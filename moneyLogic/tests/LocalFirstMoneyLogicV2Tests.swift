import Foundation

@main
struct LocalFirstMoneyLogicV2Tests {
    static var failures = 0

    static func main() {
        testSafeToSpend()
        testLeftThisMonth()
        testFlexiblePacing()
        testCategoryRemainingAndRollover()
        testNonMonthlySetAside()
        testNetWorth()
        testTransferAndCreditCardPaymentMatching()
        testRefundAndReimbursementHandling()
        testRecurringDetection()
        testCategorizationPriority()
        testReviewQueue()
        testCSVImportDuplicateAndUndo()
        testCSVImportCanonicalCategoryMapping()
        testCurrencyInputParsing()
        testSupportedCurrencySymbols()
        testRefundApplicationReducesSpending()
        testSameSignTransfersDoNotAutoMatch()
        testPlanFundedSafeToSpendDoesNotDoubleCountIncome()
        testSafeUntilNextIncome()
        testSafeUntilPaydayUsesOnlyCountedTodayInputs()
        testDashboardService()
        testWatchlistPartialMerchantMatching()

        if failures == 0 {
            print("LocalFirstMoneyLogicV2Tests passed")
        } else {
            print("LocalFirstMoneyLogicV2Tests failed: \(failures)")
            exit(1)
        }
    }

    static func testSafeToSpend() {
        let calendar = fixedCalendar()
        let today = date("2026-05-10")
        let result = MoneyLogicV2Calculations.safeToSpend(
            spendableCash: 1_000,
            expectedIncomeRemainingThisMonth: 500,
            unpaidFixedBills: 300,
            unpaidDebtMinimums: 100,
            remainingGoalContributions: 150,
            remainingNonMonthlySetAsides: 50,
            requiredBuffer: 100,
            today: today,
            calendar: calendar
        )
        expectClose(result.trueSafeToSpend, 800, "Safe to spend true formula")
        expect(result.displaySafeToSpend == 800, "Safe to spend display keeps positive value")
        expect(result.daysRemaining == 22, "Days remaining includes today")

        let negative = MoneyLogicV2Calculations.safeToSpend(
            spendableCash: 100,
            expectedIncomeRemainingThisMonth: 0,
            unpaidFixedBills: 300,
            unpaidDebtMinimums: 0,
            remainingGoalContributions: 0,
            remainingNonMonthlySetAsides: 0,
            requiredBuffer: 0,
            today: today,
            calendar: calendar
        )
        expectClose(negative.trueSafeToSpend, -200, "Safe to spend preserves negative internal value")
        expectClose(negative.displaySafeToSpend, -200, "Safe to spend display shows overspending")
    }

    static func testLeftThisMonth() {
        let left = MoneyLogicV2Calculations.leftThisMonth(
            expectedIncomeThisMonth: 3_000,
            openingBudgetCash: 200,
            fixedPaid: 800,
            fixedRemaining: 400,
            flexibleSpent: 350,
            nonMonthlySpent: 100,
            remainingNonMonthlySetAsides: 150,
            goalContributionsActual: 200,
            remainingGoalContributions: 100,
            debtMinimumsPaid: 125,
            unpaidDebtMinimums: 75,
            otherIncludedSpend: 50
        )
        expectClose(left, 850, "Left this month formula")
    }

    static func testSafeUntilNextIncome() {
        let summary = MoneyLogicV2Calculations.safeUntilNextIncome(
            currentSpendableBalance: 1_200,
            cashOnHand: 80,
            billsDueBeforeNextIncome: 400,
            savingsDueBeforeNextIncome: 150,
            requiredBuffer: 200,
            nextIncomeDate: date("2026-05-20"),
            today: date("2026-05-10"),
            calendar: fixedCalendar()
        )
        expectClose(summary.trueSafeToSpend, 530, "Safe until payday uses only current money and local commitments")
        expect(summary.daysRemaining == 11, "Safe until payday includes today and payday")
        expectClose(summary.dailySafeToSpend, 48.18181818, "Daily until payday divides by bridge days")

        let setupExample = MoneyLogicV2Calculations.safeUntilNextIncome(
            currentSpendableBalance: 10_000,
            cashOnHand: 500,
            billsDueBeforeNextIncome: 5_000,
            savingsDueBeforeNextIncome: 2_000,
            requiredBuffer: 2_000,
            nextIncomeDate: date("2026-06-10"),
            today: date("2026-05-30"),
            calendar: fixedCalendar()
        )
        expectClose(setupExample.trueSafeToSpend, 1_500, "Setup safe until payday uses current money, not future salary")
    }

    static func testSafeUntilPaydayUsesOnlyCountedTodayInputs() {
        let summary = MoneyLogicV2Calculations.safeUntilNextIncome(
            currentSpendableBalance: 10_000,
            cashOnHand: 500,
            billsDueBeforeNextIncome: 5_000,
            savingsDueBeforeNextIncome: 2_000,
            requiredBuffer: 2_000,
            nextIncomeDate: date("2026-06-10"),
            today: date("2026-06-01"),
            calendar: fixedCalendar()
        )

        expectClose(summary.trueSafeToSpend, 1_500, "Safe Until Payday counts today's money minus bills, savings, and protected money")
        expectClose(summary.dailySafeToSpend, 150, "Safe Until Payday daily amount divides by days through payday")
        expect(summary.explanation.contains("money you have today"), "Safe Until Payday explanation stays local-first")
    }

    static func testFlexiblePacing() {
        let summary = MoneyLogicV2Calculations.flexibleSpending(
            flexibleBudget: 900,
            flexibleSpent: 200,
            today: date("2026-05-10"),
            calendar: fixedCalendar()
        )
        expectClose(summary.flexibleRemaining, 700, "Flexible remaining")
        expect(summary.status == .underPace || summary.status == .onTrack, "Flexible pace is calm")
    }

    static func testCategoryRemainingAndRollover() {
        let remaining = MoneyLogicV2Calculations.categoryRemaining(
            rolloverBalance: 25,
            assignedThisMonth: 200,
            spendThisMonth: 250
        )
        expectClose(remaining, -25, "Category remaining with rollover")
    }

    static func testNonMonthlySetAside() {
        let monthly = MoneyLogicV2Calculations.nonMonthlySetAside(
            targetAmount: 1_200,
            savedSoFar: 300,
            currentMonth: date("2026-05-01"),
            targetDate: date("2026-08-15"),
            calendar: fixedCalendar()
        )
        expectClose(monthly, 225, "Non-monthly set aside includes current and target month")
    }

    static func testNetWorth() {
        let accounts = [
            account(id: "checking", type: .checking, currentBalance: 1_000),
            account(id: "savings", type: .savings, currentBalance: 2_500),
            account(id: "card", type: .creditCard, currentBalance: 400),
            account(id: "loan", type: .loan, currentBalance: 1_000)
        ]
        expectClose(MoneyLogicV2Calculations.netWorth(accounts: accounts), 2_100, "Net worth subtracts liabilities")
    }

    static func testTransferAndCreditCardPaymentMatching() {
        let accounts = [
            account(id: "checking", type: .checking, currentBalance: 1_000),
            account(id: "card", type: .creditCard, currentBalance: 400)
        ]
        let outflow = transaction(id: "out", accountId: "checking", amount: -200, type: .expense, categoryId: "credit_card_payment", bucketType: .debt)
        let inflow = transaction(id: "in", accountId: "card", amount: 200, type: .income, categoryId: "credit_card_payment", bucketType: .debt, date: date("2026-05-11"))
        let matches = MoneyLogicV2Detection.detectLikelyTransfers(transactions: [outflow, inflow], accounts: accounts, calendar: fixedCalendar())
        expect(matches.count == 1, "Transfer matching detects opposite equal amounts")
        expect(matches.first?.isCreditCardPayment == true, "Credit card payment is detected as transfer")

        let applied = MoneyLogicV2Detection.applyingTransferMatches(matches, to: [outflow, inflow])
        expect(applied.allSatisfy { $0.type == .transfer && $0.isExcludedFromBudget }, "Matched transfers are excluded from budget")
        expectClose(MoneyLogicV2Calculations.netCashFlow(transactions: applied), 0, "Transfers do not affect cash flow")
    }

    static func testRefundAndReimbursementHandling() {
        let original = transaction(id: "expense", amount: -80, type: .expense, categoryId: "shopping", bucketType: .flexible, merchant: "Target")
        let refund = transaction(id: "refund", amount: 40, type: .income, categoryId: "shopping", bucketType: .income, merchant: "Target", date: date("2026-05-20"))
        let matches = MoneyLogicV2Detection.detectLikelyRefunds(transactions: [original, refund], calendar: fixedCalendar())
        expect(matches.count == 1, "Refund matching detects matching merchant and amount")

        var reimbursement = refund
        reimbursement.id = "reimbursement"
        reimbursement.tags = ["reimbursement"]
        let reimbursementMatches = MoneyLogicV2Detection.detectLikelyRefunds(transactions: [original, reimbursement], calendar: fixedCalendar())
        expect(reimbursementMatches.first?.suggestedType == .reimbursement, "Reimbursement tag keeps reimbursement type")

        let reducedSpending = MoneyLogicV2Calculations.spending(in: [
            original,
            transaction(id: "typedRefund", amount: 40, type: .refund, categoryId: "shopping", bucketType: .flexible, merchant: "Target")
        ], bucketType: .flexible)
        expectClose(reducedSpending, 40, "Refund reduces original category spending")
    }

    static func testRecurringDetection() {
        let netflix = [
            transaction(id: "n1", amount: -15, type: .expense, categoryId: "subscriptions", bucketType: .fixed, merchant: "Netflix", date: date("2026-01-05")),
            transaction(id: "n2", amount: -15, type: .expense, categoryId: "subscriptions", bucketType: .fixed, merchant: "Netflix", date: date("2026-02-05")),
            transaction(id: "n3", amount: -15, type: .expense, categoryId: "subscriptions", bucketType: .fixed, merchant: "Netflix", date: date("2026-03-05"))
        ]
        let series = MoneyLogicV2Detection.detectRecurringSeries(transactions: netflix, calendar: fixedCalendar())
        expect(series.count == 1, "Recurring detection finds repeated monthly merchant")
        expect(series.first?.cadence == .monthly, "Recurring detection infers monthly cadence")
        expect(series.first?.userConfirmed == false, "Auto-detected recurring is not trusted silently")
    }

    static func testCategorizationPriority() {
        let categories = [
            category("groceries", bucket: .flexible),
            category("subscriptions", bucket: .fixed),
            category("miscellaneous", bucket: .flexible)
        ]
        let candidate = transaction(id: "new", amount: -25, type: .expense, categoryId: nil, bucketType: .flexible, merchant: "Trader Joe's")
        let rule = MoneyLogicV2CategoryRule(
            id: "rule",
            name: "Trader Joe's",
            matchType: .contains,
            pattern: "trader",
            categoryId: "groceries",
            bucketType: .flexible,
            isActive: true
        )
        let suggestion = MoneyLogicV2Detection.suggestCategory(
            for: candidate,
            userRules: [rule],
            categories: categories,
            confirmedHistory: [],
            recurringSeries: []
        )
        expect(suggestion.categoryId == "groceries", "User rule wins categorization priority")
        expect(suggestion.confidence == .rule, "User rule confidence is rule")
    }

    static func testReviewQueue() {
        let lowConfidence = transaction(
            id: "low",
            amount: -10,
            type: .expense,
            categoryId: "miscellaneous",
            bucketType: .flexible,
            merchant: "Unknown",
            confidence: .low,
            isReviewed: false
        )
        let items = MoneyLogicV2Detection.reviewQueue(
            transactions: [lowConfidence],
            transferMatches: [],
            refundMatches: [],
            recurringCandidates: []
        )
        expect(items.count == 1, "Low confidence transaction enters review queue")
    }

    static func testCSVImportDuplicateAndUndo() {
        let csv = """
        Date,Description,Debit,Credit,Category,Merchant
        2026-05-05,Coffee,4.50,,Coffee,Blue Bottle
        2026-05-06,Paycheck,,1000,Paycheck,Employer
        """
        let existing = transaction(id: "existing", amount: -4.50, type: .expense, categoryId: "coffee", bucketType: .flexible, merchant: "Blue Bottle", date: date("2026-05-05"))
        let preview = MoneyLogicV2CSVImport.preview(
            csvText: csv,
            defaultAccountId: "checking",
            defaultCurrency: "USD",
            existingTransactions: [existing],
            importBatchId: "batch"
        )
        expect(preview.rows.count == 2, "CSV preview parses rows")
        expect(preview.duplicateCount == 1, "CSV duplicate detection flags existing transaction")
        expect(preview.importableTransactions.count == 1, "CSV preview excludes duplicates by default")

        let remaining = MoneyLogicV2CSVImport.undoImportBatch(
            transactions: preview.importableTransactions + [existing],
            importBatchId: "batch"
        )
        expect(remaining == [existing], "Import batch undo removes imported rows")
    }

    static func testCSVImportCanonicalCategoryMapping() {
        let csv = """
        Date,Description,Debit,Credit,Category,Merchant
        2026-05-07,Rent,1200,,Rent / Mortgage,Oak Ridge
        """
        let preview = MoneyLogicV2CSVImport.preview(
            csvText: csv,
            defaultAccountId: "checking",
            defaultCurrency: "USD",
            existingTransactions: [],
            importBatchId: "category"
        )
        let transaction = preview.importableTransactions.first
        expect(transaction?.categoryId == "rent", "CSV import maps Rent / Mortgage to canonical rent category")
        expect(transaction?.bucketType == .fixed, "CSV import keeps canonical rent in fixed bucket")
    }

    static func testCurrencyInputParsing() {
        expectClose(CurrencyFormat.parseInput("30,000") ?? -1, 30_000, "Currency parser treats comma groups as thousands")
        expectClose(CurrencyFormat.parseInput("$30,000.50") ?? -1, 30_000.50, "Currency parser handles US thousands and decimals")
        expectClose(CurrencyFormat.parseInput("30000,50") ?? -1, 30_000.50, "Currency parser handles decimal comma")
        expectClose(CurrencyFormat.parseInput("1.234,56") ?? -1, 1_234.56, "Currency parser handles European thousands and decimal comma")
    }

    static func testSupportedCurrencySymbols() {
        let expected: [String: String] = [
            "USD": "$",
            "EUR": "€",
            "GBP": "£",
            "JPY": "¥",
            "CAD": "C$",
            "AUD": "A$",
            "CHF": "CHF",
            "CNY": "¥",
            "HKD": "HK$",
            "SGD": "S$",
            "KRW": "₩",
            "BRL": "R$"
        ]

        for (code, symbol) in expected {
            expect(CurrencyFormat.currencySymbol(for: code) == symbol, "\(code) uses fixed supported symbol \(symbol)")
        }
    }

    static func testRefundApplicationReducesSpending() {
        let input = MoneyLogicV2DashboardInput(
            mode: .plan,
            currency: "USD",
            monthDate: date("2026-05-10"),
            openingBudgetCash: 0,
            expectedIncome: 0,
            requiredBuffer: 0,
            accounts: [],
            transactions: [
                transaction(id: "shop", amount: -100, type: .expense, categoryId: "shopping", bucketType: .flexible, merchant: "Target"),
                transaction(id: "refund", amount: 40, type: .income, categoryId: "shopping", bucketType: .income, merchant: "Target", date: date("2026-05-12"))
            ],
            categories: [
                category("shopping", bucket: .flexible, monthlyBudget: 200)
            ],
            recurringSeries: [],
            watchlists: []
        )
        let summary = LocalFirstMoneyLogicV2Service().getDashboardSummary(input: input, calendar: fixedCalendar())
        expectClose(summary.budgetMonth.flexibleSpent, 60, "Matched refund reduces flexible spending")
        expectClose(summary.netCashFlow, -60, "Matched refund reduces net expense in cash flow")
    }

    static func testSameSignTransfersDoNotAutoMatch() {
        let first = transaction(id: "one", accountId: "checking", amount: -50, type: .transfer, categoryId: "transfer", bucketType: .transfer)
        let second = transaction(id: "two", accountId: "savings", amount: -50, type: .expense, categoryId: "transfer", bucketType: .transfer, date: date("2026-05-11"))
        let matches = MoneyLogicV2Detection.detectLikelyTransfers(transactions: [first, second], calendar: fixedCalendar())
        expect(matches.isEmpty, "Same-sign transactions are not auto-matched as transfers")
    }

    static func testPlanFundedSafeToSpendDoesNotDoubleCountIncome() {
        let month = MoneyLogicV2Calculations.buildBudgetMonth(
            monthDate: date("2026-05-10"),
            currency: "USD",
            openingBudgetCash: 0,
            expectedIncome: 30_000,
            requiredBuffer: 0,
            accounts: [],
            transactions: [],
            categories: [
                category("fixed_spending", bucket: .fixed, monthlyBudget: 6_000),
                category("emergency_fund", bucket: .goal, monthlyBudget: 5_000)
            ],
            calendar: fixedCalendar()
        )

        expectClose(month.safeToSpend, 19_000, "Plan-funded safe to spend subtracts fixed spending and goals once")
        expectClose(month.expectedIncomeRemaining, 30_000, "Expected income remaining is still tracked separately")
    }

    static func testDashboardService() {
        let input = MoneyLogicV2DashboardInput(
            mode: .plan,
            currency: "USD",
            monthDate: date("2026-05-10"),
            openingBudgetCash: 100,
            expectedIncome: 2_000,
            requiredBuffer: 50,
            accounts: [],
            transactions: [
                transaction(id: "income", amount: 1_000, type: .income, categoryId: "paycheck", bucketType: .income),
                transaction(id: "rent", amount: -700, type: .expense, categoryId: "rent", bucketType: .fixed),
                transaction(
                    id: "food",
                    amount: -120,
                    type: .expense,
                    categoryId: "groceries",
                    bucketType: .flexible,
                    confidence: .low,
                    isReviewed: false
                )
            ],
            categories: [
                category("rent", bucket: .fixed, monthlyBudget: 700),
                category("groceries", bucket: .flexible, monthlyBudget: 500),
                category("emergency_fund", bucket: .goal, monthlyBudget: 100)
            ],
            recurringSeries: [],
            watchlists: [
                MoneyLogicV2Watchlist(id: "groceries", name: "Groceries", type: .category, matchValue: "groceries", monthlyLimit: 500, isActive: true)
            ]
        )
        let summary = LocalFirstMoneyLogicV2Service().getDashboardSummary(input: input, calendar: fixedCalendar())
        expect(summary.budgetMonth.expectedIncomeRemaining == 1_000, "Dashboard tracks expected income remaining")
        expect(summary.watchlists.count == 1, "Dashboard returns watchlists")
        expect(summary.reviewQueue.isEmpty == false, "Dashboard review queue includes unreviewed local data")
    }

    static func testWatchlistPartialMerchantMatching() {
        let input = MoneyLogicV2DashboardInput(
            mode: .plan,
            currency: "USD",
            monthDate: date("2026-05-10"),
            openingBudgetCash: 0,
            expectedIncome: 0,
            requiredBuffer: 0,
            accounts: [],
            transactions: [
                transaction(id: "amazon", amount: -42, type: .expense, categoryId: "shopping", bucketType: .flexible, merchant: "Amazon Marketplace"),
                transaction(id: "coffee", amount: -6, type: .expense, categoryId: "coffee", bucketType: .flexible, merchant: "Blue Bottle")
            ],
            categories: [
                category("shopping", bucket: .flexible),
                category("coffee", bucket: .flexible)
            ],
            recurringSeries: [],
            watchlists: [
                MoneyLogicV2Watchlist(id: "amazon", name: "Amazon", type: .merchant, matchValue: "amazon", monthlyLimit: nil, isActive: true),
                MoneyLogicV2Watchlist(id: "coffee", name: "Coffee", type: .category, matchValue: "coffee", monthlyLimit: nil, isActive: true)
            ]
        )

        let watchlists = LocalFirstMoneyLogicV2Service().getWatchlists(input: input)
        expectClose(watchlists.first(where: { $0.watchlist.id == "amazon" })?.spentThisMonth ?? -1, 42, "Custom merchant watchlist matches partial merchant names")
        expectClose(watchlists.first(where: { $0.watchlist.id == "coffee" })?.spentThisMonth ?? -1, 6, "Custom category watchlist matches category spending")
    }

    static func transaction(
        id: String,
        accountId: String = "checking",
        amount: Double,
        type: MoneyLogicV2TransactionType,
        categoryId: String?,
        bucketType: MoneyLogicV2BucketType,
        merchant: String? = nil,
        date: Date = date("2026-05-10"),
        confidence: MoneyLogicV2CategorizationConfidence = .userConfirmed,
        isReviewed: Bool = true
    ) -> MoneyLogicV2Transaction {
        MoneyLogicV2Transaction(
            id: id,
            accountId: accountId,
            date: date,
            postedDate: nil,
            amount: amount,
            currency: "USD",
            merchantRaw: merchant,
            merchantNormalized: merchant.map(MoneyLogicV2Text.normalizedMerchant),
            description: merchant,
            type: type,
            categoryId: categoryId,
            bucketType: bucketType,
            tags: [],
            notes: nil,
            source: .manual,
            importBatchId: nil,
            recurringSeriesId: nil,
            linkedTransactionId: nil,
            transferGroupId: nil,
            refundOfTransactionId: nil,
            isReviewed: isReviewed,
            isExcludedFromBudget: false,
            isExcludedFromReports: false,
            categorizationConfidence: confidence,
            createdAt: date,
            updatedAt: date
        )
    }

    static func account(id: String, type: MoneyLogicV2AccountType, currentBalance: Double) -> MoneyLogicV2Account {
        MoneyLogicV2Account(
            id: id,
            name: id,
            type: type,
            currency: "USD",
            openingBalance: currentBalance,
            currentBalance: currentBalance,
            includeInBudget: true,
            includeInNetWorth: true,
            isArchived: false,
            createdAt: date("2026-05-01"),
            updatedAt: date("2026-05-01")
        )
    }

    static func category(_ id: String, bucket: MoneyLogicV2BucketType, monthlyBudget: Double = 0) -> MoneyLogicV2Category {
        MoneyLogicV2Category(
            id: id,
            name: id,
            groupId: bucket.rawValue,
            bucketType: bucket,
            icon: "circle",
            color: "000000",
            monthlyBudget: monthlyBudget,
            rolloverEnabled: true,
            rolloverBalance: 0,
            targetAmount: nil,
            targetDate: nil,
            sortOrder: 0,
            isArchived: false
        )
    }

    static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }

    static func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func expectClose(_ actual: Double, _ expected: Double, _ message: String, tolerance: Double = 0.001) {
        expect(abs(actual - expected) <= tolerance, "\(message). Expected \(expected), got \(actual)")
    }
}
