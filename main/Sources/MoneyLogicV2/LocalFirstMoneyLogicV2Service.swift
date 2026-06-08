import Foundation

struct MoneyLogicV2DashboardInput: Equatable, Sendable {
    var mode: MoneyLogicV2UserMode
    var currency: String
    var monthDate: Date
    var openingBudgetCash: Double
    var expectedIncome: Double
    var requiredBuffer: Double
    var accounts: [MoneyLogicV2Account]
    var transactions: [MoneyLogicV2Transaction]
    var categories: [MoneyLogicV2Category]
    var recurringSeries: [MoneyLogicV2RecurringSeries]
    var watchlists: [MoneyLogicV2Watchlist]
}

struct LocalFirstMoneyLogicV2Service: Sendable {
    func getDashboardSummary(
        input: MoneyLogicV2DashboardInput,
        calendar: Calendar = .current
    ) -> MoneyLogicV2DashboardSummary {
        let transferMatches = MoneyLogicV2Detection.detectLikelyTransfers(
            transactions: input.transactions,
            accounts: input.accounts,
            calendar: calendar
        )
        let transferAdjustedTransactions = MoneyLogicV2Detection.applyingTransferMatches(
            transferMatches,
            to: input.transactions
        )
        let refundMatches = MoneyLogicV2Detection.detectLikelyRefunds(
            transactions: transferAdjustedTransactions,
            calendar: calendar
        )
        let calculationTransactions = MoneyLogicV2Detection.applyingRefundMatches(
            refundMatches,
            to: transferAdjustedTransactions
        )
        let monthTransactions = calculationTransactions.filter {
            calendar.isDate($0.date, equalTo: input.monthDate, toGranularity: .month)
        }
        let budgetMonth = MoneyLogicV2Calculations.buildBudgetMonth(
            monthDate: input.monthDate,
            currency: input.currency,
            openingBudgetCash: input.openingBudgetCash,
            expectedIncome: input.expectedIncome,
            requiredBuffer: input.requiredBuffer,
            accounts: input.accounts,
            transactions: calculationTransactions,
            categories: input.categories,
            calendar: calendar
        )
        let safe = MoneyLogicV2SafeToSpendSummary(
            trueSafeToSpend: budgetMonth.safeToSpend,
            displaySafeToSpend: budgetMonth.safeToSpend,
            dailySafeToSpend: budgetMonth.dailySafeToSpend,
            daysRemaining: MoneyLogicV2Calculations.daysRemainingInMonth(from: input.monthDate, calendar: calendar),
            explanation: "After upcoming bills, goals, and planned set-asides."
        )
        let flexible = MoneyLogicV2Calculations.flexibleSpending(
            flexibleBudget: budgetMonth.flexibleBudget,
            flexibleSpent: budgetMonth.flexibleSpent,
            today: input.monthDate,
            calendar: calendar
        )
        let recurringCandidates = MoneyLogicV2Detection.detectRecurringSeries(
            transactions: calculationTransactions,
            calendar: calendar
        )
        let reviewQueue = MoneyLogicV2Detection.reviewQueue(
            transactions: monthTransactions,
            transferMatches: transferMatches,
            refundMatches: refundMatches,
            recurringCandidates: recurringCandidates
        )
        let upcoming = upcomingCommitments(
            recurringSeries: input.recurringSeries + recurringCandidates,
            from: input.monthDate,
            calendar: calendar
        )
        let watchlists = watchlistSummaries(
            watchlists: input.watchlists,
            transactions: monthTransactions
        )
        let categorySummaries = MoneyLogicV2Calculations.categorySummaries(
            categories: input.categories,
            transactions: monthTransactions
        )
        let goals = categorySummaries.filter { $0.category.bucketType == .goal }

        return MoneyLogicV2DashboardSummary(
            mode: input.mode,
            safeToSpend: safe,
            flexibleSpending: flexible,
            upcomingCommitments: upcoming,
            reviewQueue: reviewQueue,
            watchlists: watchlists,
            categorySummaries: categorySummaries,
            goals: goals,
            netWorth: MoneyLogicV2Calculations.netWorth(accounts: input.accounts),
            netCashFlow: budgetMonth.netCashFlow,
            budgetMonth: budgetMonth
        )
    }

    func getSafeToSpend(input: MoneyLogicV2DashboardInput) -> MoneyLogicV2SafeToSpendSummary {
        getDashboardSummary(input: input).safeToSpend
    }

    func getFlexibleSpendingSummary(input: MoneyLogicV2DashboardInput) -> MoneyLogicV2FlexibleSpendingSummary {
        getDashboardSummary(input: input).flexibleSpending
    }

    func getUpcomingCommitments(input: MoneyLogicV2DashboardInput) -> [MoneyLogicV2UpcomingCommitment] {
        getDashboardSummary(input: input).upcomingCommitments
    }

    func getReviewQueue(input: MoneyLogicV2DashboardInput) -> [MoneyLogicV2ReviewItem] {
        getDashboardSummary(input: input).reviewQueue
    }

    func getWatchlists(input: MoneyLogicV2DashboardInput) -> [MoneyLogicV2WatchlistSummary] {
        getDashboardSummary(input: input).watchlists
    }

    func getBudgetMonth(input: MoneyLogicV2DashboardInput) -> MoneyLogicV2BudgetMonth {
        getDashboardSummary(input: input).budgetMonth
    }

    func getCategorySummaries(input: MoneyLogicV2DashboardInput) -> [MoneyLogicV2CategorySummary] {
        MoneyLogicV2Calculations.categorySummaries(
            categories: input.categories,
            transactions: input.transactions
        )
    }

    func getNetWorth(input: MoneyLogicV2DashboardInput) -> Double {
        MoneyLogicV2Calculations.netWorth(accounts: input.accounts)
    }

    func getCashFlow(input: MoneyLogicV2DashboardInput) -> Double {
        MoneyLogicV2Calculations.netCashFlow(transactions: input.transactions)
    }

    private func upcomingCommitments(
        recurringSeries: [MoneyLogicV2RecurringSeries],
        from date: Date,
        calendar: Calendar
    ) -> [MoneyLogicV2UpcomingCommitment] {
        let horizon = calendar.date(byAdding: .day, value: 45, to: date) ?? date
        return recurringSeries
            .filter { $0.isActive && $0.nextDueDate >= calendar.startOfDay(for: date) && $0.nextDueDate <= horizon }
            .map {
                MoneyLogicV2UpcomingCommitment(
                    id: $0.id,
                    name: $0.name,
                    dueDate: $0.nextDueDate,
                    amount: $0.expectedAmount,
                    type: $0.type,
                    categoryId: $0.categoryId
                )
            }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private func watchlistSummaries(
        watchlists: [MoneyLogicV2Watchlist],
        transactions: [MoneyLogicV2Transaction]
    ) -> [MoneyLogicV2WatchlistSummary] {
        watchlists
            .filter(\.isActive)
            .prefix(5)
            .map { watchlist in
                let matches = transactions.filter { transaction in
                    switch watchlist.type {
                    case .merchant:
                        let merchantKey = transaction.normalizedMerchantKey
                        let watchKey = MoneyLogicV2Text.normalizedMerchant(watchlist.matchValue)
                        return merchantKey == watchKey || merchantKey.contains(watchKey) || watchKey.contains(merchantKey)
                    case .tag:
                        return transaction.tags.contains { $0.localizedCaseInsensitiveCompare(watchlist.matchValue) == .orderedSame }
                    case .category:
                        return transaction.categoryId == watchlist.matchValue
                    }
                }
                let spent = MoneyLogicV2Calculations.spending(in: matches)
                let remaining = watchlist.monthlyLimit.map { $0 - spent }
                return MoneyLogicV2WatchlistSummary(
                    watchlist: watchlist,
                    spentThisMonth: spent,
                    transactionCount: matches.count,
                    remaining: remaining
                )
            }
    }
}
