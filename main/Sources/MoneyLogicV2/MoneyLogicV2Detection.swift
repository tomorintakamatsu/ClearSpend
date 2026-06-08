import Foundation

struct MoneyLogicV2TransferMatch: Identifiable, Equatable, Sendable {
    var id: String { [outflowTransactionId, inflowTransactionId].sorted().joined(separator: ":") }
    var outflowTransactionId: String
    var inflowTransactionId: String
    var amount: Double
    var confidence: MoneyLogicV2CategorizationConfidence
    var isCreditCardPayment: Bool
}

struct MoneyLogicV2RefundMatch: Identifiable, Equatable, Sendable {
    var id: String { "\(refundTransactionId):\(expenseTransactionId)" }
    var refundTransactionId: String
    var expenseTransactionId: String
    var amount: Double
    var suggestedType: MoneyLogicV2TransactionType
    var confidence: MoneyLogicV2CategorizationConfidence
}

enum MoneyLogicV2CategoryRuleMatchType: String, Codable, Sendable {
    case exactMerchant = "exact_merchant"
    case contains
    case regex
}

struct MoneyLogicV2CategoryRule: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var matchType: MoneyLogicV2CategoryRuleMatchType
    var pattern: String
    var categoryId: String
    var bucketType: MoneyLogicV2BucketType
    var isActive: Bool
}

struct MoneyLogicV2CategorySuggestion: Equatable, Sendable {
    var categoryId: String?
    var bucketType: MoneyLogicV2BucketType
    var confidence: MoneyLogicV2CategorizationConfidence
    var reason: String
}

enum MoneyLogicV2Detection {
    static func detectLikelyTransfers(
        transactions: [MoneyLogicV2Transaction],
        accounts: [MoneyLogicV2Account] = [],
        tolerance: Double = 0.01,
        dateWindowDays: Int = 3,
        calendar: Calendar = .current
    ) -> [MoneyLogicV2TransferMatch] {
        let accountById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let candidates = transactions.filter {
            $0.transferGroupId == nil &&
            $0.linkedTransactionId == nil &&
            !$0.isExcludedFromReports &&
            $0.type != .refund &&
            $0.type != .reimbursement
        }
        var matches: [MoneyLogicV2TransferMatch] = []
        var used = Set<String>()

        for lhs in candidates {
            guard !used.contains(lhs.id) else { continue }
            for rhs in candidates where lhs.id != rhs.id && !used.contains(rhs.id) {
                guard lhs.accountId != rhs.accountId else { continue }
                guard amountsMatch(lhs.absoluteAmount, rhs.absoluteAmount, tolerance: tolerance) else { continue }
                guard daysBetween(lhs.date, rhs.date, calendar: calendar) <= dateWindowDays else { continue }
                guard signsAreOpposite(lhs, rhs) else { continue }

                let lhsIsOutflow = inferredSignedAmount(lhs) < inferredSignedAmount(rhs)
                let outflow = lhsIsOutflow ? lhs : rhs
                let inflow = lhsIsOutflow ? rhs : lhs
                let isCardPayment = isCreditCardPayment(outflow: outflow, inflow: inflow, accounts: accountById)
                matches.append(
                    MoneyLogicV2TransferMatch(
                        outflowTransactionId: outflow.id,
                        inflowTransactionId: inflow.id,
                        amount: outflow.absoluteAmount,
                        confidence: isCardPayment ? .high : .medium,
                        isCreditCardPayment: isCardPayment
                    )
                )
                used.insert(outflow.id)
                used.insert(inflow.id)
                break
            }
        }

        return matches
    }

    static func applyingTransferMatches(
        _ matches: [MoneyLogicV2TransferMatch],
        to transactions: [MoneyLogicV2Transaction]
    ) -> [MoneyLogicV2Transaction] {
        var result = transactions
        let groupByTransaction = Dictionary(uniqueKeysWithValues: matches.flatMap { match in
            [
                (match.outflowTransactionId, match.id),
                (match.inflowTransactionId, match.id)
            ]
        })

        for index in result.indices {
            guard let groupId = groupByTransaction[result[index].id] else { continue }
            result[index].type = .transfer
            result[index].bucketType = .transfer
            result[index].transferGroupId = groupId
            result[index].isExcludedFromBudget = true
        }
        return result
    }

    static func applyingRefundMatches(
        _ matches: [MoneyLogicV2RefundMatch],
        to transactions: [MoneyLogicV2Transaction]
    ) -> [MoneyLogicV2Transaction] {
        var result = transactions
        let matchByRefundId = Dictionary(uniqueKeysWithValues: matches.map { ($0.refundTransactionId, $0) })
        let expenseById = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })

        for index in result.indices {
            guard let match = matchByRefundId[result[index].id] else { continue }
            let originalExpense = expenseById[match.expenseTransactionId]
            result[index].type = match.suggestedType
            result[index].bucketType = originalExpense?.bucketType ?? result[index].bucketType
            result[index].categoryId = originalExpense?.categoryId ?? result[index].categoryId
            result[index].linkedTransactionId = match.expenseTransactionId
            result[index].refundOfTransactionId = match.expenseTransactionId
            result[index].isExcludedFromBudget = false
            result[index].isExcludedFromReports = false
        }
        return result
    }

    static func detectLikelyRefunds(
        transactions: [MoneyLogicV2Transaction],
        amountTolerance: Double = 0.01,
        lookbackDays: Int = 90,
        calendar: Calendar = .current
    ) -> [MoneyLogicV2RefundMatch] {
        let positives = transactions.filter {
            !$0.isExcludedFromReports &&
            $0.linkedTransactionId == nil &&
            ($0.type == .income || $0.type == .refund || $0.type == .reimbursement) &&
            $0.absoluteAmount > 0
        }
        let expenses = transactions.filter {
            !$0.isExcludedFromReports &&
            $0.type == .expense &&
            !$0.isExcludedFromBudget &&
            $0.bucketType != .transfer &&
            $0.bucketType != .excluded &&
            $0.absoluteAmount > 0
        }
        var matches: [MoneyLogicV2RefundMatch] = []
        var usedRefunds = Set<String>()

        for refund in positives.sorted(by: { $0.date < $1.date }) {
            guard !usedRefunds.contains(refund.id) else { continue }
            let possible = expenses
                .filter { expense in
                    expense.date <= refund.date &&
                    daysBetween(expense.date, refund.date, calendar: calendar) <= lookbackDays &&
                    refund.absoluteAmount <= expense.absoluteAmount + amountTolerance &&
                    merchantOrCategorySimilar(expense, refund)
                }
                .sorted {
                    let lhsScore = refundScore(expense: $0, refund: refund, calendar: calendar)
                    let rhsScore = refundScore(expense: $1, refund: refund, calendar: calendar)
                    return lhsScore > rhsScore
                }

            guard let best = possible.first else { continue }
            let suggestedType: MoneyLogicV2TransactionType = refund.tags.contains(where: { $0.localizedCaseInsensitiveContains("reimburse") })
                ? .reimbursement
                : .refund
            matches.append(
                MoneyLogicV2RefundMatch(
                    refundTransactionId: refund.id,
                    expenseTransactionId: best.id,
                    amount: refund.absoluteAmount,
                    suggestedType: suggestedType,
                    confidence: best.categoryId == refund.categoryId ? .high : .medium
                )
            )
            usedRefunds.insert(refund.id)
        }

        return matches
    }

    static func detectRecurringSeries(
        transactions: [MoneyLogicV2Transaction],
        minimumOccurrences: Int = 3,
        amountTolerancePercent: Double = 0.10,
        calendar: Calendar = .current
    ) -> [MoneyLogicV2RecurringSeries] {
        let eligible = transactions
            .filter { !$0.isExcludedFromReports && ($0.type == .expense || $0.type == .income || $0.type == .transfer) }
            .sorted { $0.date < $1.date }
        let grouped = Dictionary(grouping: eligible) { transaction in
            let merchant = transaction.normalizedMerchantKey
            if !merchant.isEmpty {
                return "\(transaction.type.rawValue):merchant:\(merchant)"
            }
            return "\(transaction.type.rawValue):category:\(transaction.categoryId ?? "unknown"):\(MoneyLogicV2Text.normalizedMerchant(transaction.description ?? ""))"
        }

        return grouped.compactMap { _, group in
            guard group.count >= minimumOccurrences else { return nil }
            let sorted = group.sorted { $0.date < $1.date }
            let amounts = sorted.map(\.absoluteAmount)
            let average = amounts.reduce(0, +) / Double(amounts.count)
            guard average > 0 else { return nil }
            let maxDelta = amounts.map { abs($0 - average) }.max() ?? 0
            guard maxDelta <= max(1, average * amountTolerancePercent) else { return nil }

            let gaps = zip(sorted.dropLast(), sorted.dropFirst()).map { previous, next in
                max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: previous.date), to: calendar.startOfDay(for: next.date)).day ?? 1)
            }
            guard let cadence = inferredCadence(from: gaps) else { return nil }
            guard let last = sorted.last else { return nil }
            let nextDue = nextDueDate(after: last.date, cadence: cadence, calendar: calendar)
            let recurringType: MoneyLogicV2RecurringType = last.type == .income
                ? .income
                : (last.bucketType == .debt ? .debtPayment : (last.bucketType == .transfer ? .transfer : .subscription))

            return MoneyLogicV2RecurringSeries(
                id: "detected-\(last.normalizedMerchantKey)-\(cadence.rawValue)".replacingOccurrences(of: " ", with: "-"),
                name: last.merchantRaw ?? last.description ?? last.categoryId ?? "Recurring item",
                merchantNormalized: last.normalizedMerchantKey.isEmpty ? nil : last.normalizedMerchantKey,
                type: recurringType,
                accountId: last.accountId,
                categoryId: last.categoryId,
                expectedAmount: average,
                amountMode: maxDelta <= 0.01 ? .fixed : .estimateFromHistory,
                cadence: cadence,
                nextDueDate: nextDue,
                lastMatchedDate: last.date,
                autoDetected: true,
                userConfirmed: false,
                isActive: true
            )
        }
        .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    static func suggestCategory(
        for transaction: MoneyLogicV2Transaction,
        userRules: [MoneyLogicV2CategoryRule],
        categories: [MoneyLogicV2Category],
        confirmedHistory: [MoneyLogicV2Transaction],
        recurringSeries: [MoneyLogicV2RecurringSeries]
    ) -> MoneyLogicV2CategorySuggestion {
        let searchable = "\(transaction.merchantRaw ?? "") \(transaction.description ?? "")"
        let normalized = MoneyLogicV2Text.normalizedMerchant(searchable)
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for rule in userRules where rule.isActive {
            if ruleMatches(rule, normalizedText: normalized, rawText: searchable),
               categoryById[rule.categoryId] != nil {
                return MoneyLogicV2CategorySuggestion(
                    categoryId: rule.categoryId,
                    bucketType: rule.bucketType,
                    confidence: .rule,
                    reason: "Matched local rule: \(rule.name)"
                )
            }
        }

        let exactMerchantMatches = confirmedHistory.filter {
            $0.categorizationConfidence == .userConfirmed &&
            !$0.normalizedMerchantKey.isEmpty &&
            $0.normalizedMerchantKey == transaction.normalizedMerchantKey &&
            $0.categoryId != nil
        }
        if let mostCommon = mostCommonCategory(in: exactMerchantMatches) {
            return MoneyLogicV2CategorySuggestion(
                categoryId: mostCommon.categoryId,
                bucketType: mostCommon.bucketType,
                confidence: .userConfirmed,
                reason: "Used your prior confirmed merchant choice"
            )
        }

        if let series = recurringSeries.first(where: { $0.isActive && $0.merchantNormalized == transaction.normalizedMerchantKey }),
           let categoryId = series.categoryId,
           let category = categoryById[categoryId] {
            return MoneyLogicV2CategorySuggestion(
                categoryId: categoryId,
                bucketType: category.bucketType,
                confidence: series.userConfirmed ? .high : .medium,
                reason: "Matched a local recurring series"
            )
        }

        let historicalMatches = confirmedHistory.filter {
            !$0.normalizedMerchantKey.isEmpty &&
            $0.normalizedMerchantKey == transaction.normalizedMerchantKey &&
            $0.categoryId != nil
        }
        if let mostCommon = mostCommonCategory(in: historicalMatches) {
            return MoneyLogicV2CategorySuggestion(
                categoryId: mostCommon.categoryId,
                bucketType: mostCommon.bucketType,
                confidence: historicalMatches.count >= 3 ? .high : .medium,
                reason: "Matched local category history"
            )
        }

        return MoneyLogicV2CategorySuggestion(
            categoryId: categories.first(where: { $0.name.localizedCaseInsensitiveContains("misc") })?.id,
            bucketType: .flexible,
            confidence: .unknown,
            reason: "Fallback category"
        )
    }

    static func reviewQueue(
        transactions: [MoneyLogicV2Transaction],
        transferMatches: [MoneyLogicV2TransferMatch],
        refundMatches: [MoneyLogicV2RefundMatch],
        recurringCandidates: [MoneyLogicV2RecurringSeries]
    ) -> [MoneyLogicV2ReviewItem] {
        var items: [MoneyLogicV2ReviewItem] = []

        for transaction in transactions where needsReview(transaction) {
            items.append(
                MoneyLogicV2ReviewItem(
                    id: "review-\(transaction.id)",
                    kind: transaction.categoryId == nil ? .uncategorized : .suggestedCategory,
                    transactionIds: [transaction.id],
                    title: transaction.categoryId == nil ? "Needs category" : "Needs review",
                    detail: transaction.merchantRaw ?? transaction.description ?? "Transaction",
                    confidence: transaction.categorizationConfidence
                )
            )
        }

        for match in transferMatches {
            items.append(
                MoneyLogicV2ReviewItem(
                    id: "transfer-\(match.id)",
                    kind: .possibleTransfer,
                    transactionIds: [match.outflowTransactionId, match.inflowTransactionId],
                    title: match.isCreditCardPayment ? "Possible credit card payment" : "Possible transfer",
                    detail: "Same amount on nearby dates. Transfers are not counted as spending.",
                    confidence: match.confidence
                )
            )
        }

        for match in refundMatches {
            items.append(
                MoneyLogicV2ReviewItem(
                    id: "refund-\(match.id)",
                    kind: .possibleRefund,
                    transactionIds: [match.refundTransactionId, match.expenseTransactionId],
                    title: match.suggestedType == .reimbursement ? "Possible reimbursement" : "Possible refund",
                    detail: "This can reduce the original expense instead of inflating income.",
                    confidence: match.confidence
                )
            )
        }

        for series in recurringCandidates where !series.userConfirmed {
            items.append(
                MoneyLogicV2ReviewItem(
                    id: "recurring-\(series.id)",
                    kind: .possibleRecurring,
                    transactionIds: [],
                    title: "Review recurring item",
                    detail: "\(series.name) looks \(series.cadence.rawValue). Confirm before trusting it.",
                    confidence: .medium
                )
            )
        }

        return items
    }

    private static func amountsMatch(_ lhs: Double, _ rhs: Double, tolerance: Double) -> Bool {
        abs(lhs - rhs) <= max(tolerance, max(lhs, rhs) * 0.0025)
    }

    private static func signsAreOpposite(_ lhs: MoneyLogicV2Transaction, _ rhs: MoneyLogicV2Transaction) -> Bool {
        let lhsSign = inferredSignedAmount(lhs)
        let rhsSign = inferredSignedAmount(rhs)
        return lhsSign * rhsSign < 0
    }

    private static func inferredSignedAmount(_ transaction: MoneyLogicV2Transaction) -> Double {
        switch transaction.type {
        case .income, .refund, .reimbursement:
            return transaction.absoluteAmount
        case .expense:
            return -transaction.absoluteAmount
        case .transfer, .adjustment:
            return transaction.amount
        }
    }

    private static func isCreditCardPayment(
        outflow: MoneyLogicV2Transaction,
        inflow: MoneyLogicV2Transaction,
        accounts: [String: MoneyLogicV2Account]
    ) -> Bool {
        let outAccount = accounts[outflow.accountId]
        let inAccount = accounts[inflow.accountId]
        return outAccount?.type.isBudgetCashAccount == true && inAccount?.type == .creditCard
    }

    private static func daysBetween(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Int {
        abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: lhs), to: calendar.startOfDay(for: rhs)).day ?? 0)
    }

    private static func merchantOrCategorySimilar(_ expense: MoneyLogicV2Transaction, _ refund: MoneyLogicV2Transaction) -> Bool {
        let expenseMerchant = expense.normalizedMerchantKey
        let refundMerchant = refund.normalizedMerchantKey
        if !expenseMerchant.isEmpty && !refundMerchant.isEmpty {
            return expenseMerchant == refundMerchant ||
                expenseMerchant.contains(refundMerchant) ||
                refundMerchant.contains(expenseMerchant)
        }
        if let expenseCategory = expense.categoryId, expenseCategory == refund.categoryId {
            return true
        }
        return false
    }

    private static func refundScore(expense: MoneyLogicV2Transaction, refund: MoneyLogicV2Transaction, calendar: Calendar) -> Int {
        var score = 0
        if amountsMatch(expense.absoluteAmount, refund.absoluteAmount, tolerance: 0.01) { score += 3 }
        if expense.categoryId == refund.categoryId { score += 2 }
        if expense.normalizedMerchantKey == refund.normalizedMerchantKey { score += 3 }
        score -= min(daysBetween(expense.date, refund.date, calendar: calendar) / 14, 4)
        return score
    }

    private static func inferredCadence(from gaps: [Int]) -> MoneyLogicV2Cadence? {
        guard !gaps.isEmpty else { return nil }
        let average = Double(gaps.reduce(0, +)) / Double(gaps.count)
        switch average {
        case 5.5...8.5:
            return .weekly
        case 12...16:
            return .biweekly
        case 26...35:
            return .monthly
        case 80...100:
            return .quarterly
        case 350...380:
            return .yearly
        default:
            let sorted = gaps.sorted()
            if sorted.allSatisfy({ (13...18).contains($0) }) {
                return .semimonthly
            }
            return nil
        }
    }

    private static func nextDueDate(after date: Date, cadence: MoneyLogicV2Cadence, calendar: Calendar) -> Date {
        let component: DateComponents
        switch cadence {
        case .weekly:
            component = DateComponents(day: 7)
        case .biweekly:
            component = DateComponents(day: 14)
        case .semimonthly:
            component = DateComponents(day: 15)
        case .monthly:
            component = DateComponents(month: 1)
        case .quarterly:
            component = DateComponents(month: 3)
        case .yearly:
            component = DateComponents(year: 1)
        case .custom:
            component = DateComponents(month: 1)
        }
        return calendar.date(byAdding: component, to: date) ?? date
    }

    private static func ruleMatches(_ rule: MoneyLogicV2CategoryRule, normalizedText: String, rawText: String) -> Bool {
        let pattern = MoneyLogicV2Text.normalizedMerchant(rule.pattern)
        switch rule.matchType {
        case .exactMerchant:
            return normalizedText == pattern
        case .contains:
            return normalizedText.contains(pattern)
        case .regex:
            return rawText.range(of: rule.pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func mostCommonCategory(in transactions: [MoneyLogicV2Transaction]) -> (categoryId: String, bucketType: MoneyLogicV2BucketType)? {
        let grouped = Dictionary(grouping: transactions.compactMap { tx -> (String, MoneyLogicV2BucketType)? in
            guard let categoryId = tx.categoryId else { return nil }
            return (categoryId, tx.bucketType)
        }, by: { $0.0 })

        return grouped
            .map { categoryId, values in (categoryId: categoryId, bucketType: values.first?.1 ?? .flexible, count: values.count) }
            .sorted { $0.count > $1.count }
            .first
            .map { ($0.categoryId, $0.bucketType) }
    }

    private static func needsReview(_ transaction: MoneyLogicV2Transaction) -> Bool {
        if transaction.isReviewed { return false }
        if transaction.categoryId == nil { return true }
        switch transaction.categorizationConfidence {
        case .medium, .low, .unknown:
            return true
        case .userConfirmed, .rule, .high:
            return false
        }
    }
}
