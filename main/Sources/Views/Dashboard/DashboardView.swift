import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showHelp = false
    @State private var activeSheet: DashboardSheet?
    @State private var expandedHelpItemIDs: Set<String> = []

    var body: some View {
        let visibleBlocks = viewModel.visibleHomeBlocks
        let dashboard = viewModel.localMoneyLogicV2Dashboard
        let spendSummary = viewModel.dashboardSpendSummary
        let reviewQueue = viewModel.reviewQueue
        let categoryBreakdown = viewModel.categoryBreakdown
        let currency = viewModel.currency
        let hasTransactions = !viewModel.transactions.isEmpty

        ScrollView {
            VStack(spacing: 18) {
                ForEach(Array(visibleBlocks.enumerated()), id: \.element) { index, block in
                    homeBlockView(
                        block,
                        dashboard: dashboard,
                        spendSummary: spendSummary,
                        reviewQueue: reviewQueue,
                        categoryBreakdown: categoryBreakdown,
                        currency: currency,
                        hasTransactions: hasTransactions
                    )
                        .cardEntrance(index: index)
                }

                if !hasTransactions && !viewModel.isLoadingData {
                    QuietDashboardStartCard()
                        .cardEntrance(index: visibleBlocks.count + 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary.opacity(0.78))
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color(.separator).opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.loc("Help"))
            }
        }
        .refreshable {
            await viewModel.refreshAll()
        }
        .overlay {
            if viewModel.isLoadingData && viewModel.transactions.isEmpty {
                ProgressView()
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                helpView
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .todaySnapshot:
                    TodaySnapshotEditorSheet()
                case .reviewQueue:
                    ReviewQueueDetailSheet()
                case .watchlists:
                    WatchlistEditorSheet()
                }
            }
        }
    }

    @ViewBuilder
    private func homeBlockView(
        _ block: AppDisplayBlock,
        dashboard: MoneyLogicV2DashboardSummary,
        spendSummary: SpendSummary,
        reviewQueue: [MoneyLogicV2ReviewItem],
        categoryBreakdown: [CategoryBreakdown],
        currency: String,
        hasTransactions: Bool
    ) -> some View {
        switch block {
        case .homeSafeToSpend:
            SpendHeroCard(
                summary: spendSummary,
                startFromTodaySummary: viewModel.startFromTodaySummary,
                localFirstSummary: dashboard.safeToSpend,
                currency: currency,
                theme: viewModel.theme,
                onEditSnapshot: {
                    activeSheet = .todaySnapshot
                }
            )
        case .homeMonthlyPulse:
            QuickStatsRow(summary: spendSummary, currency: currency)
        case .homeReviewQueue:
            if !reviewQueue.isEmpty {
                DashboardReviewQueueCard(
                    items: reviewQueue,
                    onOpen: { activeSheet = .reviewQueue }
                )
            }
        case .homeWatchlists:
            DashboardWatchlistsCard(
                watchlists: dashboard.watchlists,
                currency: currency,
                onManage: { activeSheet = .watchlists }
            )
        case .homeTopCategories:
            if hasTransactions, !categoryBreakdown.isEmpty {
                TopCategoriesList(breakdown: categoryBreakdown, currency: currency)
            }
        case .homeRecentActivity:
            if hasTransactions {
                RecentActivityList(transactions: viewModel.recentTransactions, currency: currency)
            }
        default:
            EmptyView()
        }
    }

    private var helpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                helpIntroCard

                ForEach(helpGroups) { group in
                    helpGroupView(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle(viewModel.loc("Help"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Done")) { showHelp = false }
            }
        }
    }

    private var helpIntroCard: some View {
        HStack(alignment: .top, spacing: 14) {
            PennyLetIconTile(symbol: "questionmark.circle.fill", tint: viewModel.primaryColor, size: 42, shape: .circle, isProminent: true)

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.loc("Quick answers"))
                    .font(.title3.weight(.bold))
                Text(viewModel.loc("Start with what you have. PennyLet explains what is safe."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var helpGroups: [HelpFAQGroup] {
        [
            HelpFAQGroup(
                id: "start",
                title: viewModel.loc("Start here"),
                items: [
                    HelpFAQItem(
                        id: "start_today",
                        icon: "figure.walk.circle.fill",
                        title: viewModel.loc("Start From Today"),
                        body: helpBody(
                            "No old bank data needed. Enter what you have now and what must happen before payday.",
                            key: "help_start_from_today"
                        )
                    ),
                    HelpFAQItem(
                        id: "old_history",
                        icon: "clock.badge.checkmark.fill",
                        title: viewModel.loc("No old history required"),
                        body: helpBody(
                            "PennyLet gets useful from today's snapshot. CSV import is optional, not required.",
                            key: "help_no_old_history"
                        )
                    ),
                    HelpFAQItem(
                        id: "safe_daily",
                        icon: "shield.checkered",
                        title: viewModel.loc("Safe to Spend Today"),
                        body: helpBody(
                            "Money you can use after bills, goals, and planned costs.",
                            key: "help_safe_daily"
                        )
                    ),
                    HelpFAQItem(
                        id: "balance",
                        icon: "dollarsign.circle.fill",
                        title: viewModel.loc("Balance"),
                        body: helpBody(
                            "Money in − money out this month. A quick pulse check.",
                            key: "help_balance"
                        )
                    )
                ]
            ),
            HelpFAQGroup(
                id: "money_logic",
                title: viewModel.loc("Money logic"),
                items: [
                    HelpFAQItem(
                        id: "safe_logic",
                        icon: "calendar.badge.clock",
                        title: viewModel.loc("How Safe to Spend is calculated"),
                        body: helpBody(
                            "Money you have − bills − goals − known costs.",
                            key: "help_safe_to_spend_logic"
                        )
                    ),
                    HelpFAQItem(
                        id: "transfers",
                        icon: "arrow.left.arrow.right.circle.fill",
                        title: viewModel.loc("Transfers and credit cards"),
                        body: helpBody(
                            "Moving money is not spending. Card payments are transfers.",
                            key: "help_transfers_credit_cards"
                        )
                    ),
                    HelpFAQItem(
                        id: "refunds",
                        icon: "arrow.uturn.backward.circle.fill",
                        title: viewModel.loc("Refunds and reimbursements"),
                        body: helpBody(
                            "Refunds lower the original purchase when possible, so income stays realistic.",
                            key: "help_refunds_reimbursements"
                        )
                    )
                ]
            ),
            HelpFAQGroup(
                id: "tools",
                title: viewModel.loc("Tools"),
                items: [
                    HelpFAQItem(
                        id: "review",
                        icon: "checklist.checked",
                        title: viewModel.loc("Review suggestions"),
                        body: helpBody(
                            "When PennyLet is unsure, it asks you to check instead of guessing.",
                            key: "help_review_suggestions"
                        )
                    ),
                    HelpFAQItem(
                        id: "watchlists",
                        icon: "eye.circle.fill",
                        title: viewModel.loc("Watchlists"),
                        body: helpBody(
                            "Keep an eye on coffee, dining, Amazon, games, or transit.",
                            key: "help_watchlists"
                        )
                    ),
                    HelpFAQItem(
                        id: "categories",
                        icon: "chart.pie.fill",
                        title: viewModel.loc("Top Categories"),
                        body: helpBody(
                            "See where money went this month.",
                            key: "help_categories"
                        )
                    ),
                    HelpFAQItem(
                        id: "goals",
                        icon: "target",
                        title: viewModel.loc("Savings goals"),
                        body: helpBody(
                            "Track saving progress and add money quickly from Goals.",
                            key: "help_goals"
                        )
                    ),
                    HelpFAQItem(
                        id: "subscriptions",
                        icon: "creditcard.fill",
                        title: viewModel.loc("Subscriptions"),
                        body: helpBody(
                            "Add, scan, or review likely subscriptions.",
                            key: "help_subscriptions"
                        )
                    ),
                    HelpFAQItem(
                        id: "ai",
                        icon: "sparkles",
                        title: viewModel.loc("AI Analysis"),
                        body: helpBody(
                            "Short spending notes, with local fallback if AI is slow.",
                            key: "help_ai"
                        )
                    )
                ]
            ),
            HelpFAQGroup(
                id: "personal",
                title: viewModel.loc("Personalization & privacy"),
                items: [
                    HelpFAQItem(
                        id: "wallpaper",
                        icon: "photo.on.rectangle.angled",
                        title: viewModel.loc("Wallpaper Theme"),
                        body: helpBody(
                            "Crop a photo, choose colors, and save different looks.",
                            key: "help_wallpaper"
                        )
                    ),
                    HelpFAQItem(
                        id: "privacy",
                        icon: "lock.fill",
                        title: viewModel.loc("Local data only"),
                        body: helpBody(
                            "No bank login. No cloud account. Export only when you choose.",
                            key: "help_local_privacy"
                        )
                    ),
                    HelpFAQItem(
                        id: "ai_scope",
                        icon: "sparkles.rectangle.stack.fill",
                        title: viewModel.loc("What AI can use"),
                        body: helpBody(
                            "AI only receives the local summary PennyLet prepares from saved app data. If online AI is slow, PennyLet uses local math instead.",
                            key: "help_ai_scope"
                        )
                    ),
                    HelpFAQItem(
                        id: "data_gaps",
                        icon: "doc.text.magnifyingglass",
                        title: viewModel.loc("When data is missing"),
                        body: helpBody(
                            "PennyLet does not pretend missing history exists. It shows what it knows and keeps the answer based on saved data.",
                            key: "help_data_gaps"
                        )
                    )
                ]
            )
        ]
    }

    private func helpGroupView(_ group: HelpFAQGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    helpFAQRow(item)
                    if index < group.items.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.12), lineWidth: 1)
            }
        }
    }

    private func helpFAQRow(_ item: HelpFAQItem) -> some View {
        let isExpanded = expandedHelpItemIDs.contains(item.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.24, extraBounce: 0.02)) {
                    if isExpanded {
                        expandedHelpItemIDs.remove(item.id)
                    } else {
                        expandedHelpItemIDs.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.primaryColor)
                        .frame(width: 28, height: 28)
                        .background(viewModel.primaryColor.opacity(0.10), in: Circle())

                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(viewModel.loc(isExpanded ? "Tap to hide answer" : "Tap to show answer"))

            if isExpanded {
                Text(item.body)
                    .font(.subheadline)
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 54)
                    .padding(.trailing, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func helpBody(_ english: String, key: String) -> String {
        viewModel.language == "en" ? english : viewModel.loc(key)
    }
}

private enum DashboardSheet: String, Identifiable {
    case todaySnapshot
    case reviewQueue
    case watchlists

    var id: String { rawValue }
}

private enum ReviewQueueGroupKind: String, CaseIterable, Identifiable {
    case transfers
    case refunds
    case recurring
    case categories

    var id: String { rawValue }

    func contains(_ item: MoneyLogicV2ReviewItem) -> Bool {
        switch self {
        case .transfers:
            return item.kind == .possibleTransfer
        case .refunds:
            return item.kind == .possibleRefund
        case .recurring:
            return item.kind == .possibleRecurring
        case .categories:
            return item.kind == .uncategorized || item.kind == .suggestedCategory
        }
    }

    @MainActor
    func title(in viewModel: AppViewModel) -> String {
        switch self {
        case .transfers:
            return viewModel.loc("Possible Transfers")
        case .refunds:
            return viewModel.loc("Refunds & Reimbursements")
        case .recurring:
            return viewModel.loc("Recurring Items")
        case .categories:
            return viewModel.loc("Needs Category")
        }
    }

    @MainActor
    func detail(in viewModel: AppViewModel) -> String {
        switch self {
        case .transfers:
            return viewModel.loc("Confirm money you moved so it does not count as spending.")
        case .refunds:
            return viewModel.loc("Link money returned to the original purchase.")
        case .recurring:
            return viewModel.loc("Track repeated bills or subscriptions only after you confirm them.")
        case .categories:
            return viewModel.loc("These entries need a category before reports are fully trusted.")
        }
    }

    var icon: String {
        switch self {
        case .transfers:
            return "arrow.left.arrow.right"
        case .refunds:
            return "arrow.uturn.backward"
        case .recurring:
            return "repeat"
        case .categories:
            return "tag"
        }
    }

    @MainActor
    func tint(in viewModel: AppViewModel) -> Color {
        switch self {
        case .transfers:
            return viewModel.primaryColor
        case .refunds:
            return Color(.systemGreen)
        case .recurring:
            return Color(.systemPurple)
        case .categories:
            return Color(.systemOrange)
        }
    }
}

private struct DashboardReviewQueueCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let items: [MoneyLogicV2ReviewItem]
    let onOpen: () -> Void

    private var nonEmptyGroups: [(kind: ReviewQueueGroupKind, count: Int)] {
        ReviewQueueGroupKind.allCases.compactMap { kind in
            let count = items.filter(kind.contains).count
            return count > 0 ? (kind, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PennyLetIconTile(symbol: "checklist.checked", tint: Color(.systemOrange), size: 36, symbolScale: 0.42, shape: .diamond)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.loc("Quick checks"))
                        .font(.headline.weight(.bold))
                    Text(viewModel.loc("Confirm only what looks right. Ignore the rest."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Haptics.selection()
                    onOpen()
                } label: {
                    Text(viewModel.loc("Check now"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.systemOrange))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color(.systemOrange).opacity(0.10), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(nonEmptyGroups, id: \.kind) { group in
                    let tint = group.kind.tint(in: viewModel)
                    HStack(spacing: 8) {
                        Image(systemName: group.kind.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                            .frame(width: 24, height: 24)
                            .background(tint.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(group.count)")
                                .font(.headline.weight(.bold).monospacedDigit())
                            Text(group.kind.title(in: viewModel))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.66)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(18)
        .premiumPanel(tint: Color(.systemOrange))
    }
}

private struct DashboardWatchlistsCard: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var watchlistPendingDelete: String?
    let watchlists: [MoneyLogicV2WatchlistSummary]
    let currency: String
    let onManage: () -> Void

    private let starterWatchlists = ["Coffee", "Dining", "Games", "Transport", "Shopping"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PennyLetIconTile(symbol: "eye.circle.fill", tint: Color(.systemTeal), size: 36, symbolScale: 0.42, shape: .capsule)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.loc("Watchlists"))
                        .font(.headline.weight(.bold))
                    Text(viewModel.loc("Track spending you care about."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Haptics.selection()
                    onManage()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.systemTeal))
                        .frame(width: 30, height: 30)
                        .background(Color(.systemTeal).opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.loc("Manage watchlists"))
            }

            if watchlists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.loc("Track one habit without building a full budget."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(starterWatchlists, id: \.self) { name in
                            Button {
                                Haptics.selection()
                                viewModel.addCustomWatchlist(name)
                            } label: {
                                Text(viewModel.loc(name))
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemTeal).opacity(0.10), in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(watchlists.prefix(5)) { summary in
                        HStack(spacing: 10) {
                            Text(viewModel.loc(summary.watchlist.name))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(CurrencyFormat.format(summary.spentThisMonth, currency: currency))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .currencyAmountDisplay(minScale: 0.58)
                                Text("\(summary.transactionCount) \(viewModel.loc("entries"))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                Haptics.selection()
                                watchlistPendingDelete = summary.watchlist.name
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(.systemRed))
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemRed).opacity(0.10), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(viewModel.loc("Delete"))
                        }
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .premiumPanel(tint: Color(.systemTeal))
        .confirmationDialog(
            viewModel.loc("Delete watchlist?"),
            isPresented: Binding(
                get: { watchlistPendingDelete != nil },
                set: { if !$0 { watchlistPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(viewModel.loc("Delete"), role: .destructive) {
                if let name = watchlistPendingDelete {
                    viewModel.deleteCustomWatchlist(name)
                }
                watchlistPendingDelete = nil
            }
            Button(viewModel.loc("Cancel"), role: .cancel) {
                watchlistPendingDelete = nil
            }
        } message: {
            Text(viewModel.loc("This removes it from Home. Your transactions stay saved."))
        }
    }
}

private struct TodaySnapshotEditorSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var spendableBalance = ""
    @State private var cashOnHand = ""
    @State private var keepUntouched = ""
    @State private var billsBeforePayday = ""
    @State private var saveBeforePayday = ""
    @State private var nextPaycheckAmount = ""
    @State private var nextPayday = Date()
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro

                VStack(spacing: 12) {
                    moneyField(
                        viewModel.loc("Spendable balance today"),
                        detail: viewModel.loc("Money in your bank/checking today."),
                        text: $spendableBalance,
                        icon: "banknote"
                    )
                    moneyField(
                        viewModel.loc("Cash in pocket"),
                        detail: viewModel.loc("Cash you want PennyLet to count."),
                        text: $cashOnHand,
                        icon: "wallet.pass"
                    )
                    moneyField(
                        viewModel.loc("Keep untouched"),
                        detail: viewModel.loc("Savings or buffer money to protect."),
                        text: $keepUntouched,
                        icon: "lock"
                    )
                    moneyField(
                        viewModel.loc("Bills before payday"),
                        detail: viewModel.loc("Bills due before your next paycheck."),
                        text: $billsBeforePayday,
                        icon: "calendar.badge.clock"
                    )
                    moneyField(
                        viewModel.loc("Save before payday"),
                        detail: viewModel.loc("Money to set aside before payday."),
                        text: $saveBeforePayday,
                        icon: "target"
                    )
                    moneyField(
                        viewModel.loc("Next paycheck amount"),
                        detail: viewModel.loc("Income expected on payday."),
                        text: $nextPaycheckAmount,
                        icon: "arrow.down.circle"
                    )

                    DatePicker(
                        viewModel.loc("Next payday"),
                        selection: $nextPayday,
                        displayedComponents: .date
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let summary = viewModel.startFromTodaySummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.loc("Preview"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormat.format(summary.trueSafeToSpend, currency: viewModel.currency))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(summary.trueSafeToSpend < 0 ? Color(.systemRed) : viewModel.primaryColor)
                            .currencyAmountDisplay(minScale: 0.58)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumPanel(tint: viewModel.primaryColor)
                }
            }
            .padding(20)
        }
        .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
        .navigationTitle(viewModel.loc("Today Snapshot"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(viewModel.loc("Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Save")) {
                    save()
                }
                .font(.body.weight(.semibold))
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Update today's money."))
                .font(.title3.weight(.bold))
            Text(viewModel.loc("No old bank history needed."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private func moneyField(_ title: String, detail: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(viewModel.primaryColor.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Text(currencyInputLabel)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var currencyInputLabel: String {
        CurrencyFormat.currencySymbol(for: viewModel.currency)
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        let budget = viewModel.currentBudget
        spendableBalance = amountText(budget?.currentSpendableBalance ?? 0)
        cashOnHand = amountText(budget?.cashOnHand ?? 0)
        keepUntouched = amountText(budget?.moneyToKeepUntouched ?? 0)
        billsBeforePayday = amountText(budget?.billsDueBeforeNextIncome ?? 0)
        saveBeforePayday = amountText(budget?.savingsDueBeforeNextIncome ?? 0)
        nextPaycheckAmount = amountText(budget?.nextIncomeAmount ?? budget?.monthlyIncome ?? 0)
        nextPayday = viewModel.startFromTodaySummary?.nextIncomeDate ?? Date()
    }

    private func save() {
        viewModel.updateTodaySnapshot(
            currentSpendableBalance: CurrencyFormat.parseInput(spendableBalance) ?? 0,
            cashOnHand: CurrencyFormat.parseInput(cashOnHand) ?? 0,
            moneyToKeepUntouched: CurrencyFormat.parseInput(keepUntouched) ?? 0,
            billsDueBeforeNextIncome: CurrencyFormat.parseInput(billsBeforePayday) ?? 0,
            savingsDueBeforeNextIncome: CurrencyFormat.parseInput(saveBeforePayday) ?? 0,
            nextIncomeDate: nextPayday,
            nextIncomeAmount: CurrencyFormat.parseInput(nextPaycheckAmount)
        )
        Haptics.success()
        dismiss()
    }

    private func amountText(_ amount: Double) -> String {
        amount == 0 ? "" : String(format: "%.2f", amount)
    }
}

private struct ReviewQueueDetailSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedGroups: Set<ReviewQueueGroupKind> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.reviewQueue.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.loc("Nothing needs review right now."))
                            .font(.headline.weight(.semibold))
                        Text(viewModel.loc("PennyLet will ask again when new local data needs a decision."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .premiumPanel(tint: viewModel.primaryColor)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.loc("Review Queue"))
                            .font(.title2.weight(.bold))
                        Text(viewModel.loc("Check the few items PennyLet should not guess."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .premiumPanel(tint: viewModel.primaryColor)

                    ForEach(groupedItems, id: \.kind) { group in
                        reviewGroupCard(kind: group.kind, groupItems: group.items)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
        .navigationTitle(viewModel.loc("Review Queue"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Done")) { dismiss() }
            }
        }
    }

    private var groupedItems: [(kind: ReviewQueueGroupKind, items: [MoneyLogicV2ReviewItem])] {
        ReviewQueueGroupKind.allCases.compactMap { kind in
            let groupItems = viewModel.reviewQueue.filter(kind.contains)
            return groupItems.isEmpty ? nil : (kind, groupItems)
        }
    }

    private func reviewGroupCard(kind: ReviewQueueGroupKind, groupItems: [MoneyLogicV2ReviewItem]) -> some View {
        let isExpanded = expandedGroups.contains(kind)
        let visibleItems = isExpanded ? groupItems : Array(groupItems.prefix(4))
        let tint = kind.tint(in: viewModel)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PennyLetIconTile(symbol: kind.icon, tint: tint, size: 36, symbolScale: 0.42, shape: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(kind.title(in: viewModel))
                            .font(.headline.weight(.bold))
                        Text("\(groupItems.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
                    }
                    Text(kind.detail(in: viewModel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(visibleItems) { item in
                    reviewItemRow(item, tint: tint)
                }
            }

            if groupItems.count > visibleItems.count {
                Button {
                    Haptics.selection()
                    withAnimation(AnimationPresets.fold) {
                        _ = expandedGroups.insert(kind)
                    }
                } label: {
                    Label(viewModel.loc("Show all"), systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if groupItems.count > 4, isExpanded {
                Button {
                    Haptics.selection()
                    withAnimation(AnimationPresets.fold) {
                        _ = expandedGroups.remove(kind)
                    }
                } label: {
                    Label(viewModel.loc("Show less"), systemImage: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .premiumPanel(tint: tint)
    }

    private func reviewItemRow(_ item: MoneyLogicV2ReviewItem, tint: Color) -> some View {
        let reviewTransactions = transactions(for: item)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reviewTitle(for: item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if shouldShowTextDetail(for: item) {
                        Text(reviewDetail(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Text(viewModel.loc(confidenceLabel(item.confidence)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.10), in: Capsule(style: .continuous))
            }

            if shouldShowTransactionChips(for: item), !reviewTransactions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(reviewTransactions.prefix(2)) { transaction in
                        reviewTransactionChip(transaction, tint: tint)
                    }
                }
            }

            HStack(spacing: 8) {
                if let action = primaryAction(for: item) {
                    Button {
                        Haptics.selection()
                        performPrimaryAction(for: item)
                    } label: {
                        Text(action)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Haptics.selection()
                    viewModel.dismissReviewItem(item)
                } label: {
                    Text(viewModel.loc("Ignore"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reviewTransactionChip(_ transaction: Transaction, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(CurrencyFormat.formatSigned(transaction.signedAmount, currency: viewModel.currency))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(transaction.signedAmount < 0 ? Color(.systemRed) : Color(.systemGreen))
                .frame(minWidth: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(transactionName(transaction))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text("\(transaction.dateValue.map(shortDate) ?? transaction.date) • \(transaction.category ?? viewModel.loc("Uncategorized"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func shouldShowTransactionChips(for item: MoneyLogicV2ReviewItem) -> Bool {
        item.kind == .possibleTransfer || item.kind == .possibleRefund
    }

    private func shouldShowTextDetail(for item: MoneyLogicV2ReviewItem) -> Bool {
        !shouldShowTransactionChips(for: item)
    }

    private func primaryAction(for item: MoneyLogicV2ReviewItem) -> String? {
        switch item.kind {
        case .possibleTransfer:
            return viewModel.loc("Accept Transfer")
        case .possibleRefund:
            return viewModel.loc("Accept Refund")
        case .possibleRecurring:
            return viewModel.loc("Track Recurring")
        case .uncategorized, .suggestedCategory:
            return nil
        }
    }

    private func performPrimaryAction(for item: MoneyLogicV2ReviewItem) {
        switch item.kind {
        case .possibleTransfer:
            viewModel.acceptReviewTransfer(item)
        case .possibleRefund:
            viewModel.acceptReviewRefund(item)
        case .possibleRecurring:
            viewModel.acceptReviewRecurring(item)
        case .uncategorized, .suggestedCategory:
            break
        }
    }

    private func confidenceLabel(_ confidence: MoneyLogicV2CategorizationConfidence) -> String {
        switch confidence {
        case .userConfirmed:
            return "User confirmed"
        case .rule:
            return "Rule match"
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        case .unknown:
            return "Unknown confidence"
        }
    }

    private func reviewTitle(for item: MoneyLogicV2ReviewItem) -> String {
        switch item.kind {
        case .uncategorized:
            return primaryTransactionName(for: item) ?? viewModel.loc("Needs category")
        case .suggestedCategory:
            return primaryTransactionName(for: item) ?? viewModel.loc("Suggested category")
        case .possibleTransfer:
            return item.title == "Possible credit card payment" ? viewModel.loc("Possible credit card payment") : viewModel.loc("Possible transfer")
        case .possibleRefund:
            return item.title == "Possible reimbursement" ? viewModel.loc("Possible reimbursement") : viewModel.loc("Possible refund")
        case .possibleRecurring:
            return recurringDisplay(for: item) ?? recurringDisplayName(from: item) ?? viewModel.loc("Recurring item")
        }
    }

    private func reviewDetail(for item: MoneyLogicV2ReviewItem) -> String {
        switch item.kind {
        case .uncategorized, .suggestedCategory:
            return concreteTransactionLines(for: item).first ?? item.detail
        case .possibleTransfer:
            return viewModel.loc("Same amount on nearby dates. Transfers are not counted as spending.")
        case .possibleRefund:
            return viewModel.loc("This can reduce the original expense instead of inflating income.")
        case .possibleRecurring:
            if let display = viewModel.recurringReviewDisplay(for: item) {
                let amount = CurrencyFormat.format(display.amount, currency: viewModel.currency)
                return "\(amount) • \(viewModel.loc(display.cadence.rawValue)) • \(viewModel.loc("Confirm before tracking."))"
            }
            return viewModel.loc("Confirm before tracking.")
        }
    }

    private func primaryTransactionName(for item: MoneyLogicV2ReviewItem) -> String? {
        transactions(for: item).first.map(transactionName)
    }

    private func concreteTransactionLines(for item: MoneyLogicV2ReviewItem) -> [String] {
        transactions(for: item).map { transaction in
            let amount = CurrencyFormat.formatSigned(transaction.signedAmount, currency: viewModel.currency)
            let date = transaction.dateValue.map(shortDate) ?? transaction.date
            let category = transaction.category ?? viewModel.loc("Uncategorized")
            return "\(amount) • \(transactionName(transaction)) • \(date) • \(category)"
        }
    }

    private func recurringDisplay(for item: MoneyLogicV2ReviewItem) -> String? {
        viewModel.recurringReviewDisplay(for: item)?.name
    }

    private func transactions(for item: MoneyLogicV2ReviewItem) -> [Transaction] {
        item.transactionIds.compactMap { id in
            viewModel.transactions.first { $0.id == id }
        }
    }

    private func transactionName(_ transaction: Transaction) -> String {
        if let merchant = transaction.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !merchant.isEmpty {
            return merchant
        }
        if let description = transaction.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        if let note = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        return viewModel.loc("Transaction")
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func recurringDisplayName(from item: MoneyLogicV2ReviewItem) -> String? {
        let marker = " looks "
        guard let range = item.detail.range(of: marker) else { return nil }
        let name = String(item.detail[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

private struct WatchlistEditorSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newWatchlist = ""
    @State private var watchlistPendingDelete: String?
    private let starterWatchlists = ["Coffee", "Dining", "Games", "Transport", "Shopping"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.loc("Choose what to watch."))
                        .font(.title3.weight(.bold))
                    Text(viewModel.loc("Track a merchant or category without building a full budget."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .premiumPanel(tint: Color(.systemTeal))

                HStack(spacing: 10) {
                    TextField(viewModel.loc("Watchlist name"), text: $newWatchlist)
                        .textInputAutocapitalization(.words)
                        .font(.body.weight(.semibold))
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        Haptics.selection()
                        viewModel.addCustomWatchlist(newWatchlist)
                        newWatchlist = ""
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .premiumActionFill(tint: Color(.systemTeal))
                    }
                    .buttonStyle(.plain)
                    .disabled(newWatchlist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.loc("Start with one thing"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(starterWatchlists, id: \.self) { name in
                            Button {
                                Haptics.selection()
                                viewModel.addCustomWatchlist(name)
                            } label: {
                                Text(viewModel.loc(name))
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(Color(.systemTeal).opacity(0.10), in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.loc("Saved watchlists"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    if viewModel.customWatchlists.isEmpty {
                        Text(viewModel.loc("No custom watchlists yet."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.customWatchlists, id: \.self) { name in
                                HStack {
                                    Text(viewModel.loc(name))
                                        .font(.body.weight(.semibold))
                                    Spacer()
                                    Button {
                                        Haptics.selection()
                                        watchlistPendingDelete = name
                                    } label: {
                                        Label(viewModel.loc("Delete"), systemImage: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color(.systemRed))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Color(.systemRed).opacity(0.10), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
        .navigationTitle(viewModel.loc("Watchlists"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Done")) { dismiss() }
            }
        }
        .confirmationDialog(
            viewModel.loc("Delete watchlist?"),
            isPresented: Binding(
                get: { watchlistPendingDelete != nil },
                set: { if !$0 { watchlistPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(viewModel.loc("Delete"), role: .destructive) {
                if let name = watchlistPendingDelete {
                    viewModel.deleteCustomWatchlist(name)
                }
                watchlistPendingDelete = nil
            }
            Button(viewModel.loc("Cancel"), role: .cancel) {
                watchlistPendingDelete = nil
            }
        } message: {
            Text(viewModel.loc("This removes it from Home. Your transactions stay saved."))
        }
    }
}

private struct HelpFAQGroup: Identifiable {
    let id: String
    let title: String
    let items: [HelpFAQItem]
}

private struct HelpFAQItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let body: String
}

private struct QuietDashboardStartCard: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                PennyLetIconTile(symbol: "sparkles", tint: viewModel.primaryColor, size: 42, shape: .circle, isProminent: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.loc("Ready from today"))
                        .font(.title3.weight(.bold))
                    Text(viewModel.loc("Add your first entry when money moves. Past bank history can wait."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                startChip(viewModel.loc("No bank login"))
                startChip(viewModel.loc("Old data optional"))
                startChip(viewModel.loc("Local first"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private func startChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(viewModel.primaryColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(viewModel.primaryColor.opacity(0.10), in: Capsule(style: .continuous))
    }
}
