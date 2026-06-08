import Foundation

enum MoneyLogicV2DataAdapter {
    static let manualAccountId = "local-manual-account"

    static func dashboardInput(
        budget: Budget?,
        transactions: [Transaction],
        goals: [Goal],
        recurringSubscriptions: [RecurringSubscription],
        customWatchlists: [String] = [],
        currency: String,
        mode: MoneyLogicV2UserMode = .plan,
        today: Date = Date()
    ) -> MoneyLogicV2DashboardInput {
        let categories = defaultCategories(
            budget: budget,
            goals: goals,
            transactions: transactions,
            currency: currency
        )
        let v2Transactions = transactions.map {
            makeTransaction($0, currency: currency, categories: categories)
        }
        let recurring = recurringSubscriptions.map {
            makeRecurringSeries($0, categories: categories)
        }
        let watchlists = makeWatchlists(from: transactions, categories: categories, customWatchlists: customWatchlists)
        let openingCash = (budget?.currentSpendableBalance ?? 0) + (budget?.cashOnHand ?? 0)
        // Future paychecks are context, not spendable money until recorded as income.
        let expectedIncome: Double = 0
        let requiredBuffer = budget?.moneyToKeepUntouched ?? 0

        return MoneyLogicV2DashboardInput(
            mode: mode,
            currency: currency,
            monthDate: today,
            openingBudgetCash: openingCash,
            expectedIncome: expectedIncome,
            requiredBuffer: requiredBuffer,
            accounts: [],
            transactions: v2Transactions,
            categories: categories,
            recurringSeries: recurring,
            watchlists: watchlists
        )
    }

    static func defaultCategories(
        budget: Budget?,
        goals: [Goal],
        transactions: [Transaction],
        currency: String
    ) -> [MoneyLogicV2Category] {
        let limits = budget?.categoryLimits ?? [:]
        var sort = 0
        var categories: [MoneyLogicV2Category] = []

        func add(_ id: String, _ name: String, _ group: String, _ bucket: MoneyLogicV2BucketType, _ icon: String, _ color: String, budget fallback: Double = 0) {
            sort += 1
            categories.append(
                MoneyLogicV2Category(
                    id: id,
                    name: name,
                    groupId: group,
                    bucketType: bucket,
                    icon: icon,
                    color: color,
                    monthlyBudget: limits[id] ?? fallback,
                    rolloverEnabled: bucket == .flexible || bucket == .nonMonthly,
                    rolloverBalance: 0,
                    targetAmount: nil,
                    targetDate: nil,
                    sortOrder: sort,
                    isArchived: false
                )
            )
        }

        add("paycheck", "Paycheck", "income", .income, "banknote", "2e7d32")
        add("side_income", "Side Income", "income", .income, "briefcase", "1976d2")
        add("other_income", "Other Income", "income", .income, "plus.circle", "607d8b")

        let fixedCategoryIDs = [
            "rent",
            "utilities",
            "insurance",
            "phone",
            "internet",
            "subscriptions",
            "transportation_fixed",
            "minimum_debt_payments"
        ]
        let hasDetailedFixedLimits = fixedCategoryIDs.contains { limits[$0] != nil }
        if !hasDetailedFixedLimits, (budget?.monthlyEssentials ?? 0) > 0 {
            add("fixed_spending", "Fixed Spending", "fixed", .fixed, "calendar.badge.clock", "5e35b1", budget: budget?.monthlyEssentials ?? 0)
        }

        add("rent", "Rent / Mortgage", "fixed", .fixed, "house", "5e35b1")
        add("utilities", "Utilities", "fixed", .fixed, "bolt", "f9a825")
        add("insurance", "Insurance", "fixed", .fixed, "shield", "00897b")
        add("phone", "Phone", "fixed", .fixed, "iphone", "039be5")
        add("internet", "Internet", "fixed", .fixed, "wifi", "3949ab")
        add("subscriptions", "Subscriptions", "fixed", .fixed, "repeat", "00acc1")
        add("transportation_fixed", "Transportation Fixed", "fixed", .fixed, "car", "546e7a")
        add("minimum_debt_payments", "Minimum Debt Payments", "fixed", .debt, "creditcard", "c62828")

        add("groceries", "Groceries", "flexible", .flexible, "basket", "43a047")
        add("dining", "Dining", "flexible", .flexible, "fork.knife", "fb8c00")
        add("coffee", "Coffee", "flexible", .flexible, "cup.and.saucer", "6d4c41")
        add("shopping", "Shopping", "flexible", .flexible, "bag", "d81b60")
        add("entertainment", "Entertainment", "flexible", .flexible, "play.rectangle", "8e24aa")
        add("transport", "Transport", "flexible", .flexible, "tram", "1e88e5")
        add("personal", "Personal", "flexible", .flexible, "person", "7cb342")
        add("health", "Health", "flexible", .flexible, "heart", "e53935")
        add("miscellaneous", "Miscellaneous", "flexible", .flexible, "ellipsis.circle", "757575")

        add("travel", "Travel", "non_monthly", .nonMonthly, "airplane", "00897b")
        add("gifts", "Gifts", "non_monthly", .nonMonthly, "gift", "e91e63")
        add("car_maintenance", "Car Maintenance", "non_monthly", .nonMonthly, "wrench", "455a64")
        add("annual_fees", "Annual Fees", "non_monthly", .nonMonthly, "calendar", "6a1b9a")
        add("medical", "Medical", "non_monthly", .nonMonthly, "cross.case", "d32f2f")
        add("taxes", "Taxes", "non_monthly", .nonMonthly, "doc.text", "795548")
        add("home_maintenance", "Home Maintenance", "non_monthly", .nonMonthly, "hammer", "5d4037")
        add("emergency_buffer", "Emergency Buffer", "non_monthly", .nonMonthly, "lifepreserver", "00796b")

        let savingsFallback = budget?.monthlySavingsGoal ?? 0
        add("emergency_fund", "Emergency Fund", "goals", .goal, "lock.shield", "2e7d32", budget: savingsFallback)
        add("vacation", "Vacation", "goals", .goal, "sun.max", "00838f")
        add("big_purchase", "Big Purchase", "goals", .goal, "shippingbox", "6d4c41")
        add("debt_extra_payment", "Debt Extra Payment", "goals", .debt, "arrow.down.circle", "c62828")

        add("transfer", "Transfer", "transfer_excluded", .transfer, "arrow.left.arrow.right", "607d8b")
        add("credit_card_payment", "Credit Card Payment", "transfer_excluded", .transfer, "creditcard", "607d8b")
        add("refund", "Refund", "transfer_excluded", .excluded, "arrow.uturn.backward", "2e7d32")
        add("reimbursement", "Reimbursement", "transfer_excluded", .excluded, "person.crop.circle.badge.plus", "2e7d32")
        add("balance_adjustment", "Balance Adjustment", "transfer_excluded", .excluded, "slider.horizontal.3", "757575")
        add("ignore", "Ignore", "transfer_excluded", .excluded, "eye.slash", "757575")

        for custom in budget?.customCategories ?? [] {
            let id = categoryId(custom)
            if !categories.contains(where: { $0.id == id }) {
                add(id, custom, "custom", bucketType(for: id, name: custom), "square.grid.2x2", "607d8b")
            }
        }

        for transaction in transactions {
            if let raw = transaction.category {
                let id = categoryId(raw)
                if !categories.contains(where: { $0.id == id }) {
                    add(id, raw, "imported", bucketType(for: id, name: raw), "tag", "607d8b")
                }
            }
        }

        for goal in goals {
            let id = categoryId(goal.category ?? goal.name)
            if !categories.contains(where: { $0.id == id }) {
                sort += 1
                categories.append(
                    MoneyLogicV2Category(
                        id: id,
                        name: goal.name,
                        groupId: "goals",
                        bucketType: .goal,
                        icon: "target",
                        color: "2e7d32",
                        monthlyBudget: goal.paymentAmount ?? 0,
                        rolloverEnabled: true,
                        rolloverBalance: goal.currentAmount,
                        targetAmount: goal.targetAmount,
                        targetDate: parseDate(goal.targetDate),
                        sortOrder: sort,
                        isArchived: false
                    )
                )
            }
        }

        return categories
    }

    static func makeTransaction(
        _ transaction: Transaction,
        currency: String,
        categories: [MoneyLogicV2Category]
    ) -> MoneyLogicV2Transaction {
        let now = Date()
        let categoryId = transaction.category.map(categoryId)
        let category = categoryId.flatMap { id in categories.first(where: { $0.id == id }) }
        let tags = transaction.tags ?? []
        let v2Type = inferredV2Type(transaction: transaction, categoryId: categoryId, tags: tags)
        let bucket = category?.bucketType ?? (v2Type == .income ? .income : .flexible)
        let resolvedBucket: MoneyLogicV2BucketType = {
            switch v2Type {
            case .transfer:
                return .transfer
            case .adjustment:
                return .excluded
            case .refund, .reimbursement:
                return (bucket == .transfer || bucket == .excluded) ? .flexible : bucket
            case .income, .expense:
                return bucket
            }
        }()
        let date = parseDate(transaction.date) ?? now
        let signedAmount = inferredSignedAmount(transaction: transaction, v2Type: v2Type, tags: tags)

        return MoneyLogicV2Transaction(
            id: transaction.id,
            accountId: accountId(from: tags) ?? manualAccountId,
            date: date,
            postedDate: nil,
            amount: signedAmount,
            currency: transaction.baseCurrency ?? transaction.originalCurrency ?? currency,
            merchantRaw: transaction.merchant,
            merchantNormalized: transaction.merchant.map(MoneyLogicV2Text.normalizedMerchant),
            description: transaction.description ?? transaction.note,
            type: v2Type,
            categoryId: categoryId,
            bucketType: resolvedBucket,
            tags: tags,
            notes: transaction.note,
            source: transaction.id.hasPrefix("import-") ? .csvImport : .manual,
            importBatchId: transaction.id.hasPrefix("import-") ? "local-import" : nil,
            recurringSeriesId: transaction.isRecurring ? transaction.tags?.first(where: { $0.hasPrefix("subscription:") }) : nil,
            linkedTransactionId: nil,
            transferGroupId: nil,
            refundOfTransactionId: nil,
            isReviewed: transaction.category != nil,
            isExcludedFromBudget: resolvedBucket == .transfer || resolvedBucket == .excluded,
            isExcludedFromReports: false,
            categorizationConfidence: transaction.category == nil ? .unknown : .userConfirmed,
            createdAt: parseDate(transaction.createdDate) ?? date,
            updatedAt: parseDate(transaction.updatedDate) ?? now
        )
    }

    static func makeRecurringSeries(
        _ subscription: RecurringSubscription,
        categories: [MoneyLogicV2Category]
    ) -> MoneyLogicV2RecurringSeries {
        let categoryId = subscription.category.map(categoryId) ?? "subscriptions"
        let category = categories.first(where: { $0.id == categoryId })
        return MoneyLogicV2RecurringSeries(
            id: subscription.id,
            name: subscription.name,
            merchantNormalized: MoneyLogicV2Text.normalizedMerchant(subscription.name),
            type: category?.bucketType == .debt ? .debtPayment : .subscription,
            accountId: manualAccountId,
            categoryId: categoryId,
            expectedAmount: subscription.amount,
            amountMode: .fixed,
            cadence: cadence(for: subscription.interval),
            nextDueDate: parseDate(subscription.nextBillingDate) ?? Date(),
            lastMatchedDate: nil,
            autoDetected: false,
            userConfirmed: true,
            isActive: subscription.isActive
        )
    }

    static func makeWatchlists(
        from transactions: [Transaction],
        categories: [MoneyLogicV2Category] = [],
        customWatchlists: [String] = []
    ) -> [MoneyLogicV2Watchlist] {
        var watchlists: [MoneyLogicV2Watchlist] = []
        var usedIDs: Set<String> = []

        for custom in customWatchlists {
            let name = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let normalized = MoneyLogicV2Text.normalizedMerchant(name)
            let categoryID = categoryId(name)
            let matchingCategory = categories.first { category in
                category.id == categoryID || MoneyLogicV2Text.normalizedMerchant(category.name) == normalized
            }
            let type: MoneyLogicV2WatchlistType = matchingCategory == nil ? .merchant : .category
            let matchValue = matchingCategory?.id ?? normalized
            let id = "custom-\(type.rawValue)-\(matchValue)"
            guard !usedIDs.contains(id) else { continue }
            usedIDs.insert(id)
            watchlists.append(
                MoneyLogicV2Watchlist(
                    id: id,
                    name: name,
                    type: type,
                    matchValue: matchValue,
                    monthlyLimit: nil,
                    isActive: true
                )
            )
        }

        return Array(watchlists.prefix(5))
    }

    private static func categoryId(_ value: String) -> String {
        let normalized = MoneyLogicV2Text.normalizedMerchant(value)
            .replacingOccurrences(of: " ", with: "_")
        return normalized.isEmpty ? "custom_\(stableHexID(for: value))" : normalized
    }

    private static func stableHexID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func bucketType(for id: String, name: String) -> MoneyLogicV2BucketType {
        let value = "\(id) \(MoneyLogicV2Text.normalizedMerchant(name))"
        if value.contains("income") || value.contains("salary") || value.contains("paycheck") || value.contains("freelance") {
            return .income
        }
        if value.contains("rent") || value.contains("mortgage") || value.contains("utility") || value.contains("bill") || value.contains("insurance") || value.contains("phone") || value.contains("internet") || value.contains("subscription") {
            return .fixed
        }
        if value.contains("travel") || value.contains("gift") || value.contains("maintenance") || value.contains("annual") || value.contains("medical") || value.contains("tax") {
            return .nonMonthly
        }
        if value.contains("saving") || value.contains("goal") || value.contains("emergency") || value.contains("vacation") {
            return .goal
        }
        if value.contains("debt") || value.contains("loan") {
            return .debt
        }
        if value.contains("transfer") || value.contains("payment") || value.contains("refund") || value.contains("ignore") {
            return .transfer
        }
        return .flexible
    }

    private static func cadence(for interval: RecurringSubscription.BillingInterval) -> MoneyLogicV2Cadence {
        switch interval {
        case .weekly:
            return .weekly
        case .biweekly:
            return .biweekly
        case .monthly:
            return .monthly
        case .custom:
            return .custom
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func inferredV2Type(
        transaction: Transaction,
        categoryId: String?,
        tags: [String]
    ) -> MoneyLogicV2TransactionType {
        let markers = Set(tags + [categoryId].compactMap { $0 })
        if markers.contains("refund") { return .refund }
        if markers.contains("reimbursement") { return .reimbursement }
        if markers.contains("balance_adjustment") || markers.contains("adjustment") { return .adjustment }
        if markers.contains("transfer") || markers.contains("credit_card_payment") ||
            markers.contains(where: { $0.contains("transfer_") || $0.contains("payment_") }) {
            return .transfer
        }
        return transaction.type == .income ? .income : .expense
    }

    private static func inferredSignedAmount(
        transaction: Transaction,
        v2Type: MoneyLogicV2TransactionType,
        tags: [String]
    ) -> Double {
        let amount = abs(transaction.amount)
        switch v2Type {
        case .income, .refund, .reimbursement:
            return amount
        case .expense:
            return -amount
        case .transfer:
            return tags.contains(where: { $0.hasSuffix("_in") || $0.contains("transfer_in") || $0.contains("payment_in") })
                ? amount
                : -amount
        case .adjustment:
            return transaction.type == .income ? amount : -amount
        }
    }

    private static func accountId(from tags: [String]) -> String? {
        tags.first(where: { $0.hasPrefix("account:") })?
            .replacingOccurrences(of: "account:", with: "")
    }
}
