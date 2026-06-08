import Foundation

enum MoneyLogicV2Calculations {
    static func monthIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    static func daysRemainingInMonth(from today: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: today)
        guard let endOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ).flatMap({ calendar.date(byAdding: DateComponents(month: 1, day: -1), to: $0) }) else {
            return 1
        }
        let end = calendar.startOfDay(for: endOfMonth)
        return max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
    }

    static func daysUntil(_ targetDate: Date, from today: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: today)
        let end = calendar.startOfDay(for: targetDate)
        return max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
    }

    static func safeUntilNextIncome(
        currentSpendableBalance: Double,
        cashOnHand: Double,
        billsDueBeforeNextIncome: Double,
        savingsDueBeforeNextIncome: Double,
        requiredBuffer: Double,
        nextIncomeDate: Date,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> MoneyLogicV2SafeToSpendSummary {
        let trueValue = currentSpendableBalance
            + cashOnHand
            - billsDueBeforeNextIncome
            - savingsDueBeforeNextIncome
            - requiredBuffer
        let days = daysUntil(nextIncomeDate, from: today, calendar: calendar)

        return MoneyLogicV2SafeToSpendSummary(
            trueSafeToSpend: trueValue,
            displaySafeToSpend: trueValue,
            dailySafeToSpend: trueValue / Double(days),
            daysRemaining: days,
            explanation: "Until your next payday, using only money you have today."
        )
    }

    static func spendableCash(
        accounts: [MoneyLogicV2Account],
        reservedGoalBalances: Double,
        creditCardPaymentReserve: Double
    ) -> Double {
        let budgetCash = accounts
            .filter { !$0.isArchived && $0.includeInBudget && $0.type.isBudgetCashAccount }
            .reduce(0) { $0 + $1.currentBalance }

        return budgetCash - reservedGoalBalances - creditCardPaymentReserve
    }

    static func planFunding(
        openingBudgetCash: Double,
        actualIncomeThisMonth: Double,
        expectedIncomeRemainingThisMonth: Double
    ) -> Double {
        openingBudgetCash + actualIncomeThisMonth + expectedIncomeRemainingThisMonth
    }

    static func safeToSpend(
        spendableCash: Double,
        expectedIncomeRemainingThisMonth: Double,
        unpaidFixedBills: Double,
        unpaidDebtMinimums: Double,
        remainingGoalContributions: Double,
        remainingNonMonthlySetAsides: Double,
        requiredBuffer: Double,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> MoneyLogicV2SafeToSpendSummary {
        let trueValue = spendableCash
            + expectedIncomeRemainingThisMonth
            - unpaidFixedBills
            - unpaidDebtMinimums
            - remainingGoalContributions
            - remainingNonMonthlySetAsides
            - requiredBuffer
        let days = daysRemainingInMonth(from: today, calendar: calendar)
        return MoneyLogicV2SafeToSpendSummary(
            trueSafeToSpend: trueValue,
            displaySafeToSpend: trueValue,
            dailySafeToSpend: trueValue / Double(days),
            daysRemaining: days,
            explanation: "After upcoming bills, goals, and planned set-asides."
        )
    }

    static func leftThisMonth(
        expectedIncomeThisMonth: Double,
        openingBudgetCash: Double,
        fixedPaid: Double,
        fixedRemaining: Double,
        flexibleSpent: Double,
        nonMonthlySpent: Double,
        remainingNonMonthlySetAsides: Double,
        goalContributionsActual: Double,
        remainingGoalContributions: Double,
        debtMinimumsPaid: Double,
        unpaidDebtMinimums: Double,
        otherIncludedSpend: Double
    ) -> Double {
        expectedIncomeThisMonth
            + openingBudgetCash
            - fixedPaid
            - fixedRemaining
            - flexibleSpent
            - nonMonthlySpent
            - remainingNonMonthlySetAsides
            - goalContributionsActual
            - remainingGoalContributions
            - debtMinimumsPaid
            - unpaidDebtMinimums
            - otherIncludedSpend
    }

    static func flexibleSpending(
        flexibleBudget: Double,
        flexibleSpent: Double,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> MoneyLogicV2FlexibleSpendingSummary {
        let day = max(calendar.component(.day, from: today), 1)
        let range = calendar.range(of: .day, in: .month, for: today)
        let daysInMonth = max(range?.count ?? 30, 1)
        let expected = flexibleBudget * (Double(day) / Double(daysInMonth))
        let delta = flexibleSpent - expected
        let remaining = flexibleBudget - flexibleSpent
        let status: MoneyLogicV2PaceStatus

        if flexibleBudget <= 0 {
            status = flexibleSpent <= 0 ? .onTrack : .slightlyHigh
        } else if flexibleSpent > flexibleBudget {
            status = .overBudget
        } else if delta <= -max(flexibleBudget * 0.08, 15) {
            status = .underPace
        } else if delta <= max(flexibleBudget * 0.08, 15) {
            status = .onTrack
        } else {
            status = .slightlyHigh
        }

        return MoneyLogicV2FlexibleSpendingSummary(
            flexibleBudget: flexibleBudget,
            flexibleSpent: flexibleSpent,
            flexibleRemaining: remaining,
            paceExpected: expected,
            paceDelta: delta,
            status: status
        )
    }

    static func categoryRemaining(
        rolloverBalance: Double,
        assignedThisMonth: Double,
        spendThisMonth: Double
    ) -> Double {
        rolloverBalance + assignedThisMonth - spendThisMonth
    }

    static func nonMonthlySetAside(
        targetAmount: Double,
        savedSoFar: Double,
        currentMonth: Date,
        targetDate: Date,
        calendar: Calendar = .current
    ) -> Double {
        let currentStart = firstDayOfMonth(for: currentMonth, calendar: calendar)
        let targetStart = firstDayOfMonth(for: targetDate, calendar: calendar)
        let months = (calendar.dateComponents([.month], from: currentStart, to: targetStart).month ?? 0) + 1
        return max(0, targetAmount - savedSoFar) / Double(max(1, months))
    }

    static func netCashFlow(
        transactions: [MoneyLogicV2Transaction],
        includedAccountIds: Set<String>? = nil
    ) -> Double {
        let includedIncome = transactions
            .filter { isIncluded($0, accountIds: includedAccountIds) && $0.type == .income }
            .reduce(0) { $0 + $1.absoluteAmount }

        let includedExpenses = max(spending(in: transactions, accountIds: includedAccountIds), 0)

        return includedIncome - includedExpenses
    }

    static func netWorth(accounts: [MoneyLogicV2Account]) -> Double {
        accounts
            .filter { !$0.isArchived && $0.includeInNetWorth }
            .reduce(0) { total, account in
                if account.type.isLiability {
                    return total - abs(account.currentBalance)
                }
                return total + account.currentBalance
            }
    }

    static func spending(
        in transactions: [MoneyLogicV2Transaction],
        bucketType: MoneyLogicV2BucketType? = nil,
        categoryId: String? = nil,
        accountIds: Set<String>? = nil
    ) -> Double {
        transactions.reduce(0) { total, transaction in
            guard isIncluded(transaction, accountIds: accountIds) else { return total }
            if let bucketType, transaction.bucketType != bucketType { return total }
            if let categoryId, transaction.categoryId != categoryId { return total }

            switch transaction.type {
            case .expense:
                return total + transaction.absoluteAmount
            case .refund, .reimbursement:
                return total - transaction.absoluteAmount
            case .income, .transfer, .adjustment:
                return total
            }
        }
    }

    static func income(
        in transactions: [MoneyLogicV2Transaction],
        accountIds: Set<String>? = nil
    ) -> Double {
        transactions
            .filter { isIncluded($0, accountIds: accountIds) && $0.type == .income }
            .reduce(0) { $0 + $1.absoluteAmount }
    }

    static func categorySummaries(
        categories: [MoneyLogicV2Category],
        transactions: [MoneyLogicV2Transaction],
        bucketType: MoneyLogicV2BucketType? = nil
    ) -> [MoneyLogicV2CategorySummary] {
        categories
            .filter { !$0.isArchived && (bucketType == nil || $0.bucketType == bucketType) }
            .map { category in
                let spent = max(spending(in: transactions, bucketType: nil, categoryId: category.id), 0)
                let assigned = category.monthlyBudget
                let remaining = categoryRemaining(
                    rolloverBalance: category.rolloverEnabled ? category.rolloverBalance : 0,
                    assignedThisMonth: assigned,
                    spendThisMonth: spent
                )
                return MoneyLogicV2CategorySummary(
                    category: category,
                    assignedThisMonth: assigned,
                    spentThisMonth: spent,
                    remaining: remaining,
                    isOverspent: remaining < 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.category.sortOrder == rhs.category.sortOrder {
                    return lhs.category.name < rhs.category.name
                }
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
    }

    static func creditCardPaymentReserve(
        accounts: [MoneyLogicV2Account],
        transactions: [MoneyLogicV2Transaction]
    ) -> Double {
        let cardIds = Set(accounts.filter { $0.type == .creditCard }.map(\.id))
        guard !cardIds.isEmpty else { return 0 }

        return transactions.reduce(0) { total, transaction in
            guard cardIds.contains(transaction.accountId), !transaction.isExcludedFromBudget else { return total }
            switch transaction.type {
            case .expense:
                return total + transaction.absoluteAmount
            case .refund, .reimbursement:
                return total - transaction.absoluteAmount
            case .transfer, .income, .adjustment:
                return total
            }
        }
    }

    static func buildBudgetMonth(
        monthDate: Date,
        currency: String,
        openingBudgetCash: Double,
        expectedIncome: Double,
        requiredBuffer: Double,
        accounts: [MoneyLogicV2Account],
        transactions: [MoneyLogicV2Transaction],
        categories: [MoneyLogicV2Category],
        calendar: Calendar = .current
    ) -> MoneyLogicV2BudgetMonth {
        let monthTransactions = transactions.filter { calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) }
        let budgetAccountIds = Set(accounts.filter { $0.includeInBudget }.map(\.id))
        let includedAccountIds: Set<String>? = budgetAccountIds.isEmpty ? nil : budgetAccountIds

        let actualIncome = income(in: monthTransactions, accountIds: includedAccountIds)
        let expectedRemaining = max(expectedIncome - actualIncome, 0)
        let fixedPlanned = categories.filter { $0.bucketType == .fixed }.reduce(0) { $0 + $1.monthlyBudget }
        let fixedPaid = max(spending(in: monthTransactions, bucketType: .fixed, accountIds: includedAccountIds), 0)
        let debtPlanned = categories.filter { $0.bucketType == .debt }.reduce(0) { $0 + $1.monthlyBudget }
        let debtPaid = max(spending(in: monthTransactions, bucketType: .debt, accountIds: includedAccountIds), 0)
        let nonMonthlyPlanned = categories.filter { $0.bucketType == .nonMonthly }.reduce(0) { $0 + $1.monthlyBudget }
        let nonMonthlySpent = max(spending(in: monthTransactions, bucketType: .nonMonthly, accountIds: includedAccountIds), 0)
        let goalPlanned = categories.filter { $0.bucketType == .goal }.reduce(0) { $0 + $1.monthlyBudget }
        let goalActual = max(spending(in: monthTransactions, bucketType: .goal, accountIds: includedAccountIds), 0)
        let flexibleBudget = categories.filter { $0.bucketType == .flexible }.reduce(0) { $0 + $1.monthlyBudget }
        let flexibleSpent = max(spending(in: monthTransactions, bucketType: .flexible, accountIds: includedAccountIds), 0)
        let otherSpent = max(spending(in: monthTransactions, bucketType: .excluded, accountIds: includedAccountIds), 0)

        let reserve = creditCardPaymentReserve(accounts: accounts, transactions: monthTransactions)
        let hasBudgetCashAccounts = accounts.contains { $0.includeInBudget && $0.type.isBudgetCashAccount }
        let cash: Double
        let incomeRemainingForSafeToSpend: Double
        if hasBudgetCashAccounts {
            cash = spendableCash(accounts: accounts, reservedGoalBalances: goalActual, creditCardPaymentReserve: reserve)
            incomeRemainingForSafeToSpend = expectedRemaining
        } else {
            cash = planFunding(
                openingBudgetCash: openingBudgetCash,
                actualIncomeThisMonth: actualIncome,
                expectedIncomeRemainingThisMonth: expectedRemaining
            )
            - fixedPaid
            - debtPaid
            - goalActual
            - nonMonthlySpent
            - flexibleSpent
            - otherSpent
            incomeRemainingForSafeToSpend = 0
        }
        let safe = safeToSpend(
            spendableCash: cash,
            expectedIncomeRemainingThisMonth: incomeRemainingForSafeToSpend,
            unpaidFixedBills: max(fixedPlanned - fixedPaid, 0),
            unpaidDebtMinimums: max(debtPlanned - debtPaid, 0),
            remainingGoalContributions: max(goalPlanned - goalActual, 0),
            remainingNonMonthlySetAsides: max(nonMonthlyPlanned - nonMonthlySpent, 0),
            requiredBuffer: requiredBuffer,
            today: monthDate,
            calendar: calendar
        )
        let left = leftThisMonth(
            expectedIncomeThisMonth: expectedIncome,
            openingBudgetCash: openingBudgetCash,
            fixedPaid: fixedPaid,
            fixedRemaining: max(fixedPlanned - fixedPaid, 0),
            flexibleSpent: flexibleSpent,
            nonMonthlySpent: nonMonthlySpent,
            remainingNonMonthlySetAsides: max(nonMonthlyPlanned - nonMonthlySpent, 0),
            goalContributionsActual: goalActual,
            remainingGoalContributions: max(goalPlanned - goalActual, 0),
            debtMinimumsPaid: debtPaid,
            unpaidDebtMinimums: max(debtPlanned - debtPaid, 0),
            otherIncludedSpend: otherSpent
        )
        let now = Date()

        return MoneyLogicV2BudgetMonth(
            month: monthIdentifier(for: monthDate, calendar: calendar),
            currency: currency,
            openingBudgetCash: openingBudgetCash,
            expectedIncome: expectedIncome,
            actualIncome: actualIncome,
            expectedIncomeRemaining: expectedRemaining,
            fixedPlanned: fixedPlanned,
            fixedPaid: fixedPaid,
            fixedRemaining: max(fixedPlanned - fixedPaid, 0),
            nonMonthlySetAsidePlanned: nonMonthlyPlanned,
            nonMonthlySpent: nonMonthlySpent,
            goalContributionsPlanned: goalPlanned,
            goalContributionsActual: goalActual,
            debtMinimumsPlanned: debtPlanned,
            debtMinimumsPaid: debtPaid,
            flexibleBudget: flexibleBudget,
            flexibleSpent: flexibleSpent,
            otherSpent: otherSpent,
            safeToSpend: safe.trueSafeToSpend,
            dailySafeToSpend: safe.dailySafeToSpend,
            leftThisMonth: left,
            netCashFlow: netCashFlow(transactions: monthTransactions, includedAccountIds: includedAccountIds),
            createdAt: now,
            updatedAt: now
        )
    }

    private static func firstDayOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func isIncluded(_ transaction: MoneyLogicV2Transaction, accountIds: Set<String>?) -> Bool {
        if transaction.isExcludedFromBudget || transaction.isExcludedFromReports {
            return false
        }
        if transaction.type == .transfer || transaction.bucketType == .transfer || transaction.bucketType == .excluded {
            return false
        }
        if let accountIds, !accountIds.contains(transaction.accountId) {
            return false
        }
        return true
    }
}
