import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showUpgrade = false
    @State private var fabScale: CGFloat = 1
    @State private var homePath = NavigationPath()
    @State private var activityPath = NavigationPath()
    @State private var goalsPath = NavigationPath()
    @State private var aiPath = NavigationPath()
    @State private var morePath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $homePath) {
                    DashboardView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.homeTab, systemImage: "house.fill") }
                .tag(0)

                NavigationStack(path: $activityPath) {
                    TransactionListView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.activityTab, systemImage: "list.bullet") }
                .tag(1)

                NavigationStack(path: $goalsPath) {
                    GoalsView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.goalsTab, systemImage: "target") }
                .tag(2)

                NavigationStack(path: $aiPath) {
                    AIFeaturesView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.aiTab, systemImage: "sparkles") }
                .tag(3)

                NavigationStack(path: $morePath) {
                    MoreView()
                        .toolbar { settingsButton }
                        .navigationDestination(for: MoreRoute.self) { route in
                            switch route {
                            case .subscriptions:
                                SubscriptionTrackerView()
                            case .budgetHealth:
                                BudgetHealthView()
                            }
                        }
                }
                .tabItem { Label(viewModel.moreTab, systemImage: "ellipsis.circle.fill") }
                .tag(4)
            }
            .id(viewModel.language)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue != newValue {
                    Haptics.selection()
                }
            }

            if shouldShowAddButton {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        fabScale = 0.85
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                            fabScale = 1
                        }
                        showAddSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background {
                            Circle()
                                .fill(viewModel.theme.primaryColor)
                        }
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: viewModel.theme.primaryColor.opacity(0.35), radius: 18, y: 8)
                        .scaleEffect(fabScale)
                        .rotationEffect(.degrees(fabScale < 1 ? 10 : 0))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 90)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
                .accessibilityLabel(viewModel.addTransactionTitle)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: shouldShowAddButton)
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAITab)) { notif in
            selectedTab = 3
            // Pass sub-tab type via viewModel
            if let type = notif.object as? String {
                switch type {
                case "weekly": viewModel.initialAISubTab = 1
                case "monthly": viewModel.initialAISubTab = 2
                default: viewModel.initialAISubTab = 0
                }
            }
        }
        .onChange(of: viewModel.navigateToTab) { _, new in
            if let tab = new { selectedTab = min(tab, 4) }
        }
        .onChange(of: viewModel.isPro) { _, _ in }
    }

    private var shouldShowAddButton: Bool {
        switch selectedTab {
        case 0:
            return homePath.count == 0
        case 1:
            return activityPath.count == 0
        case 2:
            return goalsPath.count == 0
        case 3:
            return aiPath.count == 0
        case 4:
            return morePath.count == 0
        default:
            return true
        }
    }

    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 10) {
                if !viewModel.isPro {
                    Button {
                        Haptics.selection()
                        showUpgrade = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(.systemYellow))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.upgradeToProLabel)
                }

                Button {
                    Haptics.selection()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.settingsTitle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private enum MoreRoute: Hashable {
    case subscriptions
    case budgetHealth
}

private struct MoreView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isBlockVisible(.moreOverview) {
                    MoreHeaderCard()
                }

                VStack(spacing: 12) {
                    NavigationLink(value: MoreRoute.subscriptions) {
                        MoreDestinationCard(
                            icon: "creditcard.fill",
                            title: viewModel.loc("Subscriptions"),
                            tint: Color(.systemTeal),
                            metric: "\(viewModel.recurringSubscriptions.filter(\.isActive).count)",
                            shape: .circle
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: MoreRoute.budgetHealth) {
                        MoreDestinationCard(
                            icon: "heart.fill",
                            title: viewModel.loc("Budget Health"),
                            tint: Color(.systemPink),
                            metric: "\(Int(viewModel.spendSummary.spendPercent))%",
                            shape: .diamond
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .navigationTitle(viewModel.moreTab)
        .clearSpendScreenBackground(theme: viewModel.theme)
    }
}

private struct MoreHeaderCard: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.loc("Money cockpit"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 42, shape: .circle)
            }

            HStack(spacing: 10) {
                MiniMoreStat(
                    title: viewModel.loc("Safe today"),
                    value: CurrencyFormat.format(viewModel.spendSummary.safeDaily, currency: viewModel.currency)
                )
                MiniMoreStat(
                    title: viewModel.loc("Tracked subs"),
                    value: "\(viewModel.recurringSubscriptions.filter(\.isActive).count)"
                )
            }
        }
        .padding(22)
        .premiumPanel(tint: viewModel.theme.primaryColor)
    }
}

private struct MiniMoreStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .currencyAmountDisplay(minScale: 0.56)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MoreDestinationCard: View {
    let icon: String
    let title: String
    let tint: Color
    let metric: String
    var shape: PennyLetIconShape = .roundedSquare

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PennyLetIconTile(symbol: icon, tint: tint, size: 54, symbolScale: 0.42, shape: shape, isProminent: true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(spacing: 5) {
                Text(metric)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }
}
