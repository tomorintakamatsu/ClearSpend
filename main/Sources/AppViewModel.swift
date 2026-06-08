import SwiftUI
import Observation
import UIKit
import UserNotifications

enum AppDisplayBlock: String, CaseIterable, Hashable {
    case homeSafeToSpend
    case homeMonthlyPulse
    case homeReviewQueue
    case homeWatchlists
    case homeTopCategories
    case homeRecentActivity
    case activityFilter
    case activitySummary
    case goalsOverview
    case aiIntro
    case aiUsage
    case aiHistory
    case moreOverview
    case subscriptionsOverview
    case subscriptionsSuggestions
    case budgetOverview
    case budgetCategories
    case budgetIncomeChart
    case budgetKeyNumbers
}

struct WallpaperThemeProfile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var imageFileName: String
    var palette: WallpaperPalette
    var themeColorHex: String?
    var cardColorHex: String?
    var visibility: Double
    var blurRadius: Double
    var panelOpacity: Double
    var zoomPercent: Double
    var horizontalFrame: Double
    var verticalFrame: Double
    var createdAt: Date
}

struct StartFromTodaySummary: Equatable, Sendable {
    var trueSafeToSpend: Double
    var displaySafeToSpend: Double
    var dailySafeToSpend: Double
    var daysUntilNextIncome: Int
    var currentMoney: Double
    var billsDueBeforeNextIncome: Double
    var subscriptionCommitmentsBeforeNextIncome: Double
    var savingsDueBeforeNextIncome: Double
    var moneyToKeepUntouched: Double
    var totalProtectedBeforeNextIncome: Double
    var nextIncomeAmount: Double
    var nextIncomeDate: Date?
    var explanation: String
}

struct ReviewRecurringDisplay: Equatable, Sendable {
    var name: String
    var cadence: MoneyLogicV2Cadence
    var amount: Double
    var nextDueDate: Date
}

@MainActor
@Observable
final class AppViewModel {
    // MARK: - Persistent Preferences

    private let prefs = UserDefaults.standard
    private let hiddenDisplayBlocksKey = "hidden_display_blocks"
    private let homeDisplayBlockOrderKey = "home_display_block_order"
    private let wallpaperPaletteKey = "wallpaper_palette"
    private let wallpaperFileName = "pennylet_wallpaper_theme.jpg"
    private let wallpaperVisibilityKey = "wallpaper_visibility"
    private let wallpaperBlurRadiusKey = "wallpaper_blur_radius"
    private let wallpaperPanelOpacityKey = "wallpaper_panel_opacity"
    private let wallpaperZoomPercentKey = "wallpaper_zoom_percent"
    private let wallpaperHorizontalFrameKey = "wallpaper_horizontal_frame"
    private let wallpaperVerticalFrameKey = "wallpaper_vertical_frame"
    private let wallpaperProfilesKey = "wallpaper_profiles"
    private let activeWallpaperProfileIDKey = "active_wallpaper_profile_id"
    private let wallpaperProfilesFolderName = "WallpaperProfiles"
    private let customThemeColorHexKey = "custom_theme_color_hex"
    private let customThemeColorEnabledKey = "custom_theme_color_enabled"
    private let wallpaperThemeColorEnabledKey = "wallpaper_theme_color_enabled"
    private let wallpaperCardColorHexKey = "wallpaper_card_color_hex"
    private let wallpaperCardColorEnabledKey = "wallpaper_card_color_enabled"
    private let goalQuickAddAmountsKey = "goal_quick_add_amounts"
    private let customWatchlistsKey = "custom_watchlists"
    private let dismissedReviewItemIDsKey = "dismissed_review_item_ids"
    private let defaultGoalQuickAddAmounts: [Double] = [10, 50, 100, 500]

    func savePreferencesToDisk() {
        prefs.set(theme.rawValue, forKey: "app_theme")
        prefs.set(colorMode.rawValue, forKey: "app_color_mode")
        prefs.set(font.rawValue, forKey: "app_font")
        prefs.set(language, forKey: "app_language")
        prefs.set(currency, forKey: "app_currency")
        prefs.set(isUsingCustomThemeColor, forKey: customThemeColorEnabledKey)
        prefs.set(isUsingWallpaperThemeColor, forKey: wallpaperThemeColorEnabledKey)
        prefs.set(hexString(from: customThemeColor), forKey: customThemeColorHexKey)
        prefs.set(isUsingWallpaperCardColor, forKey: wallpaperCardColorEnabledKey)
        prefs.set(hexString(from: wallpaperCardColor), forKey: wallpaperCardColorHexKey)
        saveGoalQuickAddAmounts()
        saveCustomWatchlists()
        saveDismissedReviewItemIDs()
        saveDisplayBlockPreferences()
    }

    func loadPreferencesFromDisk() {
        if let t = prefs.string(forKey: "app_theme"), let th = AppTheme(rawValue: t) { theme = th }
        if let c = prefs.string(forKey: "app_color_mode"), let cm = AppColorMode(rawValue: c) { colorMode = cm }
        if let f = prefs.string(forKey: "app_font"), let fn = AppFont(rawValue: f) { font = fn }
        if let l = prefs.string(forKey: "app_language") { language = l }
        if let cr = prefs.string(forKey: "app_currency") { currency = cr }
        if let hex = prefs.string(forKey: customThemeColorHexKey) { customThemeColor = Color(hex: hex) }
        isUsingCustomThemeColor = prefs.bool(forKey: customThemeColorEnabledKey)
        isUsingWallpaperThemeColor = prefs.bool(forKey: wallpaperThemeColorEnabledKey)
        if let hex = prefs.string(forKey: wallpaperCardColorHexKey) { wallpaperCardColor = Color(hex: hex) }
        isUsingWallpaperCardColor = prefs.bool(forKey: wallpaperCardColorEnabledKey)
        loadGoalQuickAddAmounts()
        loadCustomWatchlists()
        loadDismissedReviewItemIDs()
        loadWallpaperProfiles()
        loadWallpaperAppearance()
        loadWallpaperTheme()
        loadDisplayBlockPreferences()
        isDeveloperMode = prefs.bool(forKey: developerModeKey)
    }

    // Data
    var transactions: [Transaction] = []
    var budgets: [Budget] = []
    var goals: [Goal] = []
    var analysisHistory: [AnalysisHistory] = []
    var recurringSubscriptions: [RecurringSubscription] = []
    var user: User?
    var customWatchlists: [String] = []
    var dismissedReviewItemIDs: Set<String> = []

    // Loading
    var isLoading = true
    var isLoadingData = false
    var error: String?
    var navigateToTab: Int?
    var initialAISubTab: Int?
    var currentDailyResult: AIResult?
    var currentWeeklyResult: AIResult?
    var currentMonthlyResult: AIResult?
    var currentForecastResult: AIResult?
    @ObservationIgnored private var cachedLocalMoneyLogicV2Dashboard: MoneyLogicV2DashboardSummary?
    @ObservationIgnored private var cachedLocalMoneyLogicV2Revision: Int?
    @ObservationIgnored private var cachedLocalMoneyLogicV2MonthIdentifier: String?
    @ObservationIgnored private var localMoneyLogicV2Revision = 0

    func loadLocalData() {
        let decoder = JSONDecoder()
        if let data = prefs.data(forKey: "local_budgets"),
           let b = try? decoder.decode([Budget].self, from: data), !b.isEmpty {
            budgets = b
        }
        if let data = prefs.data(forKey: "local_transactions"),
           let t = try? decoder.decode([Transaction].self, from: data) {
            transactions = t
        }
        if let data = prefs.data(forKey: "local_goals"),
           let g = try? decoder.decode([Goal].self, from: data) {
            goals = g
        }
        if let data = prefs.data(forKey: "local_analysis_history"),
           let h = try? decoder.decode([AnalysisHistory].self, from: data) {
            analysisHistory = h
        }
        if let data = prefs.data(forKey: "local_recurring_subscriptions"),
           let subs = try? decoder.decode([RecurringSubscription].self, from: data) {
            recurringSubscriptions = subs
        }
        applyBudgetPreferences()
        postDueRecurringSubscriptions()
    }

    func checkAndNotifyBudgetAlerts() {
        guard let budget = currentBudget,
              budget.budgetAlertsEnabled == true,
              budget.budgetAlertsPushEnabled == true else { return }
        let svc = NotificationService()
        svc.scheduleBudgetAlert(summary: dashboardSpendSummary, currency: currency)
    }

    func saveLocalData() {
        invalidateLocalMoneyLogicV2Cache()
        if let data = try? JSONEncoder().encode(budgets) {
            prefs.set(data, forKey: "local_budgets")
        }
        if let data = try? JSONEncoder().encode(transactions) {
            prefs.set(data, forKey: "local_transactions")
        }
        if let data = try? JSONEncoder().encode(goals) {
            prefs.set(data, forKey: "local_goals")
        }
        if let data = try? JSONEncoder().encode(analysisHistory) {
            prefs.set(data, forKey: "local_analysis_history")
        }
        if let data = try? JSONEncoder().encode(recurringSubscriptions) {
            prefs.set(data, forKey: "local_recurring_subscriptions")
        }
        prefs.synchronize()
    }

    @discardableResult
    func importTransactionsCSV(content: String) -> Int {
        let rows = MoneyLogicV2CSVImport.parse(content)
        guard !rows.isEmpty else { return 0 }

        let headers = rows[0]
        let hasHeader = headers.map(csvHeaderKey).contains("date")
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        var importedCount = 0

        for columns in dataRows where columns.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            let row = hasHeader ? csvRow(headers: headers, columns: columns) : [:]

            guard let date = csvValue(["date"], row: row, columns: columns, fallbackIndex: 0) else { continue }
            let typeText = csvValue(["type", "transaction_type"], row: row, columns: columns, fallbackIndex: 1) ?? ""
            let amount = csvSignedAmount(row: row, columns: columns)
            guard let amount, abs(amount) > 0 else { continue }

            let tagText = csvValue(["tags", "tag"], row: row, columns: columns, fallbackIndex: 11)
            var tags = csvTags(from: tagText)
            let account = csvValue(["account", "account_name"], row: row, columns: columns, fallbackIndex: 9)
            if let account, !account.isEmpty {
                tags.append("account:\(csvHeaderKey(account))")
            }

            let type = csvLegacyTransactionType(typeText: typeText, amount: amount, tags: tags)
            let rawCategory = csvValue(["category", "classification"], row: row, columns: columns, fallbackIndex: 2)
            let category = AppCategory.normalizedCategoryID(for: rawCategory, type: type)
            let merchant = csvValue(["merchant", "payee", "vendor"], row: row, columns: columns, fallbackIndex: 5)
            let note = csvValue(["note", "notes", "memo"], row: row, columns: columns, fallbackIndex: 4)
            let description = csvValue(["description", "details"], row: row, columns: columns, fallbackIndex: 10)
            let normalizedType = csvHeaderKey(typeText)
            if !normalizedType.isEmpty {
                tags.append(normalizedType)
            }
            if category == "subscriptions" || tags.contains("subscription") {
                tags.append("subscription")
            }

            let origCurrency = csvValue(["original_currency", "originalcurrency"], row: row, columns: columns, fallbackIndex: 6)
            let origAmount = csvValue(["original_amount", "originalamount"], row: row, columns: columns, fallbackIndex: 7).flatMap(csvParseAmount)
            let exchangeRate = csvValue(["exchange_rate", "exchangerate"], row: row, columns: columns, fallbackIndex: 8).flatMap(csvParseAmount)

            let txn = Transaction(
                id: "import-\(UUID().uuidString)",
                amount: abs(amount),
                type: type,
                category: category,
                note: note,
                date: date,
                merchant: merchant,
                description: description,
                isRecurring: tags.contains("subscription"),
                tags: Array(Set(tags)).sorted(),
                originalCurrency: origCurrency?.isEmpty == false ? origCurrency : nil,
                originalAmount: origAmount,
                exchangeRate: exchangeRate,
                baseCurrency: origCurrency?.isEmpty == false ? currency : nil
            )
            transactions.append(txn)
            importedCount += 1
        }

        if importedCount > 0 {
            saveLocalData()
        }
        return importedCount
    }

    private func csvRow(headers: [String], columns: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
            (csvHeaderKey(header), index < columns.count ? columns[index] : "")
        })
    }

    private func csvValue(
        _ names: [String],
        row: [String: String],
        columns: [String],
        fallbackIndex: Int
    ) -> String? {
        for name in names {
            if let value = row[csvHeaderKey(name)]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        guard fallbackIndex < columns.count else { return nil }
        let value = columns[fallbackIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func csvHeaderKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func csvSignedAmount(row: [String: String], columns: [String]) -> Double? {
        if let amountText = csvValue(["amount", "transaction_amount"], row: row, columns: columns, fallbackIndex: 3),
           let amount = csvParseAmount(amountText) {
            return amount
        }

        let debit = csvValue(["debit", "withdrawal", "spent"], row: row, columns: columns, fallbackIndex: Int.max)
            .flatMap(csvParseAmount) ?? 0
        let credit = csvValue(["credit", "deposit", "received"], row: row, columns: columns, fallbackIndex: Int.max)
            .flatMap(csvParseAmount) ?? 0
        if debit != 0 || credit != 0 {
            return credit - debit
        }
        return nil
    }

    private func csvParseAmount(_ rawValue: String) -> Double? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var negative = false
        if value.hasPrefix("("), value.hasSuffix(")") {
            negative = true
            value.removeFirst()
            value.removeLast()
        }
        value = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
        guard let amount = Double(value) else { return nil }
        return negative ? -amount : amount
    }

    private func csvTags(from value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split { $0 == "," || $0 == ";" || $0 == "|" }
            .map { csvHeaderKey(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func csvLegacyTransactionType(typeText: String, amount: Double, tags: [String]) -> Transaction.TransactionType {
        let type = csvHeaderKey(typeText)
        if type.contains("income") || type.contains("paycheck") || type.contains("refund") || type.contains("reimbursement") {
            return .income
        }
        if type.contains("transfer") || type.contains("credit_card_payment") {
            return tags.contains(where: { $0.hasSuffix("_in") || $0.contains("payment_in") || $0.contains("transfer_in") }) ? .income : .expense
        }
        if type.contains("expense") || type.contains("adjustment") {
            return .expense
        }
        return amount >= 0 ? .income : .expense
    }

    // Preferences (synced from Budget)
    var theme: AppTheme = .sage
    var wallpaperPalette: WallpaperPalette?
    var wallpaperImageData: Data?
    var wallpaperUIImage: UIImage?
    var wallpaperVisibility: Double = 100
    var wallpaperBlurRadius: Double = 0
    var wallpaperPanelOpacity: Double = 85
    var wallpaperZoomPercent: Double = 0
    var wallpaperHorizontalFrame: Double = 50
    var wallpaperVerticalFrame: Double = 50
    var wallpaperProfiles: [WallpaperThemeProfile] = []
    var activeWallpaperProfileID: String?
    var wallpaperProfileImages: [String: UIImage] = [:]
    var colorMode: AppColorMode = .system
    var font: AppFont = .inter
    var customThemeColor: Color = Color(hex: "0d9488")
    var isUsingCustomThemeColor = false
    var isUsingWallpaperThemeColor = false
    var wallpaperCardColor: Color = Color(hex: "0d9488")
    var isUsingWallpaperCardColor = false
    var goalQuickAddAmounts: [Double] = [10, 50, 100, 500]
    var currency: String = "USD"
    var language: String = "en" {
        didSet { CurrencyFormat.language = language }
    }
    private(set) var hiddenDisplayBlocks: Set<AppDisplayBlock> = []
    private(set) var homeDisplayBlockOrder: [AppDisplayBlock] = AppViewModel.defaultHomeDisplayBlockOrder

    static let defaultHomeDisplayBlockOrder: [AppDisplayBlock] = [
        .homeSafeToSpend,
        .homeMonthlyPulse,
        .homeReviewQueue,
        .homeWatchlists,
        .homeTopCategories,
        .homeRecentActivity
    ]

    var primaryColor: Color {
        if isUsingWallpaperThemeColor, let wallpaperPalette {
            return wallpaperPalette.primaryColor
        }
        return isUsingCustomThemeColor ? customThemeColor : theme.primaryColor
    }

    var accentColor: Color {
        if isUsingWallpaperThemeColor, let wallpaperPalette {
            return wallpaperPalette.accentColor
        }
        return isUsingCustomThemeColor ? customThemeColor.opacity(0.62) : theme.accentColor
    }

    var backgroundColor: Color {
        wallpaperPalette?.backgroundColor ?? Color(.systemGroupedBackground)
    }

    var cardBoxColor: Color {
        hasWallpaperTheme && isUsingWallpaperCardColor ? wallpaperCardColor : primaryColor
    }

    var gradientColors: [Color] {
        [primaryColor, primaryColor.opacity(0.82), accentColor.opacity(0.86)]
    }

    var hasWallpaperTheme: Bool {
        wallpaperPalette != nil && wallpaperImageData != nil && wallpaperUIImage != nil
    }

    var activeWallpaperProfile: WallpaperThemeProfile? {
        guard let activeWallpaperProfileID else { return nil }
        return wallpaperProfiles.first(where: { $0.id == activeWallpaperProfileID })
    }

    func selectTheme(_ appTheme: AppTheme) {
        theme = appTheme
        isUsingCustomThemeColor = false
        isUsingWallpaperThemeColor = false
    }

    func setCustomThemeColor(_ color: Color) {
        customThemeColor = color
        isUsingCustomThemeColor = true
        isUsingWallpaperThemeColor = false
    }

    func useWallpaperThemeColors() {
        guard wallpaperPalette != nil else { return }
        isUsingCustomThemeColor = false
        isUsingWallpaperThemeColor = true
    }

    var wallpaperThemeColorOptions: [Color] {
        guard let wallpaperPalette else { return [] }
        return wallpaperThemeHexOptions(for: wallpaperPalette).map(Color.init(hex:))
    }

    var wallpaperCardColorOptions: [Color] {
        guard let wallpaperPalette else { return [] }
        return wallpaperCardHexOptions(for: wallpaperPalette).map(Color.init(hex:))
    }

    func selectWallpaperThemeColor(_ color: Color, usesExtractedPalette: Bool) {
        if usesExtractedPalette {
            useWallpaperThemeColors()
        } else {
            setCustomThemeColor(color)
        }
        updateActiveWallpaperProfileColorChoices()
        savePreferencesToDisk()
    }

    func selectWallpaperCardColor(_ color: Color) {
        wallpaperCardColor = color
        isUsingWallpaperCardColor = true
        updateActiveWallpaperProfileColorChoices()
        savePreferencesToDisk()
    }

    func setGoalQuickAddAmount(at index: Int, amount: Double) {
        guard goalQuickAddAmounts.indices.contains(index), amount > 0 else { return }
        goalQuickAddAmounts[index] = amount
        saveGoalQuickAddAmounts()
    }

    var wallpaperVisibilityOpacity: Double {
        clampedPercent(wallpaperVisibility) / 100
    }

    var wallpaperPanelOpacityValue: Double {
        clampedPercent(wallpaperPanelOpacity) / 100
    }

    var wallpaperZoomScale: CGFloat {
        1 + CGFloat(clampedPercent(wallpaperZoomPercent) / 100 * 1.6)
    }

    var wallpaperBlurValue: CGFloat {
        CGFloat(clampedPercent(wallpaperBlurRadius))
    }

    func wallpaperFrameOffset(in size: CGSize) -> CGSize {
        let horizontal = (clampedPercent(wallpaperHorizontalFrame) - 50) / 50
        let vertical = (clampedPercent(wallpaperVerticalFrame) - 50) / 50
        let travel = 0.08 + (clampedPercent(wallpaperZoomPercent) / 100 * 0.58)
        return CGSize(width: size.width * travel * horizontal, height: size.height * travel * vertical)
    }

    func isBlockVisible(_ block: AppDisplayBlock) -> Bool {
        !hiddenDisplayBlocks.contains(block)
    }

    var visibleHomeBlocks: [AppDisplayBlock] {
        normalizedHomeDisplayBlockOrder().filter(isBlockVisible)
    }

    func setBlock(_ block: AppDisplayBlock, visible: Bool) {
        if visible {
            hiddenDisplayBlocks.remove(block)
        } else {
            hiddenDisplayBlocks.insert(block)
        }
        saveDisplayBlockPreferences()
    }

    func moveHomeBlock(fromOffsets source: IndexSet, toOffset destination: Int) {
        var order = normalizedHomeDisplayBlockOrder()
        order.move(fromOffsets: source, toOffset: destination)
        homeDisplayBlockOrder = order
        saveDisplayBlockPreferences()
    }

    func resetHomeBlockLayout() {
        for block in Self.defaultHomeDisplayBlockOrder {
            hiddenDisplayBlocks.remove(block)
        }
        homeDisplayBlockOrder = Self.defaultHomeDisplayBlockOrder
        saveDisplayBlockPreferences()
    }

    func addCustomWatchlist(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !customWatchlists.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { return }
        customWatchlists.insert(name, at: 0)
        customWatchlists = Array(customWatchlists.prefix(5))
        invalidateLocalMoneyLogicV2Cache()
        saveCustomWatchlists()
    }

    func deleteCustomWatchlist(_ name: String) {
        customWatchlists.removeAll { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }
        invalidateLocalMoneyLogicV2Cache()
        saveCustomWatchlists()
    }

    private func saveCustomWatchlists() {
        prefs.set(customWatchlists, forKey: customWatchlistsKey)
    }

    private func loadCustomWatchlists() {
        let values = prefs.stringArray(forKey: customWatchlistsKey) ?? []
        var seen: Set<String> = []
        customWatchlists = values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = MoneyLogicV2Text.normalizedMerchant(trimmed)
            guard !trimmed.isEmpty, !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return trimmed
        }
    }

    var reviewQueue: [MoneyLogicV2ReviewItem] {
        localMoneyLogicV2Dashboard.reviewQueue.filter { !dismissedReviewItemIDs.contains($0.id) }
    }

    func dismissReviewItem(_ item: MoneyLogicV2ReviewItem) {
        dismissedReviewItemIDs.insert(item.id)
        saveDismissedReviewItemIDs()
    }

    func recurringReviewDisplay(for item: MoneyLogicV2ReviewItem) -> ReviewRecurringDisplay? {
        guard item.kind == .possibleRecurring,
              let series = recurringCandidate(for: item) else {
            return nil
        }
        return ReviewRecurringDisplay(
            name: series.name,
            cadence: series.cadence,
            amount: series.expectedAmount,
            nextDueDate: series.nextDueDate
        )
    }

    func acceptReviewTransfer(_ item: MoneyLogicV2ReviewItem) {
        guard item.kind == .possibleTransfer else {
            dismissReviewItem(item)
            return
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let transactionIDs = Set(item.transactionIds)
        let category = item.title == "Possible credit card payment" ? "credit_card_payment" : "transfer"
        var changed = false

        for index in transactions.indices where transactionIDs.contains(transactions[index].id) {
            var tags = Set(transactions[index].tags ?? [])
            tags.insert("transfer")
            tags.insert("review_confirmed")
            tags.insert("review:\(item.id)")
            transactions[index].category = category
            transactions[index].tags = Array(tags).sorted()
            transactions[index].updatedDate = now
            changed = true
        }

        dismissReviewItem(item)
        if changed {
            saveLocalData()
        }
    }

    func acceptReviewRefund(_ item: MoneyLogicV2ReviewItem) {
        guard item.kind == .possibleRefund,
              let refundID = item.transactionIds.first,
              let expenseID = item.transactionIds.dropFirst().first else {
            dismissReviewItem(item)
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let originalCategory = transactions.first(where: { $0.id == expenseID })?.category
        let marker = item.title == "Possible reimbursement" ? "reimbursement" : "refund"
        var changed = false

        if let refundIndex = transactions.firstIndex(where: { $0.id == refundID }) {
            var tags = Set(transactions[refundIndex].tags ?? [])
            tags.insert(marker)
            tags.insert("\(marker)_of:\(expenseID)")
            tags.insert("review_confirmed")
            transactions[refundIndex].category = originalCategory ?? marker
            transactions[refundIndex].tags = Array(tags).sorted()
            transactions[refundIndex].updatedDate = now
            changed = true
        }

        if let expenseIndex = transactions.firstIndex(where: { $0.id == expenseID }) {
            var tags = Set(transactions[expenseIndex].tags ?? [])
            tags.insert("linked_\(marker):\(refundID)")
            transactions[expenseIndex].tags = Array(tags).sorted()
            transactions[expenseIndex].updatedDate = now
            changed = true
        }

        dismissReviewItem(item)
        if changed {
            saveLocalData()
        }
    }

    func acceptReviewRecurring(_ item: MoneyLogicV2ReviewItem) {
        guard item.kind == .possibleRecurring,
              let series = recurringCandidate(for: item) else {
            dismissReviewItem(item)
            return
        }

        let normalizedName = MoneyLogicV2Text.normalizedMerchant(series.name)
        let alreadyTracked = recurringSubscriptions.contains { subscription in
            subscription.isActive &&
                MoneyLogicV2Text.normalizedMerchant(subscription.name) == normalizedName &&
                abs(subscription.amount - series.expectedAmount) < 0.01
        }
        guard !alreadyTracked else {
            dismissReviewItem(item)
            return
        }

        let interval = billingInterval(for: series.cadence)
        let now = ISO8601DateFormatter().string(from: Date())
        let subscription = RecurringSubscription(
            id: UUID().uuidString,
            name: series.name,
            amount: series.expectedAmount,
            currencyCode: currency,
            category: series.categoryId ?? "subscriptions",
            note: loc("Detected from local transactions"),
            startDate: dateString(series.lastMatchedDate ?? Date()),
            nextBillingDate: dateString(series.nextDueDate),
            interval: interval.interval,
            customIntervalDays: interval.customDays,
            isActive: true,
            createdDate: now,
            updatedDate: now
        )

        recurringSubscriptions.insert(subscription, at: 0)
        dismissReviewItem(item)
        saveLocalData()
    }

    private func saveDismissedReviewItemIDs() {
        prefs.set(Array(dismissedReviewItemIDs).sorted(), forKey: dismissedReviewItemIDsKey)
    }

    private func loadDismissedReviewItemIDs() {
        dismissedReviewItemIDs = Set(prefs.stringArray(forKey: dismissedReviewItemIDsKey) ?? [])
    }

    private func recurringCandidate(for item: MoneyLogicV2ReviewItem) -> MoneyLogicV2RecurringSeries? {
        let categories = MoneyLogicV2DataAdapter.defaultCategories(
            budget: currentBudget,
            goals: goals,
            transactions: transactions,
            currency: currency
        )
        let v2Transactions = transactions.map {
            MoneyLogicV2DataAdapter.makeTransaction($0, currency: currency, categories: categories)
        }
        return MoneyLogicV2Detection
            .detectRecurringSeries(transactions: v2Transactions)
            .first { "recurring-\($0.id)" == item.id }
    }

    private func billingInterval(for cadence: MoneyLogicV2Cadence) -> (interval: RecurringSubscription.BillingInterval, customDays: Int?) {
        switch cadence {
        case .weekly:
            return (.weekly, nil)
        case .biweekly:
            return (.biweekly, nil)
        case .monthly, .semimonthly:
            return (.monthly, nil)
        case .quarterly:
            return (.custom, 91)
        case .yearly:
            return (.custom, 365)
        case .custom:
            return (.custom, 30)
        }
    }

    private func saveDisplayBlockPreferences() {
        prefs.set(hiddenDisplayBlocks.map(\.rawValue).sorted(), forKey: hiddenDisplayBlocksKey)
        prefs.set(normalizedHomeDisplayBlockOrder().map(\.rawValue), forKey: homeDisplayBlockOrderKey)
    }

    private func loadDisplayBlockPreferences() {
        let rawValues = prefs.stringArray(forKey: hiddenDisplayBlocksKey) ?? []
        hiddenDisplayBlocks = Set(rawValues.compactMap(AppDisplayBlock.init(rawValue:)))
        let orderedRawValues = prefs.stringArray(forKey: homeDisplayBlockOrderKey) ?? []
        let loadedOrder = orderedRawValues.compactMap(AppDisplayBlock.init(rawValue:)).filter(Self.defaultHomeDisplayBlockOrder.contains)
        homeDisplayBlockOrder = normalizedHomeDisplayBlockOrder(from: loadedOrder)
    }

    private func normalizedHomeDisplayBlockOrder() -> [AppDisplayBlock] {
        normalizedHomeDisplayBlockOrder(from: homeDisplayBlockOrder)
    }

    private func normalizedHomeDisplayBlockOrder(from order: [AppDisplayBlock]) -> [AppDisplayBlock] {
        var seen: Set<AppDisplayBlock> = []
        var normalized: [AppDisplayBlock] = []
        for block in order where Self.defaultHomeDisplayBlockOrder.contains(block) && !seen.contains(block) {
            normalized.append(block)
            seen.insert(block)
        }
        for block in Self.defaultHomeDisplayBlockOrder where !seen.contains(block) {
            normalized.append(block)
        }
        return normalized
    }

    // Developer mode
    private let developerModeKey = "developer_mode_enabled"
    var isDeveloperMode = false {
        didSet { prefs.set(isDeveloperMode, forKey: developerModeKey) }
    }

    // Usage limit alerts
    private let aiClient = AIClient.shared
    private let aiUserFacingTimeoutNanoseconds: UInt64 = 7_000_000_000
    let revenueCat = RevenueCatService()
    let proStatus = ProStatusService()

    var currentBudget: Budget? { budgets.first }

    var localMoneyLogicV2Dashboard: MoneyLogicV2DashboardSummary {
        let monthIdentifier = MoneyLogicV2Calculations.monthIdentifier(for: Date())
        if let cachedLocalMoneyLogicV2Dashboard,
           cachedLocalMoneyLogicV2Revision == localMoneyLogicV2Revision,
           cachedLocalMoneyLogicV2MonthIdentifier == monthIdentifier {
            return cachedLocalMoneyLogicV2Dashboard
        }

        let input = MoneyLogicV2DataAdapter.dashboardInput(
            budget: currentBudget,
            transactions: transactions,
            goals: goals,
            recurringSubscriptions: recurringSubscriptions,
            customWatchlists: customWatchlists,
            currency: currency,
            mode: .plan
        )
        let dashboard = LocalFirstMoneyLogicV2Service().getDashboardSummary(input: input)
        cachedLocalMoneyLogicV2Revision = localMoneyLogicV2Revision
        cachedLocalMoneyLogicV2MonthIdentifier = monthIdentifier
        cachedLocalMoneyLogicV2Dashboard = dashboard
        return dashboard
    }

    var dashboardSpendSummary: SpendSummary {
        if let startFromTodaySummary {
            let protectedMoney = startFromTodaySummary.billsDueBeforeNextIncome
                + startFromTodaySummary.subscriptionCommitmentsBeforeNextIncome
                + startFromTodaySummary.savingsDueBeforeNextIncome
                + startFromTodaySummary.moneyToKeepUntouched
            let denominator = max(startFromTodaySummary.currentMoney, protectedMoney + max(startFromTodaySummary.trueSafeToSpend, 0))
            return SpendSummary(
                spent: protectedMoney,
                incomeThisMonth: startFromTodaySummary.nextIncomeAmount,
                monthlyDisposable: denominator,
                remaining: startFromTodaySummary.trueSafeToSpend,
                daysLeft: startFromTodaySummary.daysUntilNextIncome,
                safeDaily: startFromTodaySummary.dailySafeToSpend,
                paceDiff: 0,
                expectedSpent: protectedMoney,
                dayOfMonth: startFromTodaySummary.daysUntilNextIncome,
                totalDays: startFromTodaySummary.daysUntilNextIncome,
                spendPercent: denominator > 0 ? min((protectedMoney / denominator) * 100, 100) : 0
            )
        }

        let dashboard = localMoneyLogicV2Dashboard
        let month = dashboard.budgetMonth
        let includedSpend = month.fixedPaid
            + month.flexibleSpent
            + month.nonMonthlySpent
            + month.goalContributionsActual
            + month.debtMinimumsPaid
            + month.otherSpent
        let monthlyPlan = max(
            month.fixedPlanned
                + month.flexibleBudget
                + month.nonMonthlySetAsidePlanned
                + month.goalContributionsPlanned
                + month.debtMinimumsPlanned,
            month.expectedIncome + month.openingBudgetCash
        )

        return SpendSummary(
            spent: includedSpend,
            incomeThisMonth: month.actualIncome,
            monthlyDisposable: monthlyPlan,
            remaining: month.safeToSpend,
            daysLeft: dashboard.safeToSpend.daysRemaining,
            safeDaily: dashboard.safeToSpend.dailySafeToSpend,
            paceDiff: dashboard.flexibleSpending.paceDelta,
            expectedSpent: dashboard.flexibleSpending.paceExpected,
            dayOfMonth: Calendar.current.component(.day, from: Date()),
            totalDays: Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30,
            spendPercent: monthlyPlan > 0 ? min((includedSpend / monthlyPlan) * 100, 100) : 0
        )
    }

    var startFromTodaySummary: StartFromTodaySummary? {
        guard let budget = currentBudget else {
            return nil
        }

        let currentMoney = (budget.currentSpendableBalance ?? 0) + (budget.cashOnHand ?? 0)
        let nextDate = activeNextIncomeDate(for: budget)
        let subscriptionCommitments = subscriptionCommitmentsBeforeNextIncome(nextDate: nextDate)
        let enteredBills = budget.billsDueBeforeNextIncome ?? 0
        let savingsDue = budget.savingsDueBeforeNextIncome ?? 0
        let protectedMoney = enteredBills
            + subscriptionCommitments
            + savingsDue
            + (budget.moneyToKeepUntouched ?? 0)
        let safe = MoneyLogicV2Calculations.safeUntilNextIncome(
            currentSpendableBalance: budget.currentSpendableBalance ?? 0,
            cashOnHand: budget.cashOnHand ?? 0,
            billsDueBeforeNextIncome: enteredBills + subscriptionCommitments,
            savingsDueBeforeNextIncome: savingsDue,
            requiredBuffer: budget.moneyToKeepUntouched ?? 0,
            nextIncomeDate: nextDate
        )

        return StartFromTodaySummary(
            trueSafeToSpend: safe.trueSafeToSpend,
            displaySafeToSpend: safe.displaySafeToSpend,
            dailySafeToSpend: safe.dailySafeToSpend,
            daysUntilNextIncome: safe.daysRemaining,
            currentMoney: currentMoney,
            billsDueBeforeNextIncome: enteredBills,
            subscriptionCommitmentsBeforeNextIncome: subscriptionCommitments,
            savingsDueBeforeNextIncome: savingsDue,
            moneyToKeepUntouched: budget.moneyToKeepUntouched ?? 0,
            totalProtectedBeforeNextIncome: protectedMoney,
            nextIncomeAmount: budget.nextIncomeAmount ?? budget.monthlyIncome,
            nextIncomeDate: nextDate,
            explanation: safe.explanation
        )
    }

    static func storedDateString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func dateFromStoredString(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func activeNextIncomeDate(for budget: Budget, today: Date = Date(), calendar: Calendar = .current) -> Date {
        if let stored = budget.nextIncomeDate.flatMap(Self.dateFromStoredString),
           calendar.startOfDay(for: stored) >= calendar.startOfDay(for: today) {
            return stored
        }
        return nextPaydayDate(day: budget.payDay ?? 1, from: today, calendar: calendar)
    }

    private func subscriptionCommitmentsBeforeNextIncome(nextDate: Date, today: Date = Date(), calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: today)
        let horizon = calendar.startOfDay(for: nextDate)
        guard horizon >= start else { return 0 }

        return recurringSubscriptions
            .filter { subscription in
                guard subscription.isActive else { return false }
                guard subscription.currencyCode == currency else { return false }
                guard let dueDate = Self.dateFromStoredString(subscription.nextBillingDate) else { return false }
                let dueDay = calendar.startOfDay(for: dueDate)
                return dueDay >= start && dueDay <= horizon
            }
            .reduce(0) { $0 + $1.amount }
    }

    private func nextPaydayDate(day: Int, from today: Date = Date(), calendar: Calendar = .current) -> Date {
        let safeDay = min(max(day, 1), 31)
        var components = calendar.dateComponents([.year, .month], from: today)
        let daysInCurrentMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        components.day = min(safeDay, daysInCurrentMonth)
        let currentMonthPayday = calendar.date(from: components) ?? today
        if calendar.startOfDay(for: currentMonthPayday) >= calendar.startOfDay(for: today) {
            return currentMonthPayday
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) else {
            return currentMonthPayday
        }
        components = calendar.dateComponents([.year, .month], from: nextMonth)
        let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 30
        components.day = min(safeDay, daysInNextMonth)
        return calendar.date(from: components) ?? currentMonthPayday
    }

    private func invalidateLocalMoneyLogicV2Cache() {
        localMoneyLogicV2Revision &+= 1
        cachedLocalMoneyLogicV2Dashboard = nil
        cachedLocalMoneyLogicV2Revision = nil
        cachedLocalMoneyLogicV2MonthIdentifier = nil
    }

    var categoryBreakdown: [CategoryBreakdown] {
        var breakdown: [CategoryBreakdown] = []
        for summary in localMoneyLogicV2Dashboard.categorySummaries {
            guard summary.spentThisMonth > 0 else { continue }
            switch summary.category.bucketType {
            case .income, .transfer, .excluded:
                continue
            default:
                breakdown.append(CategoryBreakdown(id: summary.category.id, amount: summary.spentThisMonth))
            }
        }
        return breakdown.sorted { $0.amount > $1.amount }
    }

    var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    /// Set by StoreKit purchase/restore. Persisted in UserDefaults.
    var hasProSubscription: Bool {
        get { prefs.bool(forKey: "has_pro_subscription") }
        set { prefs.set(newValue, forKey: "has_pro_subscription") }
    }

    var isPro: Bool {
        isDeveloperMode || hasProSubscription
    }

    func canUseFeature(_ feature: String) -> Bool {
        if isDeveloperMode { return true }
        return remainingUses(feature) > 0
    }

    func setDeveloperMode(_ enabled: Bool) {
        isDeveloperMode = enabled
    }

    private var aiModelTier: AIModelTier {
        isPro ? .pro : .standard
    }

    func remainingUses(_ feature: String) -> Int {
        let counts = localUsageCounts
        let used = counts[feature] ?? 0
        let limit = usageLimit(feature)
        return max(0, limit - used)
    }

    func usageLimit(_ feature: String) -> Int {
        proStatus.limitFor(feature: feature, isPro: isPro)
    }

    private var localUsageCounts: [String: Int] {
        get {
            guard let data = prefs.data(forKey: "usage_counts"),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                prefs.set(data, forKey: "usage_counts")
            }
        }
    }

    func incrementUsage(_ feature: String) async {
        var counts = localUsageCounts
        // Reset if new month
        let currentMonth = {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM"
            return df.string(from: Date())
        }()
        if prefs.string(forKey: "usage_month") != currentMonth {
            counts = [:]
            prefs.set(currentMonth, forKey: "usage_month")
        }
        counts[feature] = (counts[feature] ?? 0) + 1
        localUsageCounts = counts
    }

    var needsResetToSetup = false

    func restoreDefaults() {
        let savedLanguage = prefs.string(forKey: "app_language") ?? "en"
        transactions = []
        budgets = []
        goals = []
        analysisHistory = []
        recurringSubscriptions = []
        user = nil
        error = nil
        navigateToTab = nil
        initialAISubTab = nil
        currentDailyResult = nil
        currentWeeklyResult = nil
        currentMonthlyResult = nil
        currentForecastResult = nil
        theme = .sage
        isUsingCustomThemeColor = false
        isUsingWallpaperThemeColor = false
        customThemeColor = Color(hex: "0d9488")
        wallpaperCardColor = Color(hex: "0d9488")
        isUsingWallpaperCardColor = false
        colorMode = .system
        font = .inter
        currency = "USD"
        language = savedLanguage
        clearWallpaperTheme()
        clearAllWallpaperProfiles()
        hiddenDisplayBlocks.removeAll()
        homeDisplayBlockOrder = Self.defaultHomeDisplayBlockOrder
        customWatchlists = []
        dismissedReviewItemIDs = []
        goalQuickAddAmounts = defaultGoalQuickAddAmounts
        isDeveloperMode = false
        hasProSubscription = false
        clearResettablePreferenceKeys()
        savePreferencesToDisk()
        saveLocalData()
        clearScheduledAppNotifications()
        let cache = CacheService.shared
        Task { await cache.clear() }
        needsResetToSetup = true
    }

    private func clearResettablePreferenceKeys() {
        [
            "local_budgets",
            "local_transactions",
            "local_goals",
            "local_analysis_history",
            "local_recurring_subscriptions",
            "usage_counts",
            "usage_month",
            "has_pro_subscription",
            developerModeKey,
            hiddenDisplayBlocksKey,
            homeDisplayBlockOrderKey,
            "app_theme",
            "app_color_mode",
            "app_font",
            "app_currency",
            customThemeColorHexKey,
            customThemeColorEnabledKey,
            wallpaperThemeColorEnabledKey,
            wallpaperCardColorHexKey,
            wallpaperCardColorEnabledKey,
            goalQuickAddAmountsKey,
            wallpaperPaletteKey,
            wallpaperVisibilityKey,
            wallpaperBlurRadiusKey,
            wallpaperPanelOpacityKey,
            wallpaperZoomPercentKey,
            wallpaperHorizontalFrameKey,
            wallpaperVerticalFrameKey,
            wallpaperProfilesKey,
            activeWallpaperProfileIDKey,
            customWatchlistsKey,
            dismissedReviewItemIDsKey,
        ].forEach { prefs.removeObject(forKey: $0) }
        prefs.synchronize()
    }

    private func clearAllWallpaperProfiles() {
        for profile in wallpaperProfiles {
            if let url = wallpaperProfileFileURL(fileName: profile.imageFileName) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        wallpaperProfiles = []
        wallpaperProfileImages = [:]
        activeWallpaperProfileID = nil
        prefs.removeObject(forKey: wallpaperProfilesKey)
        prefs.removeObject(forKey: activeWallpaperProfileIDKey)
        if let folder = wallpaperProfilesFolderURL(createIfNeeded: false) {
            try? FileManager.default.removeItem(at: folder)
        }
        prefs.synchronize()
    }

    private func clearScheduledAppNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func importWallpaperTheme(
        from imageData: Data,
        zoomPercent: Double = 0,
        horizontalFrame: Double = 50,
        verticalFrame: Double = 50
    ) async throws {
        let prepared = try await Task.detached(priority: .userInitiated) {
            try WallpaperPaletteExtractor.prepareWallpaper(from: imageData)
        }.value

        let profileID = UUID().uuidString
        let profile = WallpaperThemeProfile(
            id: profileID,
            name: nextWallpaperProfileName(),
            imageFileName: "\(profileID).jpg",
            palette: prepared.palette,
            themeColorHex: nil,
            cardColorHex: defaultWallpaperCardColorHex(for: prepared.palette),
            visibility: 100,
            blurRadius: 0,
            panelOpacity: 85,
            zoomPercent: clampedPercent(zoomPercent),
            horizontalFrame: clampedPercent(horizontalFrame),
            verticalFrame: clampedPercent(verticalFrame),
            createdAt: Date()
        )

        if let url = wallpaperProfileFileURL(fileName: profile.imageFileName) {
            try? prepared.imageData.write(to: url, options: [.atomic])
        }

        wallpaperProfiles.insert(profile, at: 0)
        wallpaperProfileImages[profile.id] = UIImage(data: prepared.imageData)
        saveWallpaperProfiles()
        applyWallpaperProfile(profile, imageData: prepared.imageData)
        savePreferencesToDisk()
    }

    func selectWallpaperProfile(_ profile: WallpaperThemeProfile) {
        guard let imageData = wallpaperProfileImageData(for: profile) else { return }
        applyWallpaperProfile(profile, imageData: imageData)
    }

    func saveCurrentWallpaperProfile(named name: String? = nil) {
        guard let activeWallpaperProfileID,
              let index = wallpaperProfiles.firstIndex(where: { $0.id == activeWallpaperProfileID }) else {
            saveWallpaperAppearance()
            return
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            wallpaperProfiles[index].name = trimmedName
        }
        wallpaperProfiles[index].visibility = clampedPercent(wallpaperVisibility)
        wallpaperProfiles[index].blurRadius = clampedPercent(wallpaperBlurRadius)
        wallpaperProfiles[index].panelOpacity = clampedPercent(wallpaperPanelOpacity)
        wallpaperProfiles[index].zoomPercent = clampedPercent(wallpaperZoomPercent)
        wallpaperProfiles[index].horizontalFrame = clampedPercent(wallpaperHorizontalFrame)
        wallpaperProfiles[index].verticalFrame = clampedPercent(wallpaperVerticalFrame)
        wallpaperProfiles[index].themeColorHex = isUsingWallpaperThemeColor ? nil : hexString(from: customThemeColor)
        wallpaperProfiles[index].cardColorHex = isUsingWallpaperCardColor ? hexString(from: wallpaperCardColor) : nil
        saveWallpaperAppearance()
        saveWallpaperProfiles()
    }

    func updateCurrentWallpaperCrop(
        zoomPercent: Double,
        horizontalFrame: Double,
        verticalFrame: Double
    ) {
        wallpaperZoomPercent = clampedPercent(zoomPercent)
        wallpaperHorizontalFrame = clampedPercent(horizontalFrame)
        wallpaperVerticalFrame = clampedPercent(verticalFrame)
        saveWallpaperAppearance()
    }

    func deleteWallpaperProfile(_ profile: WallpaperThemeProfile) {
        if let url = wallpaperProfileFileURL(fileName: profile.imageFileName) {
            try? FileManager.default.removeItem(at: url)
        }
        wallpaperProfiles.removeAll { $0.id == profile.id }
        wallpaperProfileImages.removeValue(forKey: profile.id)
        saveWallpaperProfiles()

        guard profile.id == activeWallpaperProfileID else { return }
        if let nextProfile = wallpaperProfiles.first,
           let imageData = wallpaperProfileImageData(for: nextProfile) {
            applyWallpaperProfile(nextProfile, imageData: imageData)
        } else {
            clearWallpaperTheme()
        }
    }

    private func applyWallpaperProfile(_ profile: WallpaperThemeProfile, imageData: Data) {
        wallpaperImageData = imageData
        wallpaperUIImage = UIImage(data: imageData)
        wallpaperPalette = profile.palette
        if let themeColorHex = profile.themeColorHex {
            customThemeColor = Color(hex: themeColorHex)
            isUsingCustomThemeColor = true
            isUsingWallpaperThemeColor = false
        } else {
            isUsingWallpaperThemeColor = true
            isUsingCustomThemeColor = false
        }
        wallpaperCardColor = Color(hex: profile.cardColorHex ?? defaultWallpaperCardColorHex(for: profile.palette))
        isUsingWallpaperCardColor = true
        activeWallpaperProfileID = profile.id
        wallpaperVisibility = clampedPercent(profile.visibility)
        wallpaperBlurRadius = clampedPercent(profile.blurRadius)
        wallpaperPanelOpacity = clampedPercent(profile.panelOpacity)
        wallpaperZoomPercent = clampedPercent(profile.zoomPercent)
        wallpaperHorizontalFrame = clampedPercent(profile.horizontalFrame)
        wallpaperVerticalFrame = clampedPercent(profile.verticalFrame)
        saveWallpaperPalette()
        persistWallpaperAppearance(updateActiveProfile: false)
        prefs.set(profile.id, forKey: activeWallpaperProfileIDKey)
        savePreferencesToDisk()
        prefs.synchronize()
    }

    private func nextWallpaperProfileName() -> String {
        "\(loc("Wallpaper")) \(wallpaperProfiles.count + 1)"
    }

    func clearWallpaperTheme() {
        wallpaperImageData = nil
        wallpaperUIImage = nil
        wallpaperPalette = nil
        activeWallpaperProfileID = nil
        isUsingWallpaperThemeColor = false
        isUsingWallpaperCardColor = false
        resetWallpaperAppearance()
        prefs.removeObject(forKey: wallpaperPaletteKey)
        prefs.removeObject(forKey: activeWallpaperProfileIDKey)
        prefs.removeObject(forKey: wallpaperCardColorHexKey)
        prefs.removeObject(forKey: wallpaperCardColorEnabledKey)
        savePreferencesToDisk()
        if let url = wallpaperFileURL() {
            try? FileManager.default.removeItem(at: url)
        }
        prefs.synchronize()
    }

    private func loadWallpaperTheme() {
        if let activeID = prefs.string(forKey: activeWallpaperProfileIDKey),
           let profile = wallpaperProfiles.first(where: { $0.id == activeID }),
           let imageData = wallpaperProfileImageData(for: profile) {
            applyWallpaperProfile(profile, imageData: imageData)
            return
        }

        if let paletteData = prefs.data(forKey: wallpaperPaletteKey),
           let palette = try? JSONDecoder().decode(WallpaperPalette.self, from: paletteData) {
            wallpaperPalette = palette
        }

        if let url = wallpaperFileURL(),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            wallpaperImageData = data
            wallpaperUIImage = image

            if wallpaperProfiles.isEmpty, let palette = wallpaperPalette {
                migrateLegacyWallpaperToProfile(imageData: data, palette: palette)
            }
        }
    }

    func saveWallpaperAppearance() {
        persistWallpaperAppearance(updateActiveProfile: true)
    }

    private func persistWallpaperAppearance(updateActiveProfile: Bool) {
        prefs.set(wallpaperVisibility, forKey: wallpaperVisibilityKey)
        prefs.set(wallpaperBlurRadius, forKey: wallpaperBlurRadiusKey)
        prefs.set(wallpaperPanelOpacity, forKey: wallpaperPanelOpacityKey)
        prefs.set(wallpaperZoomPercent, forKey: wallpaperZoomPercentKey)
        prefs.set(wallpaperHorizontalFrame, forKey: wallpaperHorizontalFrameKey)
        prefs.set(wallpaperVerticalFrame, forKey: wallpaperVerticalFrameKey)
        if updateActiveProfile {
            updateActiveWallpaperProfileSettings()
        }
        prefs.synchronize()
    }

    private func loadWallpaperAppearance() {
        if prefs.object(forKey: wallpaperVisibilityKey) != nil {
            wallpaperVisibility = normalizedStoredPercent(prefs.double(forKey: wallpaperVisibilityKey))
        }
        if prefs.object(forKey: wallpaperBlurRadiusKey) != nil {
            wallpaperBlurRadius = clampedPercent(prefs.double(forKey: wallpaperBlurRadiusKey))
        }
        if prefs.object(forKey: wallpaperPanelOpacityKey) != nil {
            wallpaperPanelOpacity = normalizedStoredPercent(prefs.double(forKey: wallpaperPanelOpacityKey))
        }
        if prefs.object(forKey: wallpaperZoomPercentKey) != nil {
            wallpaperZoomPercent = clampedPercent(prefs.double(forKey: wallpaperZoomPercentKey))
        }
        if prefs.object(forKey: wallpaperHorizontalFrameKey) != nil {
            wallpaperHorizontalFrame = clampedPercent(prefs.double(forKey: wallpaperHorizontalFrameKey))
        }
        if prefs.object(forKey: wallpaperVerticalFrameKey) != nil {
            wallpaperVerticalFrame = clampedPercent(prefs.double(forKey: wallpaperVerticalFrameKey))
        }
    }

    private func resetWallpaperAppearance() {
        wallpaperVisibility = 100
        wallpaperBlurRadius = 0
        wallpaperPanelOpacity = 85
        wallpaperZoomPercent = 0
        wallpaperHorizontalFrame = 50
        wallpaperVerticalFrame = 50
        prefs.removeObject(forKey: wallpaperVisibilityKey)
        prefs.removeObject(forKey: wallpaperBlurRadiusKey)
        prefs.removeObject(forKey: wallpaperPanelOpacityKey)
        prefs.removeObject(forKey: wallpaperZoomPercentKey)
        prefs.removeObject(forKey: wallpaperHorizontalFrameKey)
        prefs.removeObject(forKey: wallpaperVerticalFrameKey)
    }

    private func normalizedStoredPercent(_ value: Double) -> Double {
        let percentValue = value <= 1 ? value * 100 : value
        return clampedPercent(percentValue)
    }

    private func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        guard let converted = uiColor.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ),
              let components = converted.components else {
            return "0d9488"
        }

        let red = components.indices.contains(0) ? components[0] : 0
        let green = components.indices.contains(1) ? components[1] : red
        let blue = components.indices.contains(2) ? components[2] : red
        return String(
            format: "%02x%02x%02x",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private func wallpaperThemeHexOptions(for palette: WallpaperPalette) -> [String] {
        if let prominentHexes = palette.prominentHexes {
            return fiveUniqueHexes(prominentHexes, fallback: palette.primaryHex)
        }

        let bridge = blendedHex(palette.primaryHex, palette.accentHex, amount: 0.5)
        return fiveUniqueHexes([
            palette.primaryHex,
            blendedHex(palette.primaryHex, bridge, amount: 0.35),
            bridge,
            blendedHex(bridge, palette.accentHex, amount: 0.35),
            palette.accentHex
        ], fallback: palette.primaryHex)
    }

    private func wallpaperCardHexOptions(for palette: WallpaperPalette) -> [String] {
        if let subtleHexes = palette.subtleHexes {
            return fiveUniqueHexes(subtleHexes, fallback: palette.backgroundHex)
        }

        let themeHexes = wallpaperThemeHexOptions(for: palette)
        let cardHexes = themeHexes.map { blendedHex(palette.backgroundHex, $0, amount: 0.38) }
        return fiveUniqueHexes(cardHexes, fallback: palette.backgroundHex)
    }

    private func defaultWallpaperCardColorHex(for palette: WallpaperPalette) -> String {
        wallpaperCardHexOptions(for: palette).first ?? palette.backgroundHex
    }

    private func fiveUniqueHexes(_ hexes: [String], fallback: String) -> [String] {
        var result: [String] = []
        for hex in hexes.map(normalizedHex) where !result.contains(hex) {
            result.append(hex)
        }

        let fallbackHex = normalizedHex(fallback)
        while result.count < 5 {
            result.append(fallbackHex)
        }
        return Array(result.prefix(5))
    }

    private func normalizedHex(_ hex: String) -> String {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        guard clean.count >= 6 else { return "0d9488" }
        return String(clean.suffix(6))
    }

    private func blendedHex(_ firstHex: String, _ secondHex: String, amount: CGFloat) -> String {
        let first = rgbComponents(from: firstHex)
        let second = rgbComponents(from: secondHex)
        let clamped = min(max(amount, 0), 1)
        let red = first.red * (1 - clamped) + second.red * clamped
        let green = first.green * (1 - clamped) + second.green * clamped
        let blue = first.blue * (1 - clamped) + second.blue * clamped
        return String(
            format: "%02x%02x%02x",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private func rgbComponents(from hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let clean = normalizedHex(hex)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        return (
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255
        )
    }

    private func loadGoalQuickAddAmounts() {
        guard let storedValues = prefs.array(forKey: goalQuickAddAmountsKey) else {
            goalQuickAddAmounts = defaultGoalQuickAddAmounts
            return
        }
        let values = storedValues.compactMap { value -> Double? in
            if let double = value as? Double { return double }
            if let number = value as? NSNumber { return number.doubleValue }
            return nil
        }
        goalQuickAddAmounts = normalizedGoalQuickAddAmounts(values)
    }

    private func saveGoalQuickAddAmounts() {
        goalQuickAddAmounts = normalizedGoalQuickAddAmounts(goalQuickAddAmounts)
        prefs.set(goalQuickAddAmounts, forKey: goalQuickAddAmountsKey)
    }

    private func normalizedGoalQuickAddAmounts(_ values: [Double]) -> [Double] {
        defaultGoalQuickAddAmounts.indices.map { index in
            if values.indices.contains(index), values[index] > 0 {
                return values[index]
            }
            return defaultGoalQuickAddAmounts[index]
        }
    }

    private func loadWallpaperProfiles() {
        guard let data = prefs.data(forKey: wallpaperProfilesKey),
              let profiles = try? JSONDecoder().decode([WallpaperThemeProfile].self, from: data) else {
            wallpaperProfiles = []
            wallpaperProfileImages = [:]
            return
        }

        wallpaperProfiles = profiles.sorted { $0.createdAt > $1.createdAt }
        var images: [String: UIImage] = [:]
        for profile in wallpaperProfiles {
            if let data = wallpaperProfileImageData(for: profile),
               let image = UIImage(data: data) {
                images[profile.id] = image
            }
        }
        wallpaperProfileImages = images
    }

    private func saveWallpaperProfiles() {
        if let data = try? JSONEncoder().encode(wallpaperProfiles) {
            prefs.set(data, forKey: wallpaperProfilesKey)
        }
        prefs.synchronize()
    }

    private func updateActiveWallpaperProfileSettings() {
        guard let activeWallpaperProfileID,
              let index = wallpaperProfiles.firstIndex(where: { $0.id == activeWallpaperProfileID }) else { return }

        wallpaperProfiles[index].visibility = clampedPercent(wallpaperVisibility)
        wallpaperProfiles[index].blurRadius = clampedPercent(wallpaperBlurRadius)
        wallpaperProfiles[index].panelOpacity = clampedPercent(wallpaperPanelOpacity)
        wallpaperProfiles[index].zoomPercent = clampedPercent(wallpaperZoomPercent)
        wallpaperProfiles[index].horizontalFrame = clampedPercent(wallpaperHorizontalFrame)
        wallpaperProfiles[index].verticalFrame = clampedPercent(wallpaperVerticalFrame)
        saveWallpaperProfiles()
    }

    private func updateActiveWallpaperProfileColorChoices() {
        guard let activeWallpaperProfileID,
              let index = wallpaperProfiles.firstIndex(where: { $0.id == activeWallpaperProfileID }) else { return }

        wallpaperProfiles[index].themeColorHex = isUsingWallpaperThemeColor ? nil : hexString(from: customThemeColor)
        wallpaperProfiles[index].cardColorHex = isUsingWallpaperCardColor ? hexString(from: wallpaperCardColor) : nil
        saveWallpaperProfiles()
    }

    private func migrateLegacyWallpaperToProfile(imageData: Data, palette: WallpaperPalette) {
        let profileID = UUID().uuidString
        let profile = WallpaperThemeProfile(
            id: profileID,
            name: nextWallpaperProfileName(),
            imageFileName: "\(profileID).jpg",
            palette: palette,
            themeColorHex: nil,
            cardColorHex: defaultWallpaperCardColorHex(for: palette),
            visibility: clampedPercent(wallpaperVisibility),
            blurRadius: clampedPercent(wallpaperBlurRadius),
            panelOpacity: clampedPercent(wallpaperPanelOpacity),
            zoomPercent: clampedPercent(wallpaperZoomPercent),
            horizontalFrame: clampedPercent(wallpaperHorizontalFrame),
            verticalFrame: clampedPercent(wallpaperVerticalFrame),
            createdAt: Date()
        )

        if let url = wallpaperProfileFileURL(fileName: profile.imageFileName) {
            try? imageData.write(to: url, options: [.atomic])
        }

        wallpaperProfiles = [profile]
        wallpaperProfileImages[profile.id] = UIImage(data: imageData)
        activeWallpaperProfileID = profile.id
        prefs.set(profile.id, forKey: activeWallpaperProfileIDKey)
        saveWallpaperProfiles()
    }

    private func wallpaperProfileImageData(for profile: WallpaperThemeProfile) -> Data? {
        guard let url = wallpaperProfileFileURL(fileName: profile.imageFileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func saveWallpaperTheme() {
        saveWallpaperPalette()

        guard let wallpaperImageData,
              let url = wallpaperFileURL() else { return }
        try? wallpaperImageData.write(to: url, options: [.atomic])
    }

    private func saveWallpaperPalette() {
        if let palette = wallpaperPalette,
           let paletteData = try? JSONEncoder().encode(palette) {
            prefs.set(paletteData, forKey: wallpaperPaletteKey)
        }
    }

    private func wallpaperProfileFileURL(fileName: String) -> URL? {
        guard let folder = wallpaperProfilesFolderURL(createIfNeeded: true) else { return nil }
        return folder.appendingPathComponent(fileName)
    }

    private func wallpaperProfilesFolderURL(createIfNeeded: Bool) -> URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let folder = baseURL
            .appendingPathComponent("PennyLet", isDirectory: true)
            .appendingPathComponent(wallpaperProfilesFolderName, isDirectory: true)
        if createIfNeeded {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func wallpaperFileURL() -> URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let folder = baseURL.appendingPathComponent("PennyLet", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(wallpaperFileName)
    }

    func requestNotificationPermission() {
        Task {
            let _: Bool = await NotificationService().registerForPushNotifications()
        }
    }

    func updateBudgetLocally(_ data: BudgetData) {
        guard var budget = budgets.first else { return }
        budget.monthlyIncome = data.monthlyIncome
        budget.monthlyEssentials = data.monthlyEssentials
        budget.monthlySavingsGoal = data.monthlySavingsGoal
        if let p = data.payDay { budget.payDay = p }
        if let startDate = data.startDate { budget.startDate = startDate }
        if let balance = data.currentSpendableBalance { budget.currentSpendableBalance = balance }
        if let cash = data.cashOnHand { budget.cashOnHand = cash }
        if let untouched = data.moneyToKeepUntouched { budget.moneyToKeepUntouched = untouched }
        if let bills = data.billsDueBeforeNextIncome { budget.billsDueBeforeNextIncome = bills }
        if let savings = data.savingsDueBeforeNextIncome { budget.savingsDueBeforeNextIncome = savings }
        if let nextDate = data.nextIncomeDate { budget.nextIncomeDate = nextDate }
        if let nextAmount = data.nextIncomeAmount { budget.nextIncomeAmount = nextAmount }
        if let cadence = data.incomeCadence { budget.incomeCadence = cadence }
        if let c = data.currency { budget.currency = c; currency = c }
        if let l = data.language { budget.language = l; language = l }
        if let t = data.theme { budget.theme = t; if let th = AppTheme(rawValue: t) { theme = th } }
        if let cm = data.colorMode { budget.colorMode = cm; if let c = AppColorMode(rawValue: cm) { colorMode = c } }
        if let f = data.font { budget.font = f; if let fn = AppFont(rawValue: f) { font = fn } }
        if let s = data.startOfWeek { budget.startOfWeek = s }
        if let a = data.autoAnalysisEnabled { budget.autoAnalysisEnabled = a }
        if let d = data.dailyAnalysisTime { budget.dailyAnalysisTime = d }
        if let w = data.weeklyAnalysisTime { budget.weeklyAnalysisTime = w }
        if let m = data.monthlyAnalysisTime { budget.monthlyAnalysisTime = m }
        if let be = data.budgetAlertsEnabled { budget.budgetAlertsEnabled = be }
        if let bee = data.budgetAlertsEmailEnabled { budget.budgetAlertsEmailEnabled = bee }
        if let bp = data.budgetAlertsPushEnabled { budget.budgetAlertsPushEnabled = bp }
        if let ae = data.alertEmail { budget.alertEmail = ae }
        if let cc = data.customCategories { budget.customCategories = cc }
        budget.updatedDate = ISO8601DateFormatter().string(from: Date())
        budgets[0] = budget
        saveLocalData()
    }

    func updateTodaySnapshot(
        currentSpendableBalance: Double,
        cashOnHand: Double,
        moneyToKeepUntouched: Double,
        billsDueBeforeNextIncome: Double,
        savingsDueBeforeNextIncome: Double,
        nextIncomeDate: Date,
        nextIncomeAmount: Double?
    ) {
        guard let budget = currentBudget else { return }
        updateBudgetLocally(BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: Calendar.current.component(.day, from: nextIncomeDate),
            startDate: budget.startDate,
            currentSpendableBalance: max(0, currentSpendableBalance),
            cashOnHand: max(0, cashOnHand),
            moneyToKeepUntouched: max(0, moneyToKeepUntouched),
            billsDueBeforeNextIncome: max(0, billsDueBeforeNextIncome),
            savingsDueBeforeNextIncome: max(0, savingsDueBeforeNextIncome),
            nextIncomeDate: Self.storedDateString(from: nextIncomeDate),
            nextIncomeAmount: max(0, nextIncomeAmount ?? budget.monthlyIncome),
            incomeCadence: budget.incomeCadence,
            currency: budget.currency,
            language: budget.language,
            theme: budget.theme,
            colorMode: budget.colorMode,
            font: budget.font,
            startOfWeek: budget.startOfWeek,
            autoAnalysisEnabled: budget.autoAnalysisEnabled,
            dailyAnalysisTime: budget.dailyAnalysisTime,
            weeklyAnalysisTime: budget.weeklyAnalysisTime,
            monthlyAnalysisTime: budget.monthlyAnalysisTime,
            budgetAlertsEnabled: budget.budgetAlertsEnabled,
            budgetAlertsEmailEnabled: budget.budgetAlertsEmailEnabled,
            budgetAlertsPushEnabled: budget.budgetAlertsPushEnabled,
            alertEmail: budget.alertEmail,
            customCategories: budget.customCategories
        ))
    }

    func addCustomCategory(_ name: String) {
        guard let budget = currentBudget else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let customID = AppCategory.customCategoryID(for: trimmed)
        let builtInCategories = AppCategory.expenseCategories + AppCategory.incomeCategories
        guard !builtInCategories.contains(where: {
            $0.id == customID || $0.label.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) else { return }
        var customs = budget.customCategories ?? []
        guard !customs.contains(where: {
            $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame ||
                AppCategory.customCategoryID(for: $0) == customID
        }) else { return }
        customs.append(trimmed)
        let data = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            customCategories: customs
        )
        updateBudgetLocally(data)
    }

    private func aiPersonalContext() -> String {
        let summary = dashboardSpendSummary
        let budget = currentBudget
        let monthlyIncome = budget?.monthlyIncome ?? 0
        let essentials = budget?.monthlyEssentials ?? 0
        let savingsGoal = budget?.monthlySavingsGoal ?? 0
        let disposable = monthlyIncome - essentials - savingsGoal
        let startSummary = startFromTodaySummary

        let cal = Calendar.current
        let today = Date()
        let monthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: today, toGranularity: .month)
        }
        let monthExpenses = aiExpenseTransactions(monthTxns)
        let monthIncome = aiIncomeAmount(in: monthTxns)
        let monthSpent = aiSpendAmount(in: monthTxns)
        let budgetPercent = disposable > 0 ? Int((monthSpent / disposable * 100).rounded()) : 0
        let projectedSpend = projectedMonthSpend(currentSpent: monthSpent, summary: summary)

        let dateRange: String = {
            let dates = transactions.compactMap(\.dateValue).sorted()
            guard let first = dates.first, let last = dates.last else { return "No transaction history yet" }
            return "\(shortDate(first)) to \(shortDate(last))"
        }()

        return [
            "PENNYLET DATA SNAPSHOT",
            "- Analysis date: \(shortDate(today))",
            "- Currency: \(currency)",
            "- Data coverage: \(dataCoverageLine(transactions))",
            "- Transaction history range: \(dateRange)",
            "",
            "Budget and pace:",
            "- Monthly income target: \(CurrencyFormat.format(monthlyIncome, currency: currency))",
            "- Essentials: \(CurrencyFormat.format(essentials, currency: currency))",
            "- Savings goal: \(CurrencyFormat.format(savingsGoal, currency: currency))",
            "- Disposable budget: \(CurrencyFormat.format(disposable, currency: currency))",
            "- Pay day: \(budget?.payDay.map(String.init) ?? "not set")",
            "- Start-from-today mode: \(startSummary == nil ? "off" : "on")",
            "- Money available today: \(CurrencyFormat.format(startSummary?.currentMoney ?? 0, currency: currency))",
            "- Safe until payday: \(CurrencyFormat.format(startSummary?.trueSafeToSpend ?? 0, currency: currency))",
            "- Daily until payday: \(CurrencyFormat.format(startSummary?.dailySafeToSpend ?? 0, currency: currency))",
            "- Next income amount: \(CurrencyFormat.format(startSummary?.nextIncomeAmount ?? 0, currency: currency))",
            "- Current month spent: \(CurrencyFormat.format(monthSpent, currency: currency)) (\(budgetPercent)% of disposable budget)",
            "- Current month income recorded: \(CurrencyFormat.format(monthIncome, currency: currency))",
            "- Projected month-end spend at current pace: \(CurrencyFormat.format(projectedSpend, currency: currency))",
            "- Expected spend by today: \(CurrencyFormat.format(summary.expectedSpent, currency: currency))",
            "- Pace difference: \(CurrencyFormat.format(summary.paceDiff, currency: currency))",
            "- Safe daily spend: \(CurrencyFormat.format(summary.safeDaily, currency: currency))",
            "- Days left this month: \(summary.daysLeft)",
            "",
            "Current month evidence:",
            "- Current month top categories: \(topCategoryLines(from: monthExpenses, limit: 4))",
            "- Current month top merchants: \(topMerchantLines(from: monthExpenses, limit: 4))",
            "- Largest current month expenses: \(transactionEvidenceLines(monthExpenses.sorted { $0.amount > $1.amount }, limit: 3))",
            "- Recent transactions: \(transactionEvidenceLines(aiEvidenceTransactions(transactions).sorted { ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast) }, limit: 6))",
            "- Goals: \(goalContextLines())"
        ].joined(separator: "\n")
    }

    private func aiOutputRules(for analysisName: String) -> String {
        """
        Accuracy and writing rules for \(analysisName):
        - Write in \(promptLanguage).
        - Treat the provided PennyLet data as the only source of truth.
        - Do not invent missing transactions, income, merchants, dates, goals, or category changes.
        - Cite exact amounts, categories, merchants, dates, percentages, or time windows when making claims.
        - If history is short or the user started mid-month, say the answer is based on saved PennyLet data instead of implying a complete bank history.
        - Never suggest connecting a bank, uploading credentials, or using financial data that is not already saved in PennyLet.
        - Keep the output short, specific, and useful in under 15 seconds.
        - The action must be measurable: include a target amount, category, merchant, or time window.
        - Use a calm, non-judgmental tone.
        """
    }

    private func topCategoryLines(from txns: [Transaction], limit: Int) -> String {
        let grouped = Dictionary(grouping: aiExpenseTransactions(txns), by: { normalizedCategoryID(for: $0) ?? "other" })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(limit)
        guard !grouped.isEmpty else { return "none" }
        return grouped.map { "\(categoryLabel($0.key, type: .expense)): \(CurrencyFormat.format($0.value, currency: currency))" }
            .joined(separator: "; ")
    }

    private func topMerchantLines(from txns: [Transaction], limit: Int) -> String {
        let named = aiExpenseTransactions(txns).compactMap { tx -> (String, Double)? in
            guard let merchant = tx.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !merchant.isEmpty else { return nil }
            return (merchant, tx.amount)
        }
        let grouped = Dictionary(grouping: named, by: { $0.0 })
            .mapValues { items in (amount: items.reduce(0) { $0 + $1.1 }, count: items.count) }
            .sorted { $0.value.amount > $1.value.amount }
            .prefix(limit)
        guard !grouped.isEmpty else { return "none" }
        return grouped.map { "\($0.key): \(CurrencyFormat.format($0.value.amount, currency: currency)) across \($0.value.count) transaction\($0.value.count == 1 ? "" : "s")" }
            .joined(separator: "; ")
    }

    private func transactionEvidenceLines(_ txns: [Transaction], limit: Int) -> String {
        let items = aiEvidenceTransactions(txns).prefix(limit).map { tx in
            let dateText = tx.dateValue.map(shortDate) ?? tx.date
            let sign = tx.type == .income ? "+" : "-"
            let merchant = tx.merchant?.isEmpty == false ? " at \(tx.merchant!)" : ""
            let note = tx.note?.isEmpty == false ? " (\(tx.note!))" : ""
            let original = originalCurrencyText(for: tx)
            let recurring = tx.isRecurring ? " recurring" : ""
            return "\(dateText): \(sign)\(CurrencyFormat.format(tx.amount, currency: currency))\(original) \(categoryLabel(tx.category, type: tx.type))\(merchant)\(recurring)\(note)"
        }
        return items.isEmpty ? "none" : items.joined(separator: "; ")
    }

    private func goalContextLines() -> String {
        let lines = goals.prefix(4).map { goal in
            let progress = Int((goal.progress * 100).rounded())
            let remaining = CurrencyFormat.format(goal.remainingAmount, currency: currency)
            return "\(goal.name): \(progress)% funded, \(remaining) remaining"
        }
        return lines.isEmpty ? "none" : lines.joined(separator: "; ")
    }

    private func categoryComparisonLines(current: [Transaction], previous: [Transaction], limit: Int) -> String {
        let currentTotals = categoryTotals(current)
        let previousTotals = categoryTotals(previous)
        let categoryIDs = Set(currentTotals.keys).union(previousTotals.keys)
        let changes = categoryIDs.map { id -> (id: String, current: Double, previous: Double, delta: Double) in
            let current = currentTotals[id] ?? 0
            let previous = previousTotals[id] ?? 0
            return (id, current, previous, current - previous)
        }
        .sorted { abs($0.delta) > abs($1.delta) }
        .prefix(limit)

        guard !changes.isEmpty else { return "none" }
        return changes.map { item in
            "\(categoryLabel(item.id, type: .expense)): \(CurrencyFormat.format(item.current, currency: currency)) now vs \(CurrencyFormat.format(item.previous, currency: currency)) before (\(changeText(current: item.current, previous: item.previous)))"
        }.joined(separator: "; ")
    }

    private func categoryTotals(_ txns: [Transaction]) -> [String: Double] {
        Dictionary(grouping: aiExpenseTransactions(txns), by: { normalizedCategoryID(for: $0) ?? "other" })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    private func changeText(current: Double, previous: Double) -> String {
        let delta = current - previous
        let direction = delta >= 0 ? "+" : "-"
        let amount = "\(direction)\(CurrencyFormat.format(abs(delta), currency: currency))"
        guard previous > 0 else {
            return current > 0 ? "\(amount), new activity" : "\(amount), no activity"
        }
        let pct = Int((delta / previous * 100).rounded())
        return "\(amount), \(pct >= 0 ? "+" : "")\(pct)%"
    }

    private func dataCoverageLine(_ txns: [Transaction]) -> String {
        let dated = txns.compactMap(\.dateValue).sorted()
        guard let first = dated.first, let last = dated.last else {
            return "0 transactions"
        }
        let expenseCount = txns.filter { $0.type == .expense }.count
        let incomeCount = txns.filter { $0.type == .income && !isRefundOrReimbursement($0) }.count
        let excludedCount = txns.filter(isTransferOrExcluded).count
        return "\(txns.count) transactions (\(expenseCount) expenses, \(incomeCount) income, \(excludedCount) transfers/excluded) from \(shortDate(first)) to \(shortDate(last))"
    }

    private func aiExpenseTransactions(_ txns: [Transaction]) -> [Transaction] {
        txns.filter { $0.type == .expense && !isTransferOrExcluded($0) }
    }

    private func aiEvidenceTransactions(_ txns: [Transaction]) -> [Transaction] {
        txns.filter { !isTransferOrExcluded($0) || isRefundOrReimbursement($0) }
    }

    private func aiSpendAmount(in txns: [Transaction]) -> Double {
        let expenses = aiExpenseTransactions(txns).reduce(0) { $0 + $1.amount }
        let refunds = txns.filter(isRefundOrReimbursement).reduce(0) { $0 + $1.amount }
        return max(expenses - refunds, 0)
    }

    private func aiIncomeAmount(in txns: [Transaction]) -> Double {
        txns
            .filter { $0.type == .income && !isTransferOrExcluded($0) && !isRefundOrReimbursement($0) }
            .reduce(0) { $0 + $1.amount }
    }

    private func isRefundOrReimbursement(_ tx: Transaction) -> Bool {
        let category = normalizedCategoryID(for: tx) ?? ""
        let tags = tx.tags ?? []
        return category == "refund" ||
            category == "reimbursement" ||
            tags.contains(where: { $0.contains("refund") || $0.contains("reimbursement") || $0.contains("reimburse") })
    }

    private func isTransferOrExcluded(_ tx: Transaction) -> Bool {
        let category = normalizedCategoryID(for: tx) ?? ""
        let tags = tx.tags ?? []
        if isRefundOrReimbursement(tx) {
            return false
        }
        return category == "transfer" ||
            category == "credit_card_payment" ||
            category == "balance_adjustment" ||
            category == "ignore" ||
            tags.contains(where: { tag in
                tag.contains("transfer") ||
                    tag.contains("credit_card_payment") ||
                    tag.contains("payment_out") ||
                    tag.contains("payment_in") ||
                    tag.contains("adjustment")
            })
    }

    private func normalizedCategoryID(for tx: Transaction) -> String? {
        AppCategory.normalizedCategoryID(for: tx.category, type: tx.type)
    }

    private func originalCurrencyText(for tx: Transaction) -> String {
        guard let originalCurrency = tx.originalCurrency,
              originalCurrency != currency,
              let originalAmount = tx.originalAmount else {
            return ""
        }
        return " [original \(CurrencyFormat.format(originalAmount, currency: originalCurrency))]"
    }

    private func projectedMonthSpend(currentSpent: Double, summary: SpendSummary) -> Double {
        guard summary.dayOfMonth > 0, summary.totalDays > 0 else { return currentSpent }
        return currentSpent / Double(summary.dayOfMonth) * Double(summary.totalDays)
    }

    private func jsonNumber(_ raw: String, key: String) -> Double? {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json[key] else {
            return nil
        }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private func categoryLabel(_ id: String?, type: Transaction.TransactionType) -> String {
        loc(AppCategory.category(for: id, type: type).label)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func generateForecast(progress: AIProgressHandler? = nil) async throws -> AIResult {
        progress?(.collectingData)
        let s = dashboardSpendSummary
        let cal = Calendar.current
        let thisMonth = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        }
        let thisMonthSpent = aiSpendAmount(in: thisMonth)
        let thisMonthIncome = aiIncomeAmount(in: thisMonth)

        // Previous months for comparison (up to 3 months back)
        var pastMonthsData: [(label: String, spent: Double)] = []
        for offset in 1...3 {
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: Date()) else { continue }
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: monthStart, toGranularity: .month)
            }
            let total = aiSpendAmount(in: monthTxns)
            let df = DateFormatter(); df.dateFormat = "MMM"
            pastMonthsData.append((df.string(from: monthStart), total))
        }

        let thisMonthExpenses = aiExpenseTransactions(thisMonth)
        let byCategory: [String: Double] = Dictionary(grouping: thisMonthExpenses, by: { normalizedCategoryID(for: $0) ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }
        let catLines = topCategoryLines(from: thisMonthExpenses, limit: 5)
        let projectedThisMonth = projectedMonthSpend(currentSpent: thisMonthSpent, summary: s)
        let nonZeroPastMonths = pastMonthsData.map { $0.spent }.filter { $0 > 0 }
        let pastAverage = nonZeroPastMonths.isEmpty ? thisMonthSpent : nonZeroPastMonths.reduce(0, +) / Double(nonZeroPastMonths.count)
        let localForecastBaseline = max(0, (projectedThisMonth * 0.6) + (pastAverage * 0.4))

        // Current month trend (weekly)
        let currentLabel = {
            let df = DateFormatter(); df.dateFormat = "MMM"
            return df.string(from: Date())
        }()
        let recentEvidence = transactionEvidenceLines(
            aiEvidenceTransactions(transactions).sorted { ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast) },
            limit: 6
        )

        let prompt = """
        You are a precise personal finance forecaster. Use ONLY the data below. NEVER invent numbers.

        \(aiPersonalContext())

        FORECAST INPUTS
        This month's spending by category:
        \(catLines == "none" ? "No spending data this month." : catLines)

        This month: Spent \(CurrencyFormat.format(thisMonthSpent, currency: currency)), Income \(CurrencyFormat.format(thisMonthIncome, currency: currency))
        Past months: \(pastMonthsData.map { "\($0.label): \(CurrencyFormat.format($0.spent, currency: currency))" }.joined(separator: ", "))
        Current pace projection for this month: \(CurrencyFormat.format(projectedThisMonth, currency: currency))
        Local weighted forecast baseline: \(CurrencyFormat.format(localForecastBaseline, currency: currency)) (60% current pace + 40% recent-month average)
        Daily safe spend: \(CurrencyFormat.format(s.safeDaily, currency: currency))
        Days remaining: \(s.daysLeft)
        Recent transaction evidence: \(recentEvidence)

        \(aiOutputRules(for: "forecast"))
        Return:
        - summary: 2 short sentences predicting the next month using the baseline and recent evidence.
        - forecast_amount: a numeric next-month spend estimate in \(currency). Keep it close to the baseline unless a specific category or merchant justifies a change.
        - top_forecasted_category: category most likely to drive next month, with amount/evidence.
        - saving_tip: one tailored action with a realistic target amount.
        - watch_item: one category or merchant to monitor next.
        - confidence_reason: High/Medium/Low plus the exact data reason.
        - data_gap: "none" or the most important missing data that limits accuracy.
        """

        let schema: [String: AnyCodable] = [
            "type": "object",
            "additionalProperties": .bool(false),
            "properties": .object([
                "summary": .object(["type": "string"]),
                "forecast_amount": .object(["type": "number"]),
                "top_forecasted_category": .object(["type": "string"]),
                "saving_tip": .object(["type": "string"]),
                "watch_item": .object(["type": "string"]),
                "confidence_reason": .object(["type": "string"]),
                "data_gap": .object(["type": "string"]),
            ]),
            "required": .array([.string("summary"), .string("forecast_amount"), .string("top_forecasted_category"), .string("saving_tip"), .string("watch_item"), .string("confidence_reason"), .string("data_gap")]),
        ]
        progress?(.requestPrepared)
        progress?(.waitingForAI)
        let raw: String
        do {
            raw = try await invokeLLMWithUserFacingDeadline(prompt: prompt, responseJSONSchema: schema)
        } catch {
            return await localAIFallback(type: "forecast", feature: "forecast", progress: progress, error: error)
        }
        progress?(.responseReceived)
        let formatted = formatForecastResult(raw)
        let forecastAmount = jsonNumber(raw, key: "forecast_amount") ?? localForecastBaseline

        // Compute chart data
        var trendData: [(String, Double)] = []
        for pm in pastMonthsData.reversed() { trendData.append((pm.label, pm.spent)) }
        trendData.append((currentLabel, thisMonthSpent))
        trendData.append((loc("Next Month"), forecastAmount))

        let catChart = byCategory.map { (name: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }.map { (name: $0.name, amount: $0.amount) }

        let now = ISO8601DateFormatter().string(from: Date())
        let historyData = AnalysisHistoryData(type: "forecast", content: formatted, analysisDate: now, categoryChartJSON: chartJSON(catChart), dailyChartJSON: chartJSON(trendData))
        progress?(.savingResult)
        await saveAnalysisHistoryEntry(historyData)

        await incrementUsage("forecast")
        let res = AIResult(text: formatted, categoryChart: catChart, dailyChart: trendData)
        currentForecastResult = res
        progress?(.finished)
        return res
    }

    private func formatForecastResult(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        var parts: [String] = []
        if let summary = json["summary"] as? String { parts.append(summary) }
        if let forecast = jsonNumber(raw, key: "forecast_amount") {
            parts.append("\(l.totalSpent) (est): \(CurrencyFormat.format(forecast, currency: currency))")
        }
        if let topCat = json["top_forecasted_category"] as? String {
            parts.append("\(l.topCategory): \(topCat)")
        }
        if let tip = json["saving_tip"] as? String { parts.append("\(l.suggestion): \(tip)") }
        if let watch = json["watch_item"] as? String { parts.append("\(l.watchItem): \(watch)") }
        if let confidence = json["confidence_reason"] as? String { parts.append("\(l.confidence): \(confidence)") }
        if let gap = usefulOptionalText(json["data_gap"] as? String) { parts.append("\(l.dataQuality): \(gap)") }
        return parts.isEmpty ? raw : parts.joined(separator: "\n\n")
    }

    // MARK: - AI

    struct AIResult {
        let text: String
        let categoryChart: [(name: String, amount: Double)]
        let dailyChart: [(day: String, amount: Double)]
    }

    enum AIProgressPhase: Sendable, Equatable {
        case collectingData
        case requestPrepared
        case waitingForAI
        case usingLocalSummary
        case responseReceived
        case savingResult
        case finished

        static let orderedPhases: [AIProgressPhase] = [
            .collectingData,
            .requestPrepared,
            .waitingForAI,
            .usingLocalSummary,
            .responseReceived,
            .savingResult,
            .finished
        ]

        var messageKey: String {
            switch self {
            case .collectingData: return "Reading local spending data"
            case .requestPrepared: return "Preparing AI request"
            case .waitingForAI: return "Waiting for AI response"
            case .usingLocalSummary: return "Building local analysis"
            case .responseReceived: return "AI response received"
            case .savingResult: return "Saving result locally"
            case .finished: return "Result ready"
            }
        }
    }

    typealias AIProgressHandler = @MainActor @Sendable (AIProgressPhase) -> Void

    private func invokeLLMWithUserFacingDeadline(
        prompt: String,
        responseJSONSchema: [String: AnyCodable]? = nil
    ) async throws -> String {
        let client = aiClient
        let tier = aiModelTier
        let timeout = aiUserFacingTimeoutNanoseconds

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await client.invokeLLM(prompt: prompt, responseJSONSchema: responseJSONSchema, modelTier: tier)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeout)
                throw ClientError.requestTimedOut
            }

            guard let result = try await group.next() else {
                throw ClientError.requestTimedOut
            }
            group.cancelAll()
            return result
        }
    }

    func generateDailyAnalysis(progress: AIProgressHandler? = nil) async throws -> AIResult {
        progress?(.collectingData)
        let summary = dashboardSpendSummary
        let todayTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return Calendar.current.isDateInToday(date)
        }
        let todaySpent = aiSpendAmount(in: todayTxns)
        let todayIncome = aiIncomeAmount(in: todayTxns)
        let txnLines = transactionEvidenceLines(
            aiEvidenceTransactions(todayTxns).sorted { ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast) },
            limit: 10
        )
        let recentTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
            return days >= 0 && days <= 14
        }.sorted { ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast) }
        let recentExpenses = aiExpenseTransactions(recentTxns)

        let prompt = """
        You are a precise personal finance assistant. Use ONLY the data below. NEVER invent numbers.

        \(aiPersonalContext())

        DAILY ANALYSIS WINDOW
        Date: \(shortDate(Date()))
        Today's transactions:
        \(txnLines == "none" ? "No transactions today." : txnLines)

        Recent 14-day transaction evidence:
        \(transactionEvidenceLines(recentTxns, limit: 6))

        Recent 14-day top categories:
        \(topCategoryLines(from: recentExpenses, limit: 3))

        Recent 14-day top merchants:
        \(topMerchantLines(from: recentExpenses, limit: 3))

        Totals:
        - Spent: \(CurrencyFormat.format(todaySpent, currency: currency))
        - Income: \(CurrencyFormat.format(todayIncome, currency: currency))
        - Daily safe spend: \(CurrencyFormat.format(summary.safeDaily, currency: currency))

        \(aiOutputRules(for: "daily analysis"))
        Return:
        - title: A short, useful headline tied to today's actual numbers.
        - summary: 1-2 sentences comparing today's spend to the safe daily limit. If today is empty, use the 14-day evidence and say today has no entries.
        - top_category: highest-spend category today with amount, or the most relevant 14-day category if today is empty.
        - evidence: 1 concise sentence naming the exact transaction/category/merchant/date behind the insight.
        - action: one specific action for the next 24 hours with a target amount/category/merchant.
        - confidence: High/Medium/Low plus the exact data reason.
        - data_gap: "none" or one missing detail that would improve accuracy.
        \(isPro ? "- unusual: Flag a genuinely unusual transaction compared to recent spending, with amount and reason, or say \\\"none\\\"." : "")
        """

        let props: [String: AnyCodable] = {
            var p: [String: AnyCodable] = [
                "title": .object(["type": "string"]),
                "summary": .object(["type": "string"]),
                "top_category": .object(["type": "string"]),
                "evidence": .object(["type": "string"]),
                "action": .object(["type": "string"]),
                "confidence": .object(["type": "string"]),
                "data_gap": .object(["type": "string"]),
            ]
            if isPro { p["unusual"] = .object(["type": "string"]) }
            return p
        }()

        let schema: [String: AnyCodable] = [
            "type": "object",
            "additionalProperties": .bool(false),
            "properties": .object(props),
            "required": .array([.string("title"), .string("summary"), .string("top_category"), .string("evidence"), .string("action"), .string("confidence"), .string("data_gap")]),
        ]

        progress?(.requestPrepared)
        progress?(.waitingForAI)
        let raw: String
        do {
            raw = try await invokeLLMWithUserFacingDeadline(prompt: prompt, responseJSONSchema: schema)
        } catch {
            return await localAIFallback(type: "daily", feature: "daily", progress: progress, error: error)
        }
        progress?(.responseReceived)
        let formatted = formatResult(raw, type: "daily")

        let today = ISO8601DateFormatter().string(from: Date())
        let historyData = AnalysisHistoryData(type: "daily", content: formatted, analysisDate: today, categoryChartJSON: nil, dailyChartJSON: nil)
        progress?(.savingResult)
        await saveAnalysisHistoryEntry(historyData)

        await incrementUsage("daily")
        let res = AIResult(text: formatted, categoryChart: [], dailyChart: [])
        currentDailyResult = res
        progress?(.finished)
        return res
    }

    func generateWeeklyAnalysis(progress: AIProgressHandler? = nil) async throws -> AIResult {
        progress?(.collectingData)
        let summary = dashboardSpendSummary
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let currentWindowStart = cal.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let previousWindowStart = cal.date(byAdding: .day, value: -7, to: currentWindowStart) ?? currentWindowStart
        let thisWeekTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return date >= currentWindowStart && date <= Date()
        }
        let lastWeekTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return date >= previousWindowStart && date < currentWindowStart
        }

        let thisWeekSpent = aiSpendAmount(in: thisWeekTxns)
        let lastWeekSpent = aiSpendAmount(in: lastWeekTxns)

        let thisWeekExpenses = aiExpenseTransactions(thisWeekTxns)
        let lastWeekExpenses = aiExpenseTransactions(lastWeekTxns)
        let catLines = topCategoryLines(from: thisWeekExpenses, limit: 5)
        let lastCatLines = topCategoryLines(from: lastWeekExpenses, limit: 5)
        let categoryChanges = categoryComparisonLines(current: thisWeekExpenses, previous: lastWeekExpenses, limit: 4)
        let thisWeekEvidence = transactionEvidenceLines(
            thisWeekExpenses.sorted { $0.amount > $1.amount },
            limit: 5
        )
        let lastWeekEvidence = transactionEvidenceLines(
            lastWeekExpenses.sorted { $0.amount > $1.amount },
            limit: 3
        )
        let currentWindowLabel = "\(shortDate(currentWindowStart)) to \(shortDate(Date()))"
        let previousWindowLabel = "\(shortDate(previousWindowStart)) to \(shortDate(cal.date(byAdding: .day, value: -1, to: currentWindowStart) ?? currentWindowStart))"

        let prompt = """
        You are a precise personal finance analyst. Use ONLY the data below. NEVER invent numbers.

        \(aiPersonalContext())

        WEEKLY ANALYSIS WINDOWS
        Current 7-day window: \(currentWindowLabel)
        Previous 7-day window: \(previousWindowLabel)
        Current 7-day spending by category: \(catLines)
        Previous 7-day spending by category: \(lastCatLines)
        Category changes: \(categoryChanges)
        Current 7-day total spent: \(CurrencyFormat.format(thisWeekSpent, currency: currency))
        Previous 7-day total spent: \(CurrencyFormat.format(lastWeekSpent, currency: currency))
        Daily safe spend: \(CurrencyFormat.format(summary.safeDaily, currency: currency))
        Days remaining this month: \(summary.daysLeft)
        Current 7-day largest transactions: \(thisWeekEvidence)
        Previous 7-day largest transactions: \(lastWeekEvidence)

        \(aiOutputRules(for: "weekly analysis"))
        Return:
        - summary: 2 concise sentences comparing the two exact 7-day windows with totals and the biggest driver.
        - top_category: highest-spend category in the current window with amount and reason.
        - vs_last_week: precise total comparison with percentage if previous spend is above zero.
        - biggest_driver: merchant, category, or transaction that best explains the change.
        - action: one specific action for the next 7 days with a target amount/category/merchant.
        - watch_item: one recurring category or merchant to monitor.
        - confidence: High/Medium/Low plus the exact data reason.
        - data_gap: "none" or one missing detail that would improve accuracy.
        \(isPro ? "- tip: One specific, actionable spending tip for next week." : "")
        """

        let props: [String: AnyCodable] = {
            var p: [String: AnyCodable] = [
                "summary": .object(["type": "string"]),
                "top_category": .object(["type": "string"]),
                "vs_last_week": .object(["type": "string"]),
                "biggest_driver": .object(["type": "string"]),
                "action": .object(["type": "string"]),
                "watch_item": .object(["type": "string"]),
                "confidence": .object(["type": "string"]),
                "data_gap": .object(["type": "string"]),
            ]
            if isPro {
                p["tip"] = .object(["type": "string"])
            }
            return p
        }()

        let schema: [String: AnyCodable] = [
            "type": "object",
            "additionalProperties": .bool(false),
            "properties": .object(props),
            "required": .array([.string("summary"), .string("top_category"), .string("vs_last_week"), .string("biggest_driver"), .string("action"), .string("watch_item"), .string("confidence"), .string("data_gap")]),
        ]

        progress?(.requestPrepared)
        progress?(.waitingForAI)
        let raw: String
        do {
            raw = try await invokeLLMWithUserFacingDeadline(prompt: prompt, responseJSONSchema: schema)
        } catch {
            return await localAIFallback(type: "weekly", feature: "recap", progress: progress, error: error)
        }
        progress?(.responseReceived)
        let formatted = formatResult(raw, type: "weekly")

        let now = ISO8601DateFormatter().string(from: Date())
        let trendData = computeWeeklyTrend()
        let historyData = AnalysisHistoryData(type: "weekly", content: formatted, analysisDate: now, categoryChartJSON: nil, dailyChartJSON: chartJSON(trendData))
        progress?(.savingResult)
        await saveAnalysisHistoryEntry(historyData)

        await incrementUsage("recap")
        let res = AIResult(text: formatted, categoryChart: [], dailyChart: trendData)
        currentWeeklyResult = res
        progress?(.finished)
        return res
    }

    func generateMonthlyAnalysis(progress: AIProgressHandler? = nil) async throws -> AIResult {
        progress?(.collectingData)
        let budget = currentBudget
        let s = dashboardSpendSummary
        let cal = Calendar.current
        let analysisDate = Date()
        let monthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: analysisDate, toGranularity: .month)
        }
        let lastMonth = cal.date(byAdding: .month, value: -1, to: analysisDate)!
        let lastMonthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
        }

        let monthSpent = aiSpendAmount(in: monthTxns)
        let monthIncome = aiIncomeAmount(in: monthTxns)
        let lastMonthSpent = aiSpendAmount(in: lastMonthTxns)

        let monthExpenses = aiExpenseTransactions(monthTxns)
        let lastMonthExpenses = aiExpenseTransactions(lastMonthTxns)
        let catLines = topCategoryLines(from: monthExpenses, limit: 5)
        let lastCatLines = topCategoryLines(from: lastMonthExpenses, limit: 5)
        let categoryChanges = categoryComparisonLines(current: monthExpenses, previous: lastMonthExpenses, limit: 5)

        let disposable = (budget?.monthlyIncome ?? 0) - (budget?.monthlyEssentials ?? 0) - (budget?.monthlySavingsGoal ?? 0)
        let budgetPct = disposable > 0 ? Int((monthSpent / disposable * 100).rounded()) : 0
        let projectedSpend = projectedMonthSpend(currentSpent: monthSpent, summary: s)
        let monthlyEvidence = transactionEvidenceLines(
            monthExpenses.sorted { $0.amount > $1.amount },
            limit: 6
        )
        let merchantEvidence = topMerchantLines(from: monthExpenses, limit: 4)
        let monthLabel = {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM"
            return df.string(from: analysisDate)
        }()
        let lastMonthLabel = {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM"
            return df.string(from: lastMonth)
        }()

        let prompt = """
        You are a precise personal finance analyst. Use ONLY the data below. NEVER invent numbers.

        \(aiPersonalContext())

        MONTHLY ANALYSIS WINDOWS
        Current month: \(monthLabel)
        Previous month: \(lastMonthLabel)
        This month's spending by category: \(catLines.isEmpty ? "none" : catLines)
        Last month's spending by category: \(lastCatLines.isEmpty ? "none" : lastCatLines)
        Category changes: \(categoryChanges)
        This month spent: \(CurrencyFormat.format(monthSpent, currency: currency))
        This month income: \(CurrencyFormat.format(monthIncome, currency: currency))
        Last month spent: \(CurrencyFormat.format(lastMonthSpent, currency: currency))
        Monthly budget (disposable): \(CurrencyFormat.format(disposable, currency: currency))
        Budget used: \(budgetPct)%
        Projected month-end spend at current pace: \(CurrencyFormat.format(projectedSpend, currency: currency))
        Days remaining: \(s.daysLeft)
        Top merchants this month: \(merchantEvidence)
        Largest transactions this month: \(monthlyEvidence)

        \(aiOutputRules(for: "monthly analysis"))
        Return:
        - headline: a short summary of budget adherence tied to the user's actual budget percentage.
        - summary: 2 concise sentences analyzing spending vs budget, category changes, and likely month-end outcome.
        - budget_adherence: A comparison like "\(budgetPct)% of budget used with \(s.daysLeft) days left".
        - biggest_change: Which category changed the most from last month and by how much.
        - next_step: one actionable recommendation for the remaining days with a realistic target amount.
        - drivers: the specific merchants, categories, or transactions driving the result.
        - watch_item: one category or merchant to monitor.
        - confidence: High/Medium/Low plus the exact data reason.
        - data_gap: "none" or one missing detail that would improve accuracy.
        """

        let schema: [String: AnyCodable] = [
            "type": "object",
            "additionalProperties": .bool(false),
            "properties": .object([
                "headline": .object(["type": "string"]),
                "summary": .object(["type": "string"]),
                "budget_adherence": .object(["type": "string"]),
                "biggest_change": .object(["type": "string"]),
                "next_step": .object(["type": "string"]),
                "drivers": .object(["type": "string"]),
                "watch_item": .object(["type": "string"]),
                "confidence": .object(["type": "string"]),
                "data_gap": .object(["type": "string"]),
            ]),
            "required": .array([.string("headline"), .string("summary"), .string("budget_adherence"), .string("biggest_change"), .string("next_step"), .string("drivers"), .string("watch_item"), .string("confidence"), .string("data_gap")]),
        ]

        progress?(.requestPrepared)
        progress?(.waitingForAI)
        let raw: String
        do {
            raw = try await invokeLLMWithUserFacingDeadline(prompt: prompt, responseJSONSchema: schema)
        } catch {
            return await localAIFallback(type: "monthly", feature: "insight", progress: progress, error: error)
        }
        progress?(.responseReceived)
        let formatted = formatResult(raw, type: "monthly")

        let now = ISO8601DateFormatter().string(from: Date())
        let catChart = computeCategoryBreakdown()
        let historyData = AnalysisHistoryData(type: "monthly", content: formatted, analysisDate: now, categoryChartJSON: chartJSON(catChart), dailyChartJSON: nil)
        progress?(.savingResult)
        await saveAnalysisHistoryEntry(historyData)

        await incrementUsage("insight")
        let res = AIResult(text: formatted, categoryChart: catChart, dailyChart: [])
        currentMonthlyResult = res
        progress?(.finished)
        return res
    }

    private func formatResult(_ raw: String, type: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        var parts: [String] = []
        switch type {
        case "daily":
            if let title = json["title"] as? String { parts.append(title) }
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let top = json["top_category"] as? String { parts.append("\(l.topCategory): \(top)") }
            if let evidence = (json["evidence"] as? String) ?? (json["why"] as? String) { parts.append("\(l.evidence): \(evidence)") }
            if let action = json["action"] as? String { parts.append("\(l.nextStep): \(action)") }
            if let confidence = json["confidence"] as? String { parts.append("\(l.confidence): \(confidence)") }
            if let gap = usefulOptionalText(json["data_gap"] as? String) { parts.append("\(l.dataQuality): \(gap)") }
            if let unusual = json["unusual"] as? String, unusual.lowercased() != "none" {
                parts.append(unusual)
            }
        case "weekly":
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let top = json["top_category"] as? String { parts.append("\(l.topCategory): \(top)") }
            if let vs = json["vs_last_week"] as? String { parts.append(vs) }
            if let driver = json["biggest_driver"] as? String { parts.append("\(l.evidence): \(driver)") }
            if let watch = json["watch_item"] as? String { parts.append("\(l.watchItem): \(watch)") }
            if let action = json["action"] as? String { parts.append("\(l.nextStep): \(action)") }
            if let confidence = json["confidence"] as? String { parts.append("\(l.confidence): \(confidence)") }
            if let gap = usefulOptionalText(json["data_gap"] as? String) { parts.append("\(l.dataQuality): \(gap)") }
            if let tip = json["tip"] as? String { parts.append("\(l.suggestion): \(tip)") }
        case "monthly":
            if let h = json["headline"] as? String { parts.append(h) }
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let adh = json["budget_adherence"] as? String { parts.append(adh) }
            if let chg = json["biggest_change"] as? String { parts.append(chg) }
            if let drivers = json["drivers"] as? String { parts.append("\(l.evidence): \(drivers)") }
            if let watch = json["watch_item"] as? String { parts.append("\(l.watchItem): \(watch)") }
            if let next = json["next_step"] as? String { parts.append("\(l.nextStep): \(next)") }
            if let confidence = json["confidence"] as? String { parts.append("\(l.confidence): \(confidence)") }
            if let gap = usefulOptionalText(json["data_gap"] as? String) { parts.append("\(l.dataQuality): \(gap)") }
        default:
            return raw
        }
        return parts.isEmpty ? raw : parts.joined(separator: "\n\n")
    }

    private func usefulOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.lowercased() != "none" else {
            return nil
        }
        return trimmed
    }

    private func localAIFallback(
        type: String,
        feature: String,
        progress: AIProgressHandler?,
        error: Error
    ) async -> AIResult {
        progress?(.usingLocalSummary)
        let result = localFallbackResult(type: type, error: error)
        let now = ISO8601DateFormatter().string(from: Date())
        progress?(.savingResult)
        await saveAnalysisHistoryEntry(AnalysisHistoryData(
            type: type,
            content: result.text,
            analysisDate: now,
            categoryChartJSON: chartJSON(result.categoryChart),
            dailyChartJSON: chartJSON(result.dailyChart)
        ))

        switch type {
        case "daily":
            currentDailyResult = result
        case "weekly":
            currentWeeklyResult = result
        case "monthly":
            currentMonthlyResult = result
        case "forecast":
            currentForecastResult = result
        default:
            break
        }

        progress?(.finished)
        return result
    }

    private func localFallbackResult(type: String, error: Error) -> AIResult {
        let summary = dashboardSpendSummary
        let dashboard = localMoneyLogicV2Dashboard
        let categoryChart = computeCategoryBreakdown()
        let weeklyTrend = computeWeeklyTrend()
        let topCategory = categoryChart.first
        let fallbackReason = fallbackReasonText(for: error)
        let safe = CurrencyFormat.format(dashboard.safeToSpend.trueSafeToSpend, currency: currency)
        let daily = CurrencyFormat.format(dashboard.safeToSpend.dailySafeToSpend, currency: currency)
        let spent = CurrencyFormat.format(summary.spent, currency: currency)
        let remaining = CurrencyFormat.format(summary.remaining, currency: currency)
        let reviewCount = reviewQueue.count
        let noneText: String
        let noCommitmentsText: String
        let localEvidenceText: String
        let fallbackIntro: String
        let safeLine: String
        let spentLine: String
        let reviewLine: String
        let nextStepLine: String
        let confidenceLevelText: String
        let estimatedText: String
        let title: String
        switch language {
        case "ja":
            noneText = "なし"
            noCommitmentsText = "今後の定期支払いはまだ見つかっていません。"
            localEvidenceText = "この結果は、この端末に保存された取引、予算、目標、振替、返金、定期項目だけをもとにしています。"
            fallbackIntro = "リモートAIを利用できなかったため、PennyLetが端末内の計算で代わりに作成しました。\(fallbackReason)"
            safeLine = "使ってよい金額: \(safe)。1日あたり: \(daily)。"
            spentLine = "今月の記録済み支出: \(spent)。計画上の残り: \(remaining)。"
            reviewLine = reviewCount == 0 ? "なし" : "\(reviewCount)件の確認が必要です。"
            nextStepLine = "未分類の項目を確認し、自由支出を1日あたり\(daily)前後に保ちましょう。"
            confidenceLevelText = "中"
            estimatedText = "予測"
            switch type {
            case "daily": title = "端末内の今日の分析"
            case "weekly": title = "端末内の週間分析"
            case "monthly": title = "端末内の月間分析"
            case "forecast": title = "端末内の予測"
            default: title = "端末内の支出分析"
            }
        case "zh":
            noneText = "无"
            noCommitmentsText = "暂未发现即将到来的定期支出。"
            localEvidenceText = "此结果只基于本机已保存的交易、预算、目标、转账、退款和定期项目。"
            fallbackIntro = "远程 AI 暂时不可用，所以 PennyLet 改用本机计算生成结果。\(fallbackReason)"
            safeLine = "可安心花费: \(safe)。每日可用: \(daily)。"
            spentLine = "本月已记录支出: \(spent)。计划剩余空间: \(remaining)。"
            reviewLine = reviewCount == 0 ? "无" : "还有 \(reviewCount) 项需要确认。"
            nextStepLine = "先确认未分类项目，再把自由支出控制在每天约 \(daily)。"
            confidenceLevelText = "中等"
            estimatedText = "估算"
            switch type {
            case "daily": title = "本机每日分析"
            case "weekly": title = "本机每周分析"
            case "monthly": title = "本机月度分析"
            case "forecast": title = "本机预测分析"
            default: title = "本机支出分析"
            }
        default:
            noneText = "none"
            noCommitmentsText = "No upcoming recurring commitments found yet."
            localEvidenceText = "This is based only on local transactions, budgets, goals, transfers, refunds, and recurring items already saved on this device."
            fallbackIntro = "Remote AI was unavailable, so PennyLet used a local calculation instead. \(fallbackReason)"
            safeLine = "Safe to spend: \(safe). Daily safe amount: \(daily)."
            spentLine = "This month recorded spending: \(spent). Remaining plan room: \(remaining)."
            reviewLine = reviewCount == 0 ? "none" : "\(reviewCount) item\(reviewCount == 1 ? "" : "s") still need review."
            nextStepLine = "Review any uncategorized items, then keep discretionary spending near \(daily) per day."
            confidenceLevelText = "Medium"
            estimatedText = "est"
            switch type {
            case "daily": title = "Local daily read"
            case "weekly": title = "Local weekly read"
            case "monthly": title = "Local monthly read"
            case "forecast": title = "Local forecast read"
            default: title = "Local spending read"
            }
        }

        let topLine = topCategory.map { "\($0.0): \(CurrencyFormat.format($0.1, currency: currency))" } ?? noneText
        let commitments = dashboard.upcomingCommitments.prefix(3)
            .map { "\($0.name) \(CurrencyFormat.format($0.amount, currency: currency))" }
            .joined(separator: "; ")

        let forecastLine: String = {
            guard type == "forecast" else { return "" }
            let forecast = weeklyTrend.map { $0.1 }.filter { $0 > 0 }
            let average = forecast.isEmpty ? summary.spent : forecast.reduce(0, +) / Double(max(forecast.count, 1))
            return "\n\n\(l.totalSpent) (\(estimatedText)): \(CurrencyFormat.format(max(average * 4.3, summary.spent), currency: currency))"
        }()

        let text = [
            title,
            fallbackIntro,
            safeLine,
            spentLine,
            "\(l.topCategory): \(topLine).",
            "\(l.watchItem): \(commitments.isEmpty ? noCommitmentsText : commitments).",
            "\(l.confidence): \(confidenceLevelText). \(localEvidenceText)",
            "\(l.dataQuality): \(reviewLine)",
            "\(l.nextStep): \(nextStepLine)"
        ].joined(separator: "\n\n") + forecastLine

        return AIResult(text: text, categoryChart: categoryChart, dailyChart: weeklyTrend)
    }

    private func fallbackReasonText(for error: Error) -> String {
        if let clientError = error as? ClientError {
            switch clientError {
            case .requestTimedOut:
                switch language {
                case "ja": return "リクエストがタイムアウトしました。"
                case "zh": return "请求已超时。"
                default: return "The request timed out."
                }
            case .serverError, .unauthorized, .notFound:
                switch language {
                case "ja": return "AIサービスに接続できませんでした。"
                case "zh": return "无法连接到 AI 服务。"
                default: return "The AI service could not be reached."
                }
            default:
                switch language {
                case "ja": return "AIリクエストを完了できませんでした。"
                case "zh": return "AI 请求未能完成。"
                default: return "The AI request could not be completed."
                }
            }
        }
        return error.localizedDescription
    }

    private func parseChartData(from raw: String) -> ([(String, Double)], [(String, Double)]) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [])
        }
        // category_chart for pie charts
        let cats = (json["category_chart"] as? [[String: Any]])?.compactMap { c -> (String, Double)? in
            guard let name = c["name"] as? String, let amt = c["amount"] as? Double else { return nil }
            return (name, amt)
        } ?? []
        // trend_data for weekly 4-week trend (flattened into daily chart format)
        let days = (json["trend_data"] as? [[String: Any]])?.flatMap { week -> [(String, Double)] in
            guard let weekName = week["week"] as? String,
                  let categories = week["categories"] as? [[String: Any]] else { return [] }
            return categories.compactMap { cat -> (String, Double)? in
                guard let name = cat["name"] as? String, let amt = cat["amount"] as? Double else { return nil }
                return ("\(weekName) \(name)", amt)
            }
        } ?? []
        return (cats, days)
    }

    private func saveAnalysisHistoryEntry(_ data: AnalysisHistoryData) async {
        let localEntry = AnalysisHistory(
            id: UUID().uuidString,
            type: data.type,
            content: data.content,
            analysisDate: data.analysisDate,
            createdDate: ISO8601DateFormatter().string(from: Date()),
            categoryChartJSON: data.categoryChartJSON,
            dailyChartJSON: data.dailyChartJSON
        )

        analysisHistory.insert(localEntry, at: 0)
        saveLocalData()
    }

    func chartsForHistory(_ item: AnalysisHistory) -> (category: [(name: String, amount: Double)], daily: [(day: String, amount: Double)]) {
        let cal = Calendar.current
        let refDate: Date = {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = item.analysisDate ?? item.createdDate, let date = fmt.date(from: d) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = item.analysisDate ?? item.createdDate, let date = fmt.date(from: d) { return date }
            return Date()
        }()

        switch item.type {
        case "weekly":
            // Compute 4-week trend around the analysis date
            var trend: [(String, Double)] = []
            for weekOffset in stride(from: 3, through: 0, by: -1) {
                guard let weekStart = cal.date(byAdding: .day, value: -(weekOffset * 7 + 7), to: refDate),
                      let weekEnd = cal.date(byAdding: .day, value: -(weekOffset * 7), to: refDate) else { continue }
                let weekTxns = transactions.filter { tx in
                    guard let date = tx.dateValue else { return false }
                    return date >= weekStart && date < weekEnd
                }
                let total = aiSpendAmount(in: weekTxns)
                let df = DateFormatter(); df.dateFormat = "M/d"
                trend.append((df.string(from: weekStart), total))
            }
            return ([], trend)

        case "monthly":
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: refDate, toGranularity: .month)
            }
            let grouped = Dictionary(grouping: aiExpenseTransactions(monthTxns), by: { normalizedCategoryID(for: $0) ?? "other" })
            let cats = grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.1 > $1.1 }
                .map { (name: $0.0, amount: $0.1) }
            return (cats, [])

        case "forecast":
            // Category breakdown for current month
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: refDate, toGranularity: .month)
            }
            let grouped = Dictionary(grouping: aiExpenseTransactions(monthTxns), by: { normalizedCategoryID(for: $0) ?? "other" })
            let cats = grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.1 > $1.1 }
                .map { (name: $0.0, amount: $0.1) }

            // Trend: past 3 months + current
            var trend: [(String, Double)] = []
            for offset in stride(from: 3, through: 0, by: -1) {
                guard let monthStart = cal.date(byAdding: .month, value: -offset, to: refDate) else { continue }
                let txns = transactions.filter { tx in
                    guard let date = tx.dateValue else { return false }
                    return cal.isDate(date, equalTo: monthStart, toGranularity: .month)
                }
                let total = aiSpendAmount(in: txns)
                let df = DateFormatter(); df.dateFormat = "MMM"
                trend.append((df.string(from: monthStart), total))
            }
            return (cats, trend)

        default:
            return ([], [])
        }
    }

    private func computeWeeklyTrend() -> [(String, Double)] {
        let cal = Calendar.current
        var result: [(String, Double)] = []
        for weekOffset in stride(from: 3, through: 0, by: -1) {
            guard let weekStart = cal.date(byAdding: .day, value: -(weekOffset * 7 + 7), to: Date()),
                  let weekEnd = cal.date(byAdding: .day, value: -(weekOffset * 7), to: Date()) else { continue }
            let weekTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return date >= weekStart && date < weekEnd
            }
            let total = aiSpendAmount(in: weekTxns)
            let label: String = {
                let df = DateFormatter(); df.dateFormat = "M/d"
                return "\(df.string(from: weekStart))"
            }()
            result.append((label, total))
        }
        return result
    }

    private func computeCategoryBreakdown() -> [(String, Double)] {
        let monthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }
        let grouped = Dictionary(grouping: aiExpenseTransactions(monthTxns), by: { normalizedCategoryID(for: $0) ?? "other" })
        return grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
            .map { (name: $0.0, amount: $0.1) }
    }

    private func chartJSON(_ data: [(String, Double)]) -> String? {
        guard !data.isEmpty else { return nil }
        let arr = data.map { ["name": $0.0, "amount": $0.1] }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: arr) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    // MARK: - AI Formatting

    private var l: AILabels {
        switch language {
            case "ja": return .init(topCategory: "トップカテゴリ", pattern: "パターン", suggestion: "アドバイス",
                                 totalSpent: "支出合計", totalIncome: "収入合計", budgetUsed: "予算使用率", nextStep: "次のステップ",
                                 evidence: "根拠", confidence: "信頼度", dataQuality: "データの不足", watchItem: "注目ポイント")
            case "zh": return .init(topCategory: "主要类别", pattern: "消费模式", suggestion: "建议",
                                 totalSpent: "总支出", totalIncome: "总收入", budgetUsed: "预算使用率", nextStep: "下一步",
                                 evidence: "依据", confidence: "可信度", dataQuality: "数据缺口", watchItem: "关注项")
            default:  return .init(topCategory: "Top category", pattern: "Pattern", suggestion: "Suggestion",
                                 totalSpent: "Total spent", totalIncome: "Total income", budgetUsed: "Budget used", nextStep: "Next step",
                                 evidence: "Evidence", confidence: "Confidence", dataQuality: "Data gap", watchItem: "Watch item")
        }
    }

    private struct AILabels {
        let topCategory, pattern, suggestion: String
        let totalSpent, totalIncome, budgetUsed, nextStep: String
        let evidence, confidence, dataQuality, watchItem: String
    }

    private var promptLanguage: String {
        switch language {
        case "ja": return "Japanese"
        case "zh": return "Simplified Chinese"
        default: return "English"
        }
    }

    func languageDisplayName(for code: String) -> String {
        switch language {
        case "ja":
            switch code {
            case "ja": return "日本語"
            case "zh": return "簡体字中国語"
            default: return "英語"
            }
        case "zh":
            switch code {
            case "ja": return "日语"
            case "zh": return "简体中文"
            default: return "英语"
            }
        default:
            switch code {
            case "ja": return "Japanese"
            case "zh": return "Simplified Chinese"
            default: return "English"
            }
        }
    }

    // MARK: - Localization

    var homeTab: String {
        switch language { case "ja": return "ホーム"; case "zh": return "首页"; default: return "Home" }
    }
    var activityTab: String {
        switch language { case "ja": return "取引"; case "zh": return "交易"; default: return "Activity" }
    }
    var goalsTab: String {
        switch language { case "ja": return "目標"; case "zh": return "目标"; default: return "Goals" }
    }
    var aiTab: String {
        switch language { case "ja": return "AI"; case "zh": return "AI"; default: return "AI" }
    }
    var moreTab: String {
        switch language { case "ja": return "その他"; case "zh": return "更多"; default: return "More" }
    }
    var healthTab: String {
        switch language { case "ja": return "分析"; case "zh": return "分析"; default: return "Health" }
    }
    var appLocale: Locale {
        switch language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }
    var settingsTitle: String {
        switch language { case "ja": return "設定"; case "zh": return "设置"; default: return "Settings" }
    }
    var appearanceSection: String {
        switch language { case "ja": return "デザイン"; case "zh": return "外观"; default: return "Appearance" }
    }
    var budgetSection: String {
        switch language { case "ja": return "予算"; case "zh": return "预算"; default: return "Budget" }
    }
    var preferencesSection: String {
        switch language { case "ja": return "設定"; case "zh": return "偏好"; default: return "Preferences" }
    }
    var analysisSectionLabel: String {
        switch language { case "ja": return "自動分析"; case "zh": return "自动分析"; default: return "Auto Analysis" }
    }
    var dataSectionLabel: String {
        switch language { case "ja": return "データ"; case "zh": return "数据"; default: return "Data" }
    }
    var accountSectionLabel: String {
        switch language { case "ja": return "アカウント"; case "zh": return "账户"; default: return "Account" }
    }
    var signOutLabel: String {
        switch language { case "ja": return "サインアウト"; case "zh": return "退出登录"; default: return "Sign Out" }
    }
    var deleteAccountLabel: String {
        switch language { case "ja": return "アカウント削除"; case "zh": return "删除账户"; default: return "Delete Account" }
    }
    var exportCSVLabel: String {
        switch language { case "ja": return "CSVエクスポート"; case "zh": return "导出CSV"; default: return "Export as CSV" }
    }
    var autoAnalysisLabel: String {
        switch language { case "ja": return "自動分析を有効にする"; case "zh": return "启用自动分析"; default: return "Enable Auto Analysis" }
    }
    var signOutConfirmTitle: String { self.signOutLabel }
    var signOutConfirmMessage: String {
        switch language { case "ja": return "本当にサインアウトしますか？データは保持されます。"; case "zh": return "确定要退出登录吗？数据会被保留。"; default: return "Are you sure you want to sign out? Your data will be preserved." }
    }
    var deleteConfirmTitle: String { self.deleteAccountLabel }
    var deleteConfirmMessage: String {
        switch language { case "ja": return "すべてのデータが永久に削除されます。この操作は取り消せません。"; case "zh": return "这将永久删除所有数据。此操作无法撤销。"; default: return "This will permanently delete all data. This action cannot be undone." }
    }
    var cancelLabel: String {
        switch language { case "ja": return "キャンセル"; case "zh": return "取消"; default: return "Cancel" }
    }
    var deleteLabel: String {
        switch language { case "ja": return "削除"; case "zh": return "删除"; default: return "Delete" }
    }
    var languageLabel: String {
        switch language { case "ja": return "言語"; case "zh": return "语言"; default: return "Language" }
    }
    var currencyLabel: String {
        switch language { case "ja": return "通貨"; case "zh": return "货币"; default: return "Currency" }
    }
    var themeLabel: String {
        switch language { case "ja": return "テーマ"; case "zh": return "主题"; default: return "Theme" }
    }
    var colorModeLabel: String {
        switch language { case "ja": return "カラーモード"; case "zh": return "颜色模式"; default: return "Color Mode" }
    }
    var fontLabel: String {
        switch language { case "ja": return "フォント"; case "zh": return "字体"; default: return "Font" }
    }
    var dailyTabLabel: String {
        switch language { case "ja": return "デイリー"; case "zh": return "每日"; default: return "Daily" }
    }
    var weeklyTabLabel: String {
        switch language { case "ja": return "ウィークリー"; case "zh": return "每周"; default: return "Weekly" }
    }
    var monthlyTabLabel: String {
        switch language { case "ja": return "マンスリー"; case "zh": return "每月"; default: return "Monthly" }
    }
    var aiInsightsTitle: String {
        switch language { case "ja": return "AIインサイト"; case "zh": return "AI洞察"; default: return "AI Insights" }
    }
    var generatingLabel: String {
        switch language { case "ja": return "分析を生成中..."; case "zh": return "正在生成分析..."; default: return "Generating insights..." }
    }
    var resultLabel: String {
        switch language { case "ja": return "結果"; case "zh": return "结果"; default: return "Result" }
    }
    var clearLabel: String {
        switch language { case "ja": return "クリア"; case "zh": return "清除"; default: return "Clear" }
    }
    var generateLabel: String {
        switch language { case "ja": return "生成"; case "zh": return "生成"; default: return "Generate" }
    }
    var historyLabel: String {
        switch language { case "ja": return "履歴"; case "zh": return "历史"; default: return "History" }
    }
    func freeUsesRemaining(_ n: Int) -> String {
        switch language { case "ja": return "今月の無料利用はあと\(n)回です"; case "zh": return "本月剩余免费使用次数：\(n)"; default: return "\(n) free uses remaining this month" }
    }
    var dailyAnalysisTitle: String {
        switch language { case "ja": return "今日の分析"; case "zh": return "每日分析"; default: return "Daily Analysis" }
    }
    var dailyAnalysisSubtitle: String {
        switch language { case "ja": return "今日の支出パターンのAI分析を取得"; case "zh": return "获取今日消费模式的AI分析"; default: return "Get an AI recap of today's spending patterns" }
    }
    var weeklyRecapTitle: String {
        switch language { case "ja": return "週間レポート"; case "zh": return "每周回顾"; default: return "Weekly Recap" }
    }
    var weeklyRecapSubtitle: String {
        switch language { case "ja": return "過去7日間の支出を振り返る"; case "zh": return "回顾过去7天的消费"; default: return "Review your spending over the past 7 days" }
    }
    var monthlyInsightTitle: String {
        switch language { case "ja": return "月間分析"; case "zh": return "月度洞察"; default: return "Monthly Insight" }
    }
    var monthlyInsightSubtitle: String {
        switch language { case "ja": return "今月のお金を確認"; case "zh": return "查看本月资金状态"; default: return "Check this month's money" }
    }
    var upgradeTitle: String {
        switch language { case "ja": return "アップグレード"; case "zh": return "升级"; default: return "Upgrade" }
    }
    var upgradeToProLabel: String {
        switch language { case "ja": return "Proにアップグレード"; case "zh": return "升级到Pro"; default: return "Upgrade to Pro" }
    }
    var monthlyInsightRequiresPro: String {
        switch language { case "ja": return "月間分析はProが必要です"; case "zh": return "月度洞察需要Pro"; default: return "Monthly Insights require Pro" }
    }
    var upgradeDescription: String {
        switch language {
        case "ja": return "Proで予測、チャート、カテゴリ、AI分析を増やせます。"
        case "zh": return "Pro 可解锁预测、图表、分类和更多 AI 分析。"
        default: return "Unlock forecasts, charts, categories, and more AI."
        }
    }
    var subscribeLabel: String {
        switch language { case "ja": return "購読する"; case "zh": return "订阅"; default: return "Subscribe" }
    }
    var restoreLabel: String {
        switch language { case "ja": return "購入を復元"; case "zh": return "恢复购买"; default: return "Restore Purchases" }
    }
    var addTransactionTitle: String {
        switch language { case "ja": return "取引を追加"; case "zh": return "添加交易"; default: return "Add Transaction" }
    }
    var expenseLabel: String {
        switch language { case "ja": return "支出"; case "zh": return "支出"; default: return "Expense" }
    }
    var incomeLabel: String {
        switch language { case "ja": return "収入"; case "zh": return "收入"; default: return "Income" }
    }
    var amountLabel: String {
        switch language { case "ja": return "金額"; case "zh": return "金额"; default: return "Amount" }
    }
    var categoryLabel: String {
        switch language { case "ja": return "カテゴリ"; case "zh": return "类别"; default: return "Category" }
    }
    var noteLabel: String {
        switch language { case "ja": return "メモ"; case "zh": return "备注"; default: return "Note" }
    }
    var dateLabel: String {
        switch language { case "ja": return "日付"; case "zh": return "日期"; default: return "Date" }
    }
    var saveLabel: String {
        switch language { case "ja": return "保存"; case "zh": return "保存"; default: return "Save" }
    }
    var weekStartsLabel: String {
        switch language { case "ja": return "週の始まり"; case "zh": return "每周开始日"; default: return "Week Starts" }
    }
    var sundayLabel: String {
        switch language { case "ja": return "日曜日"; case "zh": return "周日"; default: return "Sunday" }
    }
    var mondayLabel: String {
        switch language { case "ja": return "月曜日"; case "zh": return "周一"; default: return "Monday" }
    }
    var monthlyIncomeLabel: String {
        switch language { case "ja": return "月収"; case "zh": return "月收入"; default: return "Monthly Income" }
    }
    var essentialsLabel: String {
        switch language { case "ja": return "固定費"; case "zh": return "固定支出"; default: return "Essentials" }
    }
    var savingsGoalLabel: String {
        switch language { case "ja": return "貯金目標"; case "zh": return "储蓄目标"; default: return "Savings Goal" }
    }
    var payDayLabel: String {
        switch language { case "ja": return "給料日"; case "zh": return "发薪日"; default: return "Pay Day" }
    }
    var dayLabel: (Int) -> String {
        switch language {
        case "ja": return { "\($0)日" }
        case "zh": return { "第\($0)天" }
        default: return { "Day \($0)" }
        }
    }
    var editBudgetLabel: String {
        switch language { case "ja": return "予算を編集"; case "zh": return "编辑预算"; default: return "Edit Budget" }
    }
    var savingDots: String {
        switch language { case "ja": return "保存中..."; case "zh": return "保存中..."; default: return "Saving..." }
    }
    var scanReceiptLabel: String {
        switch language { case "ja": return "レシートをスキャン"; case "zh": return "扫描收据"; default: return "Scan Receipt" }
    }
    var usageExhaustedFreeTitle: String {
        switch language { case "ja": return "利用制限に達しました"; case "zh": return "使用次数已用完"; default: return "Usage Limit Reached" }
    }
    var usageExhaustedFreeMessage: String {
        switch language { case "ja": return "今月の無料分を使い切りました。Proで分析を増やせます。"; case "zh": return "本月免费次数已用完。Pro 可解锁更多分析。"; default: return "Free uses are done for this month. Pro adds more analyses." }
    }
    var usageExhaustedProTitle: String {
        switch language { case "ja": return "月間制限に達しました"; case "zh": return "月度使用次数已用完"; default: return "Monthly Limit Reached" }
    }
    var usageExhaustedProMessage: String {
        switch language { case "ja": return "今月分を使い切りました。来月リセットされます。"; case "zh": return "本月次数已用完，下月会刷新。"; default: return "Monthly uses are done. They refresh next month." }
    }
    var okLabel: String {
        switch language { case "ja": return "OK"; case "zh": return "确定"; default: return "OK" }
    }
    var devModeEnabled: String {
        switch language { case "ja": return "開発者モード有効"; case "zh": return "开发者模式已启用"; default: return "Developer Mode Enabled" }
    }
    var devModeUnlimited: String {
        switch language { case "ja": return "すべての機能が無制限になりました"; case "zh": return "所有功能现在无限制"; default: return "All features are now unlimited" }
    }
    var developerToolsLabel: String {
        switch language { case "ja": return "開発者ツール"; case "zh": return "开发者工具"; default: return "Developer Tools" }
    }
    var developerProAccessLabel: String {
        switch language { case "ja": return "Proアクセス"; case "zh": return "Pro 访问权限"; default: return "Pro Access" }
    }
    var developerModeDisabledMessage: String {
        switch language { case "ja": return "通常のサブスクリプション状態を使用中"; case "zh": return "正在使用正常订阅状态"; default: return "Using the normal subscription state" }
    }
    var developerUnlockMessage: String {
        switch language { case "ja": return "設定でProアクセスを切り替えられます。"; case "zh": return "现在可以在设置中切换 Pro 访问权限。"; default: return "You can now toggle Pro access in Settings." }
    }
    var appVersionLabel: String {
        switch language { case "ja": return "アプリバージョン"; case "zh": return "应用版本"; default: return "App Version" }
    }

    // MARK: - Generic Localization

    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return loc(hour < 17 ? "Good morning, " : "Good evening, ")
    }

    func loc(_ key: String) -> String {
        switch language {
        case "ja": return LocalizationStrings.ja[key] ?? Self.jaDict[key] ?? key
        case "zh": return LocalizationStrings.zh[key] ?? Self.zhDict[key] ?? key
        default: return key
        }
    }

    private static let jaDict: [String: String] = [
// App
        "PennyLet": "PennyLet",
        "Track spending, reach goals": "支出を管理して目標を達成",
        "Sign In with Cloud": "クラウドでサインイン",
        "You'll be redirected to sign in securely.": "安全にサインインするためリダイレクトされます。",
        "Continue as Guest": "ゲストとして続ける",
        "Guest Mode": "ゲストモード",
        "Sign in to save your data and unlock all features.": "サインインしてデータを保存し、すべての機能を解放しましょう。",
        "Active Subscriptions": "アクティブなサブスク",
        "found": "件見つかりました",
        "Yearly": "年間",
        "Detected on this device": "このデバイスで検出",
        "Expired": "期限切れ",
        "No App Store subscriptions found": "App Storeサブスクリプションが見つかりません",
        "Active subscriptions purchased through Apple will appear here automatically.": "Appleを通じて購入したアクティブなサブスクリプションが自動的に表示されます。",
        "Scan for Subscriptions": "サブスクリプションをスキャン",
        "PennyLet can detect your active App Store subscriptions and track them automatically.": "PennyLetはアクティブなApp Storeサブスクリプションを検出し、自動的に追跡します。",
        "Scan Now": "今すぐスキャン",
        "Scanning subscriptions...": "サブスクリプションをスキャン中...",
        "Subscription Tracker": "サブスクリプション管理",
        "Create Account or Sign In": "アカウント作成 / サインイン",
        "Account Required": "アカウントが必要です",
        "Upgrading to Pro requires an account. Create one or sign in to continue.": "Proへのアップグレードにはアカウントが必要です。アカウントを作成するかサインインしてください。",
        "Log In": "ログイン",

        // Onboarding
        "Already have an account? Log In": "アカウントをお持ちですか？ログイン",
        "How PennyLet Works": "PennyLetの使い方",
        "Help": "ヘルプ",
        "Done": "完了",
        "help_balance": "今月入ったお金から出ていったお金を引いた金額です。今月が順調かどうかをすばやく確認できます。",
        "help_safe_daily": "使う前に見るための金額です。PennyLetは請求、貯金目標、予定している支出を先に取り分けます。",
        "help_categories": "今月どこにお金を使ったかを表示します。注意したいカテゴリを見つけやすくなります。",
        "help_ai": "保存済みの支出データから、日次・週次・月次・予測の短いメモを作ります。オンラインAIが遅いときは、端末内の集計で代わりに表示します。",
        "help_subscriptions": "サブスクを1か所で管理できます。手動追加、対象のApp Store購入の確認、取引から見つけた候補の確認ができます。",
        "Welcome to PennyLet": "PennyLetへようこそ",
        "Track your spending, build healthy budgets, and reach your financial goals.": "支出を管理し、健全な予算を立て、目標を達成しましょう。",
        "Back": "戻る",
        "Next": "次へ",
        "Get Started": "始める",
        "Please enter a valid monthly income": "有効な月収を入力してください",
        "Preferences": "設定",
        "Appearance": "デザイン",
        "Color Mode": "カラーモード",
        "Font": "フォント",
        "Region": "地域",
        "Currency": "通貨",
        "Your Budget": "あなたの予算",
        "After tax": "税引後",
        "Essential Bills": "固定費",
        "Rent, utilities, etc.": "家賃、光熱費など",
        "Savings Goal": "貯金目標",
        "Monthly target": "月間目標",
        "Pay Day": "給料日",

        // Dashboard
        "Hello, ": "こんにちは、",
        "Monthly Income": "月収",
        "Good morning, ": "おはようございます、",
        "Good evening, ": "こんばんは、",
        "there": "ゲスト",
        "Safe to Spend Today": "今日使える金額",
        "Spent": "支出",
        "Income": "収入",
        "Balance": "残高",
        "Top Categories": "カテゴリ別",
        "No spending this month": "今月の支出はありません",
        "Recent Activity": "最近の取引",
        "View All": "すべて見る",
        "No transactions yet": "まだ取引がありません",
        "d left": "日残り",
        "% used": "%使用",
        "% of budget used": "予算の%使用",

        // Activity
        "Activity": "取引",
        "Search transactions": "取引を検索",
        "Filter": "フィルター",
        "No Transactions": "取引なし",
        "No Results": "結果なし",
        "Generate Test Data": "テストデータを生成",
        "Add your first transaction": "最初の取引を追加しましょう",
        "Try a different search": "別のキーワードで検索",

        // Goals
        "Goals": "目標",
        "No Goals Yet": "まだ目標がありません",
        "Set savings goals to track your progress": "貯金目標を設定して進捗を管理しましょう",
        "% complete": "%達成",
        "Goal Details": "目標詳細",
        "Name": "名前",
        "Target Amount": "目標金額",
        "Current Amount": "現在の金額",
        "Frequency": "頻度",
        "Weekly": "毎週",
        "Biweekly": "隔週",
        "Monthly": "毎月",
        "New Goal": "新しい目標",
        "Add Goal": "目標を追加",

        // Budget Health
        "Budget Health": "予算の健全性",
        "Monthly Disposable": "月間自由支出",
        "Spending by Category": "カテゴリ別支出",
        "No spending data this month": "今月の支出データがありません",
        "Income vs Spending": "収入 vs 支出",
        "Remaining": "残り",
        "Safe Daily": "安全な1日額",
        "Days Left": "残り日数",

        // Upgrade
        "PennyLet Pro": "PennyLet Pro",
        "Free": "無料",
        "Pro": "Pro",
        "Plan": "プラン",
        "Yearly (save 40%)": "年間（40%割引）",
        "Processing...": "処理中...",
        "Subscribe": "購読する",
        "Restore Purchases": "購入を復元",
        "More AI Analyses": "より多くのAI分析",
        "30 daily, 15 weekly, 10 monthly, and 3 forecasts every month": "毎月30回のデイリー、15回のウィークリー、10回のマンスリー、3回の予測",
        "Custom Categories": "カスタムカテゴリ",
        "Create your own spending and income categories": "自分だけの支出・収入カテゴリを作成",
        "Spending Forecasts": "支出予測",
        "AI predicts next month's spending based on your history": "過去のデータからAIが来月の支出を予測",
        "Forecast": "予測",
        "Spending Forecast": "支出予測",
        "Weekly Trend": "週間トレンド",
        "Next Month": "来月",
        "Monthly Limit Reached": "月間制限に達しました",
        "Please wait until the first of next month for your usage to refresh.": "来月1日までお待ちください。",
        "Free Uses Exhausted": "無料利用回数を使い切りました",
        "Upgrade to PennyLet Pro for more analyses and unlimited access.": "PennyLet Proにアップグレードして、より多くの分析と無制限のアクセスを。",
        " free left of ": "回の無料利用が残っています（全",
        " uses this month": "回/月）",
        "See AI-predicted spending for next month based on your history.": "過去の履歴に基づいてAIが予測した来月の支出を表示します。",
        "New": "新規",
        "New Category": "新しいカテゴリ",
        "Add": "追加",
        "/mo": "/月",
        "Upgrade": "アップグレード",
        "Get more AI analyses, visual charts, forecasts, and deeper spending insights.": "より多くのAI分析、ビジュアルチャート、予測、より深い支出インサイトを。",
        "Visual Pie Charts": "ビジュアル円グラフ",
        "Beautiful spending breakdown charts in weekly and monthly reports": "週次・月次レポートの美しい支出内訳グラフ",
        "Deeper Spending Insights": "より深い支出インサイト",
        "Detailed patterns, trends, and personalized recommendations": "詳細なパターン、トレンド、パーソナライズされた提案",
        "Just $3.33/month": "月々たった$3.33",
        "AI Spending Insights": "AI支出分析",
        "Daily, weekly, and monthly analysis": "日次・週次・月次の分析",
        "Receipt Scanner": "レシートスキャン",
        "Snap receipts to log expenses instantly": "レシートを撮影して即座に記録",
        "Custom Tags": "カスタムタグ",
        "Organize transactions your way": "取引を自由に整理",
        "Budget Alerts": "予算アラート",
        "Get notified when nearing limits": "予算が近づいたら通知",
        "Advanced Charts": "高度なグラフ",
        "Deeper insights into your spending": "支出をより深く分析",
        "Unable to load pricing. Please try again.": "価格を読み込めませんでした。再試行してください。",
        "No active subscription found.": "有効なサブスクリプションが見つかりません。",
        "Purchase restored! Pro features are now unlocked.": "購入が復元されました！Pro機能のロックが解除されました。",

        // Receipt Scanner
        "Scan Receipt": "レシートをスキャン",
        "Take Photo": "写真を撮る",
        "Use": "使用",
        "Take a photo of your receipt": "レシートを撮影してください",
        "We'll extract the merchant, amount, and category automatically.": "店名、金額、カテゴリを自動的に抽出します。",
        "Choose Photo": "写真を選択",
        "Extracted Details": "抽出された情報",
        "Merchant": "店名",
        "Could not load image.": "画像を読み込めませんでした。",
        "Could not prepare image.": "画像を準備できませんでした。",
        "Uploading receipt...": "レシートをアップロード中...",
        "Extracting details...": "詳細を抽出中...",
        "Could not parse receipt. Try again.": "レシートを解析できませんでした。再試行してください。",

        // Charts / AI
        "Category Breakdown": "カテゴリ別内訳",
        "Daily Spending": "1日の支出",
        "Analysis": "分析",

        // Misc
        "Developer Mode": "開発者モード",
        "Type": "種類",
        "Budget": "予算",
        "Save": "保存",
        "Cancel": "キャンセル",
        "Delete": "削除",
        "Theme": "テーマ",
        "Saving...": "保存中...",
        "Amount": "金額",
        "0": "0",
        "Light": "ライト",
        "Dark": "ダーク",
        "System": "システム",
        "Sage": "セージ",
        "Ocean": "オーシャン",
        "Sunset": "サンセット",
        "Lavender": "ラベンダー",
        "Forest": "フォレスト",
        "Midnight": "ミッドナイト",
        "Coral": "コーラル",
        "Honey": "ハニー",
        "Plum": "プラム",
        "Mint": "ミント",
        "Sky": "スカイ",
         "Blush": "ブラッシュ",
        "Inter": "Inter",
        "Serif": "セリフ",
        "Rounded": "ラウンド",
        "Mono": "モノ",
        "Food & Dining": "食事",
        "Groceries": "食料品",
        "Transport": "交通",
        "Shopping": "ショッピング",
        "Entertainment": "エンタメ",
        "Health": "健康",
        "Bills & Utilities": "光熱費",
        "Rent / Housing": "家賃",
        "Subscriptions": "サブスク",
        "Travel": "旅行",
        "Education": "教育",
        "Gifts": "ギフト",
        "Other": "その他",
        "Salary": "給料",
        "Freelance": "フリーランス",
        "Investment": "投資",
        "Gift": "贈与",
        "All": "すべて",
        "Expense": "支出",
        "Allocation": "配分",
        "Validation failed": "入力エラー",
        "Invalid URL": "無効なURL",
        "Invalid response from server": "サーバーからの無効な応答",
        "Session expired. Please sign in again.": "セッションが切れました。もう一度サインインしてください。",
        "Resource not found": "リソースが見つかりません",
        "HTTP error": "HTTPエラー",
        "Server error": "サーバーエラー",
        "Data error": "データエラー",
        "Date,Type,Category,Amount,Note,Merchant": "日付,種類,カテゴリ,金額,メモ,店名",
        "21:00": "21:00",
        "09:00": "09:00",
        "$39.99/yr": "¥4,800/年",
        "$4.99/mo": "¥600/月",
        "10x More AI Analyses": "10倍のAI分析",
        "30 daily, 15 weekly, and 10 monthly analyses every month": "毎月30回のデイリー、15回のウィークリー、10回のマンスリー分析",
        "Sign In with Apple": "Appleでサインイン",
        "Email": "メールアドレス",
        "Password": "パスワード",
        "Sign In": "サインイン",
        "Create Account": "アカウント作成",
        "Already have an account? Sign In": "アカウントをお持ちですか？サインイン",
        "Don't have an account? Create one": "アカウントがありませんか？作成する",
        "or": "または",
        "Verify Email": "メール確認",
        "Enter the verification code sent to your email": "メールに送信された確認コードを入力してください",
        "Verification Code": "確認コード",
        "Verify & Sign In": "確認してサインイン",
        "Converting...": "変換中...",
        "Rate": "レート",
        "Refresh Exchange Rates": "為替レートを更新",
        "Network error": "ネットワークエラー",
        "Currency not supported": "サポートされていない通貨",
        "Could not fetch exchange rate.": "為替レートを取得できませんでした。",
        "Exchange rates updated": "為替レートを更新しました",
    ]

    private static let zhDict: [String: String] = [
// App
        "PennyLet": "PennyLet",
        "Track spending, reach goals": "追踪支出，实现目标",
        "Sign In with Cloud": "通过云端登录",
        "You'll be redirected to sign in securely.": "您将被重定向以安全登录。",
        "Continue as Guest": "以游客身份继续",
        "Guest Mode": "游客模式",
        "Sign in to save your data and unlock all features.": "登录以保存数据并解锁所有功能。",
        "Active Subscriptions": "活跃订阅",
        "found": "个",
        "Yearly": "每年",
        "Detected on this device": "在此设备上检测到",
        "Expired": "已过期",
        "No App Store subscriptions found": "未找到App Store订阅",
        "Active subscriptions purchased through Apple will appear here automatically.": "通过Apple购买的活跃订阅将自动显示在这里。",
        "Scan for Subscriptions": "扫描订阅",
        "PennyLet can detect your active App Store subscriptions and track them automatically.": "PennyLet可以检测您活跃的App Store订阅并自动追踪。",
        "Scan Now": "立即扫描",
        "Scanning subscriptions...": "正在扫描订阅...",
        "Subscription Tracker": "订阅追踪",
        "Create Account or Sign In": "创建账户 / 登录",
        "Account Required": "需要账户",
        "Upgrading to Pro requires an account. Create one or sign in to continue.": "升级到Pro需要账户。请创建账户或登录以继续。",
        "Log In": "登录",

        // Onboarding
        "Already have an account? Log In": "已有账户？登录",
        "How PennyLet Works": "PennyLet使用指南",
        "Help": "帮助",
        "Done": "完成",
        "help_balance": "这是本月进来的钱减去花出去的钱。可以快速判断这个月整体是否顺利。",
        "help_safe_daily": "这是花钱前最适合看的数字。PennyLet 会先预留账单、储蓄目标和计划支出。",
        "help_categories": "这里显示本月钱花在了哪里，帮助您找到最值得注意的类别。",
        "help_ai": "AI 会把已保存的支出数据整理成每日、每周、每月或预测短文。如果在线 AI 太慢，PennyLet 会改用本机摘要。",
        "help_subscriptions": "订阅会集中在一个地方。您可以手动添加、扫描符合条件的 App Store 购买，或查看交易中发现的可能订阅。",
        "Welcome to PennyLet": "欢迎使用PennyLet",
        "Track your spending, build healthy budgets, and reach your financial goals.": "追踪支出，建立健康预算，实现财务目标。",
        "Back": "返回",
        "Next": "下一步",
        "Get Started": "开始使用",
        "Please enter a valid monthly income": "请输入有效的月收入",
        "Preferences": "偏好设置",
        "Appearance": "外观",
        "Color Mode": "颜色模式",
        "Font": "字体",
        "Region": "地区",
        "Currency": "货币",
        "Your Budget": "您的预算",
        "After tax": "税后",
        "Essential Bills": "固定支出",
        "Rent, utilities, etc.": "房租、水电等",
        "Savings Goal": "储蓄目标",
        "Monthly target": "月度目标",
        "Pay Day": "发薪日",

        // Dashboard
        "Hello, ": "你好，",
        "Monthly Income": "月收入",
        "Good morning, ": "早上好，",
        "Good evening, ": "晚上好，",
        "there": "访客",
        "Safe to Spend Today": "今日可安全支出",
        "Spent": "已支出",
        "Income": "收入",
        "Balance": "余额",
        "Top Categories": "热门类别",
        "No spending this month": "本月无支出",
        "Recent Activity": "最近交易",
        "View All": "查看全部",
        "No transactions yet": "暂无交易",
        "d left": "天剩余",
        "% used": "%已使用",
        "% of budget used": "预算使用率",

        // Activity
        "Activity": "交易",
        "Search transactions": "搜索交易",
        "Filter": "筛选",
        "No Transactions": "暂无交易",
        "No Results": "无结果",
        "Generate Test Data": "生成测试数据",
        "Add your first transaction": "添加第一笔交易",
        "Try a different search": "尝试其他搜索",

        // Goals
        "Goals": "目标",
        "No Goals Yet": "暂无目标",
        "Set savings goals to track your progress": "设定储蓄目标追踪进度",
        "% complete": "%完成",
        "Goal Details": "目标详情",
        "Name": "名称",
        "Target Amount": "目标金额",
        "Current Amount": "当前金额",
        "Frequency": "频率",
        "Weekly": "每周",
        "Biweekly": "每两周",
        "Monthly": "每月",
        "New Goal": "新建目标",
        "Add Goal": "添加目标",

        // Budget Health
        "Budget Health": "预算健康",
        "Monthly Disposable": "月度可支配",
        "Spending by Category": "分类支出",
        "No spending data this month": "本月无支出数据",
        "Income vs Spending": "收入与支出",
        "Remaining": "剩余",
        "Safe Daily": "日均可花",
        "Days Left": "剩余天数",

        // Upgrade
        "PennyLet Pro": "PennyLet Pro",
        "Free": "免费",
        "Pro": "Pro",
        "Plan": "计划",
        "Yearly (save 40%)": "年度（节省40%）",
        "Processing...": "处理中...",
        "Subscribe": "订阅",
        "Restore Purchases": "恢复购买",
        "More AI Analyses": "更多AI分析",
        "30 daily, 15 weekly, 10 monthly, and 3 forecasts every month": "每月30次每日、15次每周、10次每月、3次预测",
        "Custom Categories": "自定义类别",
        "Create your own spending and income categories": "创建您自己的支出和收入类别",
        "Spending Forecasts": "支出预测",
        "AI predicts next month's spending based on your history": "AI根据您的历史记录预测下月支出",
        "Forecast": "预测",
        "Spending Forecast": "支出预测",
        "Weekly Trend": "每周趋势",
        "Next Month": "下月",
        "Monthly Limit Reached": "已达月度上限",
        "Please wait until the first of next month for your usage to refresh.": "请等待下月1日刷新使用次数。",
        "Free Uses Exhausted": "免费使用次数已用完",
        "Upgrade to PennyLet Pro for more analyses and unlimited access.": "升级到PennyLet Pro以获取更多分析和无限访问。",
        " free left of ": "次免费剩余/共",
        " uses this month": "次每月",
        "See AI-predicted spending for next month based on your history.": "查看AI根据您的历史记录预测的下月支出。",
        "New": "新建",
        "New Category": "新类别",
        "Add": "添加",
        "/mo": "/月",
        "Upgrade": "升级",
        "Get more AI analyses, visual charts, forecasts, and deeper spending insights.": "获取更多 AI 分析、可视化图表、预测和更深入的消费洞察。",
        "Visual Pie Charts": "可视化饼图",
        "Beautiful spending breakdown charts in weekly and monthly reports": "每周和每月报告中精美的消费分类图表",
        "Deeper Spending Insights": "更深入的消费洞察",
        "Detailed patterns, trends, and personalized recommendations": "详细的消费模式、趋势和个性化建议",
        "Just $3.33/month": "每月仅$3.33",
        "AI Spending Insights": "AI消费洞察",
        "Daily, weekly, and monthly analysis": "每日、每周、每月分析",
        "Receipt Scanner": "收据扫描器",
        "Snap receipts to log expenses instantly": "拍照即可即时记录消费",
        "Custom Tags": "自定义标签",
        "Organize transactions your way": "按您的方式整理交易",
        "Budget Alerts": "预算提醒",
        "Get notified when nearing limits": "接近限额时收到通知",
        "Advanced Charts": "高级图表",
        "Deeper insights into your spending": "更深入的消费洞察",
        "Unable to load pricing. Please try again.": "无法加载定价，请重试。",
        "No active subscription found.": "未找到有效订阅。",
        "Purchase restored! Pro features are now unlocked.": "购买已恢复！Pro功能现已解锁。",

        // Receipt Scanner
        "Scan Receipt": "扫描收据",
        "Take Photo": "拍照",
        "Use": "使用",
        "Take a photo of your receipt": "拍摄收据照片",
        "We'll extract the merchant, amount, and category automatically.": "我们将自动提取商家、金额和类别。",
        "Choose Photo": "选择照片",
        "Extracted Details": "提取详情",
        "Merchant": "商家",
        "Could not load image.": "无法加载图片。",
        "Could not prepare image.": "无法准备图片。",
        "Uploading receipt...": "正在上传收据...",
        "Extracting details...": "正在提取详情...",
        "Could not parse receipt. Try again.": "无法解析收据，请重试。",

        // Charts / AI
        "Category Breakdown": "类别分布",
        "Daily Spending": "每日支出",
        "Analysis": "分析",

        // Misc
        "Developer Mode": "开发者模式",
        "Type": "类型",
        "Budget": "预算",
        "Save": "保存",
        "Cancel": "取消",
        "Delete": "删除",
        "Theme": "主题",
        "Saving...": "保存中...",
        "Amount": "金额",
        "0": "0",
        "Light": "浅色",
        "Dark": "深色",
        "System": "跟随系统",
        "Sage": "鼠尾草",
        "Ocean": "海洋",
        "Sunset": "日落",
        "Lavender": "薰衣草",
        "Forest": "森林",
        "Midnight": "午夜",
        "Coral": "珊瑚",
        "Honey": "蜂蜜",
        "Plum": "梅子",
        "Mint": "薄荷",
        "Sky": "天空",
        "Blush": "腮红",
        "Inter": "Inter",
        "Serif": "衬线体",
        "Rounded": "圆体",
        "Mono": "等宽体",
        "Food & Dining": "餐饮",
        "Groceries": "食品杂货",
        "Transport": "交通",
        "Shopping": "购物",
        "Entertainment": "娱乐",
        "Health": "健康",
        "Bills & Utilities": "账单与水电",
        "Rent / Housing": "房租",
        "Subscriptions": "订阅",
        "Travel": "旅行",
        "Education": "教育",
        "Gifts": "礼物",
        "Other": "其他",
        "Salary": "工资",
        "Freelance": "自由职业",
        "Investment": "投资",
        "Gift": "赠与",
        "All": "全部",
        "Expense": "支出",
        "Allocation": "分配",
        "Validation failed": "输入验证失败",
        "Invalid URL": "无效URL",
        "Invalid response from server": "服务器响应无效",
        "Session expired. Please sign in again.": "会话已过期，请重新登录。",
        "Resource not found": "资源未找到",
        "HTTP error": "HTTP错误",
        "Server error": "服务器错误",
        "Data error": "数据错误",
        "Date,Type,Category,Amount,Note,Merchant": "日期,类型,类别,金额,备注,商家",
        "21:00": "21:00",
        "09:00": "09:00",
        "$39.99/yr": "¥258/年",
        "$4.99/mo": "¥33/月",
        "10x More AI Analyses": "10倍AI分析次数",
        "30 daily, 15 weekly, and 10 monthly analyses every month": "每月30次每日分析、15次每周回顾、10次月度洞察",
        "Sign In with Apple": "通过Apple登录",
        "Email": "邮箱",
        "Password": "密码",
        "Sign In": "登录",
        "Create Account": "创建账户",
        "Already have an account? Sign In": "已有账户？登录",
        "Don't have an account? Create one": "没有账户？创建一个",
        "or": "或",
        "Verify Email": "验证邮箱",
        "Enter the verification code sent to your email": "请输入发送到您邮箱的验证码",
        "Verification Code": "验证码",
        "Verify & Sign In": "验证并登录",
        "Converting...": "转换中...",
        "Rate": "汇率",
        "Refresh Exchange Rates": "刷新汇率",
        "Network error": "网络错误",
        "Currency not supported": "不支持的货币",
        "Could not fetch exchange rate.": "无法获取汇率。",
        "Exchange rates updated": "汇率已更新",
    ]

    func deleteAllData() async {
        restoreDefaults()
    }

    // MARK: - Data Loading

    func refreshAll() async {
        loadLocalData()
        applyBudgetPreferences()
        postDueRecurringSubscriptions()
        isLoadingData = false
    }

    private func applyBudgetPreferences() {
        guard let budget = currentBudget else { return }
        if let t = budget.theme, let appTheme = AppTheme(rawValue: t) { theme = appTheme }
        if let cm = budget.colorMode, let mode = AppColorMode(rawValue: cm) { colorMode = mode }
        if let f = budget.font, let appFont = AppFont(rawValue: f) { font = appFont }
        if let c = budget.currency { currency = c }
        if let l = budget.language { language = l }
    }

    // MARK: - Mutations

    func addTransaction(_ data: TransactionData) async {
        let localId = UUID().uuidString
        let txn = Transaction(
            id: localId, amount: data.amount, type: data.type,
            category: data.category, note: data.note, date: data.date,
            merchant: data.merchant, description: data.description,
            isRecurring: data.isRecurring, tags: data.tags,
            originalCurrency: data.originalCurrency,
            originalAmount: data.originalAmount,
            exchangeRate: data.exchangeRate,
            baseCurrency: data.baseCurrency
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            transactions.insert(txn, at: 0)
        }
        saveLocalData()
    }

    func addRecurringSubscription(
        name: String,
        amount: Double,
        currencyCode: String,
        category: String?,
        note: String?,
        startDate: Date,
        interval: RecurringSubscription.BillingInterval,
        customIntervalDays: Int?
    ) async {
        let id = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var nextDate = nextBillingDate(after: startDate, interval: interval, customIntervalDays: customIntervalDays)
        while calendar.startOfDay(for: nextDate) <= today {
            nextDate = nextBillingDate(after: nextDate, interval: interval, customIntervalDays: customIntervalDays)
        }
        let subscription = RecurringSubscription(
            id: id,
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            note: note,
            startDate: dateString(startDate),
            nextBillingDate: dateString(nextDate),
            interval: interval,
            customIntervalDays: customIntervalDays,
            isActive: true,
            createdDate: now,
            updatedDate: now
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            recurringSubscriptions.insert(subscription, at: 0)
        }
        saveLocalData()
    }

    func deleteRecurringSubscription(_ subscription: RecurringSubscription) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            recurringSubscriptions.removeAll { $0.id == subscription.id }
        }
        saveLocalData()
    }

    func deactivateRecurringSubscription(_ subscription: RecurringSubscription) {
        guard let index = recurringSubscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        recurringSubscriptions[index].isActive = false
        recurringSubscriptions[index].updatedDate = ISO8601DateFormatter().string(from: Date())
        saveLocalData()
    }

    private func postDueRecurringSubscriptions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var generated: [Transaction] = []
        var updated = false

        for index in recurringSubscriptions.indices {
            guard recurringSubscriptions[index].isActive,
                  var nextDate = Date.fromDateString(recurringSubscriptions[index].nextBillingDate) else { continue }

            nextDate = calendar.startOfDay(for: nextDate)
            var safetyCounter = 0
            while nextDate <= today && safetyCounter < 36 {
                let subscription = recurringSubscriptions[index]
                let dueDate = dateString(nextDate)
                let tag = "subscription:\(subscription.id)"

                if !transactions.contains(where: { $0.date == dueDate && ($0.tags ?? []).contains(tag) }) {
                    let now = ISO8601DateFormatter().string(from: Date())
                    generated.append(Transaction(
                        id: UUID().uuidString,
                        amount: subscription.amount,
                        type: .expense,
                        category: subscription.category ?? "subscriptions",
                        note: subscription.note ?? subscription.name,
                        date: dueDate,
                        merchant: subscription.name,
                        description: nil,
                        isRecurring: true,
                        tags: [tag, "subscription"],
                        createdDate: now,
                        updatedDate: now,
                        originalCurrency: nil,
                        originalAmount: nil,
                        exchangeRate: nil,
                        baseCurrency: subscription.currencyCode
                    ))
                }

                nextDate = nextBillingDate(after: nextDate, interval: subscription.interval, customIntervalDays: subscription.customIntervalDays)
                recurringSubscriptions[index].nextBillingDate = dateString(nextDate)
                recurringSubscriptions[index].updatedDate = ISO8601DateFormatter().string(from: Date())
                updated = true
                safetyCounter += 1
            }
        }

        guard updated || !generated.isEmpty else { return }
        if !generated.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                transactions.insert(contentsOf: generated.sorted { $0.date > $1.date }, at: 0)
            }
        }
        saveLocalData()
    }

    private func nextBillingDate(
        after date: Date,
        interval: RecurringSubscription.BillingInterval,
        customIntervalDays: Int?
    ) -> Date {
        let calendar = Calendar.current
        switch interval {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom:
            return calendar.date(byAdding: .day, value: max(1, customIntervalDays ?? 30), to: date) ?? date
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func refreshExchangeRates() async {
        do {
            _ = try await CurrencyRateService.shared.refreshRates(base: currency)
        } catch {
            // Silently fail; rates will be fetched on next transaction
        }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        let id = transaction.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            transactions.removeAll { $0.id == id }
        }
        saveLocalData()
    }

    func updateBudget(_ data: BudgetData) async {
        updateBudgetLocally(data)
    }

    func addGoal(_ data: GoalData) async {
        let now = ISO8601DateFormatter().string(from: Date())
        let goal = Goal(
            id: UUID().uuidString,
            name: data.name,
            targetAmount: data.targetAmount,
            currentAmount: data.currentAmount ?? 0,
            targetDate: data.targetDate,
            category: data.category,
            paymentAmount: data.paymentAmount,
            frequency: data.frequency,
            startDate: data.startDate,
            createdDate: now,
            updatedDate: now
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            goals.append(goal)
        }
        saveLocalData()
    }

    func updateGoalAmount(id: String, newAmount: Double) async {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        let optimistic = goals[idx]
        let wasComplete = optimistic.progress >= 1
        goals[idx] = Goal(
            id: optimistic.id, name: optimistic.name,
            targetAmount: optimistic.targetAmount,
            currentAmount: newAmount,
            targetDate: optimistic.targetDate, category: optimistic.category,
            paymentAmount: optimistic.paymentAmount, frequency: optimistic.frequency,
            startDate: optimistic.startDate,
            createdDate: optimistic.createdDate,
            updatedDate: ISO8601DateFormatter().string(from: Date())
        )
        saveLocalData()

        if !wasComplete, goals[idx].progress >= 1 {
            NotificationService.shared.scheduleGoalCompleted(
                id: optimistic.id,
                title: loc("Goal completed!"),
                body: "\(optimistic.name) \(loc("is fully funded."))"
            )
        }
    }

    func deleteGoal(_ goal: Goal) async {
        let id = goal.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            goals.removeAll { $0.id == id }
        }
        saveLocalData()
    }

    func deleteAnalysisHistory(_ item: AnalysisHistory) async {
        await deleteAnalysisHistoryById(item.id)
    }

    func deleteAnalysisHistoryById(_ id: String) async {
        analysisHistory.removeAll { $0.id == id }
        saveLocalData()
    }

    var needsOnboarding: Bool {
        guard !isLoading else { return false }
        return budgets.isEmpty
    }
}
