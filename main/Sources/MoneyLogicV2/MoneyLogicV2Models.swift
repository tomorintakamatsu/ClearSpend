import Foundation

enum MoneyLogicV2AccountType: String, Codable, CaseIterable, Sendable {
    case cash
    case checking
    case savings
    case creditCard = "credit_card"
    case loan
    case investment
    case otherAsset = "other_asset"
    case otherLiability = "other_liability"

    var isBudgetCashAccount: Bool {
        switch self {
        case .cash, .checking, .savings:
            return true
        case .creditCard, .loan, .investment, .otherAsset, .otherLiability:
            return false
        }
    }

    var isAsset: Bool {
        switch self {
        case .cash, .checking, .savings, .investment, .otherAsset:
            return true
        case .creditCard, .loan, .otherLiability:
            return false
        }
    }

    var isLiability: Bool {
        switch self {
        case .creditCard, .loan, .otherLiability:
            return true
        case .cash, .checking, .savings, .investment, .otherAsset:
            return false
        }
    }
}

struct MoneyLogicV2Account: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var type: MoneyLogicV2AccountType
    var currency: String
    var openingBalance: Double
    var currentBalance: Double
    var includeInBudget: Bool
    var includeInNetWorth: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum MoneyLogicV2TransactionType: String, Codable, CaseIterable, Sendable {
    case income
    case expense
    case transfer
    case refund
    case reimbursement
    case adjustment
}

enum MoneyLogicV2BucketType: String, Codable, CaseIterable, Sendable {
    case income
    case fixed
    case flexible
    case nonMonthly = "non_monthly"
    case goal
    case debt
    case transfer
    case excluded
}

enum MoneyLogicV2TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case csvImport = "csv_import"
    case localImport = "local_import"
    case migration
}

enum MoneyLogicV2CategorizationConfidence: String, Codable, CaseIterable, Sendable {
    case userConfirmed = "user_confirmed"
    case rule
    case high
    case medium
    case low
    case unknown
}

struct MoneyLogicV2Transaction: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var accountId: String
    var date: Date
    var postedDate: Date?
    var amount: Double
    var currency: String
    var merchantRaw: String?
    var merchantNormalized: String?
    var description: String?
    var type: MoneyLogicV2TransactionType
    var categoryId: String?
    var bucketType: MoneyLogicV2BucketType
    var tags: [String]
    var notes: String?
    var source: MoneyLogicV2TransactionSource
    var importBatchId: String?
    var recurringSeriesId: String?
    var linkedTransactionId: String?
    var transferGroupId: String?
    var refundOfTransactionId: String?
    var isReviewed: Bool
    var isExcludedFromBudget: Bool
    var isExcludedFromReports: Bool
    var categorizationConfidence: MoneyLogicV2CategorizationConfidence
    var createdAt: Date
    var updatedAt: Date

    var absoluteAmount: Double {
        abs(amount)
    }

    var normalizedMerchantKey: String {
        MoneyLogicV2Text.normalizedMerchant(merchantNormalized ?? merchantRaw ?? description ?? "")
    }

    var reportSignedAmount: Double {
        switch type {
        case .income:
            return absoluteAmount
        case .expense:
            return -absoluteAmount
        case .refund, .reimbursement:
            return absoluteAmount
        case .transfer, .adjustment:
            return 0
        }
    }
}

struct MoneyLogicV2Category: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var groupId: String
    var bucketType: MoneyLogicV2BucketType
    var icon: String
    var color: String
    var monthlyBudget: Double
    var rolloverEnabled: Bool
    var rolloverBalance: Double
    var targetAmount: Double?
    var targetDate: Date?
    var sortOrder: Int
    var isArchived: Bool
}

enum MoneyLogicV2RecurringType: String, Codable, CaseIterable, Sendable {
    case income
    case bill
    case subscription
    case debtPayment = "debt_payment"
    case transfer
    case savingsGoal = "savings_goal"
}

enum MoneyLogicV2AmountMode: String, Codable, CaseIterable, Sendable {
    case fixed
    case variable
    case estimateFromHistory = "estimate_from_history"
}

enum MoneyLogicV2Cadence: String, Codable, CaseIterable, Sendable {
    case weekly
    case biweekly
    case semimonthly
    case monthly
    case quarterly
    case yearly
    case custom
}

struct MoneyLogicV2RecurringSeries: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var merchantNormalized: String?
    var type: MoneyLogicV2RecurringType
    var accountId: String?
    var categoryId: String?
    var expectedAmount: Double
    var amountMode: MoneyLogicV2AmountMode
    var cadence: MoneyLogicV2Cadence
    var nextDueDate: Date
    var lastMatchedDate: Date?
    var autoDetected: Bool
    var userConfirmed: Bool
    var isActive: Bool
}

struct MoneyLogicV2BudgetMonth: Codable, Identifiable, Equatable, Sendable {
    var id: String { "\(month)-\(currency)" }
    var month: String
    var currency: String
    var openingBudgetCash: Double
    var expectedIncome: Double
    var actualIncome: Double
    var expectedIncomeRemaining: Double
    var fixedPlanned: Double
    var fixedPaid: Double
    var fixedRemaining: Double
    var nonMonthlySetAsidePlanned: Double
    var nonMonthlySpent: Double
    var goalContributionsPlanned: Double
    var goalContributionsActual: Double
    var debtMinimumsPlanned: Double
    var debtMinimumsPaid: Double
    var flexibleBudget: Double
    var flexibleSpent: Double
    var otherSpent: Double
    var safeToSpend: Double
    var dailySafeToSpend: Double
    var leftThisMonth: Double
    var netCashFlow: Double
    var createdAt: Date
    var updatedAt: Date
}

enum MoneyLogicV2UserMode: String, Codable, CaseIterable, Sendable {
    case focus
    case plan
    case envelope
}

enum MoneyLogicV2PaceStatus: String, Codable, Sendable {
    case underPace = "under_pace"
    case onTrack = "on_track"
    case slightlyHigh = "slightly_high"
    case overBudget = "over_budget"

    var calmLabel: String {
        switch self {
        case .underPace:
            return "You still have room"
        case .onTrack:
            return "On track"
        case .slightlyHigh:
            return "A little high"
        case .overBudget:
            return "Move money to cover this"
        }
    }
}

struct MoneyLogicV2SafeToSpendSummary: Equatable, Sendable {
    var trueSafeToSpend: Double
    var displaySafeToSpend: Double
    var dailySafeToSpend: Double
    var daysRemaining: Int
    var explanation: String
}

struct MoneyLogicV2FlexibleSpendingSummary: Equatable, Sendable {
    var flexibleBudget: Double
    var flexibleSpent: Double
    var flexibleRemaining: Double
    var paceExpected: Double
    var paceDelta: Double
    var status: MoneyLogicV2PaceStatus
}

struct MoneyLogicV2CategorySummary: Identifiable, Equatable, Sendable {
    var id: String { category.id }
    var category: MoneyLogicV2Category
    var assignedThisMonth: Double
    var spentThisMonth: Double
    var remaining: Double
    var isOverspent: Bool
}

enum MoneyLogicV2ReviewKind: String, Codable, Sendable {
    case uncategorized
    case suggestedCategory = "suggested_category"
    case possibleTransfer = "possible_transfer"
    case possibleRefund = "possible_refund"
    case possibleRecurring = "possible_recurring"
}

struct MoneyLogicV2ReviewItem: Identifiable, Equatable, Sendable {
    var id: String
    var kind: MoneyLogicV2ReviewKind
    var transactionIds: [String]
    var title: String
    var detail: String
    var confidence: MoneyLogicV2CategorizationConfidence
}

enum MoneyLogicV2WatchlistType: String, Codable, Sendable {
    case merchant
    case tag
    case category
}

struct MoneyLogicV2Watchlist: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var type: MoneyLogicV2WatchlistType
    var matchValue: String
    var monthlyLimit: Double?
    var isActive: Bool
}

struct MoneyLogicV2WatchlistSummary: Identifiable, Equatable, Sendable {
    var id: String { watchlist.id }
    var watchlist: MoneyLogicV2Watchlist
    var spentThisMonth: Double
    var transactionCount: Int
    var remaining: Double?
}

struct MoneyLogicV2UpcomingCommitment: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var dueDate: Date
    var amount: Double
    var type: MoneyLogicV2RecurringType
    var categoryId: String?
}

struct MoneyLogicV2DashboardSummary: Equatable, Sendable {
    var mode: MoneyLogicV2UserMode
    var safeToSpend: MoneyLogicV2SafeToSpendSummary
    var flexibleSpending: MoneyLogicV2FlexibleSpendingSummary
    var upcomingCommitments: [MoneyLogicV2UpcomingCommitment]
    var reviewQueue: [MoneyLogicV2ReviewItem]
    var watchlists: [MoneyLogicV2WatchlistSummary]
    var categorySummaries: [MoneyLogicV2CategorySummary]
    var goals: [MoneyLogicV2CategorySummary]
    var netWorth: Double
    var netCashFlow: Double
    var budgetMonth: MoneyLogicV2BudgetMonth
}

enum MoneyLogicV2Text {
    static func normalizedMerchant(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(co|corp|inc|llc|ltd|store|payment|purchase)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func similarityKey(_ merchant: String?, _ description: String?) -> String {
        let merchantKey = normalizedMerchant(merchant ?? "")
        if !merchantKey.isEmpty {
            return merchantKey
        }
        return normalizedMerchant(description ?? "")
    }
}
