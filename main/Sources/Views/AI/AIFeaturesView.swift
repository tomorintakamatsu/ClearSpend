import SwiftUI
import Charts

struct AIFeaturesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab = 0
    @State private var tabLoading: [Bool] = [false, false, false, false]
    @State private var tabErrors: [String?] = [nil, nil, nil, nil]
    @State private var tabProgressPhases: [AppViewModel.AIProgressPhase] = [.collectingData, .collectingData, .collectingData, .collectingData]
    @State private var showsHistory = false

    private var tabResults: [AppViewModel.AIResult?] {
        [viewModel.currentDailyResult, viewModel.currentWeeklyResult, viewModel.currentMonthlyResult, viewModel.currentForecastResult]
    }
    @State private var showUpgradeSheet = false
    @State private var showUsageAlert = false
    @State private var selectedHistoryItem: AnalysisHistory?

    private var tabLabels: [String] {
        var tabs = [viewModel.dailyTabLabel, viewModel.weeklyTabLabel, viewModel.monthlyTabLabel]
        if viewModel.isPro { tabs.append(viewModel.loc("Forecast")) }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isBlockVisible(.aiIntro) {
                aiHeaderCard
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }

            Picker(viewModel.loc("Analysis"), selection: $selectedTab) {
                ForEach(tabLabels.indices, id: \.self) { i in
                    Text(tabLabels[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue != newValue {
                    Haptics.selection()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            TabView(selection: $selectedTab) {
                dailyTab.tag(0)
                weeklyTab.tag(1)
                monthlyTab.tag(2)
                if viewModel.isPro { forecastTab.tag(3) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle(viewModel.aiInsightsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let sub = viewModel.initialAISubTab {
                selectedTab = sub
                viewModel.initialAISubTab = nil
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
        .alert(viewModel.usageExhaustedProTitle, isPresented: $showUsageAlert) {
            Button(viewModel.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.usageExhaustedProMessage)
        }
        .sheet(item: $selectedHistoryItem) { item in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let date = item.analysisDate ?? item.createdDate {
                            Text(formatDate(date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(viewModel.primaryColor)
                        }
                        Text(item.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.isPro {
                            let charts = viewModel.chartsForHistory(item)
                            if !charts.category.isEmpty {
                                categoryChartView(charts.category)
                            }
                            if !charts.daily.isEmpty {
                                dailyChartView(charts.daily)
                            }
                        }
                    }
                    .padding(20)
                }
                .navigationTitle(viewModel.resultLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            Task {
                                let id = item.id
                                selectedHistoryItem = nil
                                await viewModel.deleteAnalysisHistoryById(id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(viewModel.clearLabel) { selectedHistoryItem = nil }
                    }
                }
            }
        }
    }

    // MARK: - Daily Tab

    private var aiHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 44, shape: .circle, isProminent: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.loc("PennyLet Intelligence"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var dailyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isBlockVisible(.aiUsage) {
                    usageBadge(feature: "daily")
                }

                if tabLoading[0] {
                    loadingView(for: 0)
                } else if let result = tabResults[0] {
                    resultView(result, tab: 0)
                } else if !viewModel.canUseFeature("daily") {
                    exhaustedView
                } else {
                    emptyView(
                        title: viewModel.dailyAnalysisTitle,
                        feature: "daily",
                        tab: 0
                    ) {
                        await generate(for: 0) { progress in try await viewModel.generateDailyAnalysis(progress: progress) }
                    }
                }

                if let e = tabErrors[0] {
                    errorView(e)
                }

                if viewModel.isBlockVisible(.aiHistory) {
                    historySection(type: "daily")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Weekly Tab

    private var weeklyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isBlockVisible(.aiUsage) {
                    usageBadge(feature: "recap")
                }

                if tabLoading[1] {
                    loadingView(for: 1)
                } else if let result = tabResults[1] {
                    resultView(result, tab: 1)
                } else if !viewModel.canUseFeature("recap") {
                    exhaustedView
                } else {
                    emptyView(
                        title: viewModel.weeklyRecapTitle,
                        feature: "recap",
                        tab: 1
                    ) {
                        await generate(for: 1) { progress in try await viewModel.generateWeeklyAnalysis(progress: progress) }
                    }
                }

                if let e = tabErrors[1] {
                    errorView(e)
                }

                if viewModel.isBlockVisible(.aiHistory) {
                    historySection(type: "weekly")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Monthly Tab

    private var monthlyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.canUseFeature("insight") == false && !viewModel.isPro {
                    upgradePrompt
                } else {
                    if viewModel.isBlockVisible(.aiUsage) {
                        usageBadge(feature: "insight")
                    }

                    if tabLoading[2] {
                        loadingView(for: 2)
                    } else if let result = tabResults[2] {
                        resultView(result, tab: 2)
                    } else if !viewModel.canUseFeature("insight") {
                        exhaustedView
                    } else {
                        emptyView(
                            title: viewModel.monthlyInsightTitle,
                            feature: "insight",
                            tab: 2
                        ) {
                            await generate(for: 2) { progress in try await viewModel.generateMonthlyAnalysis(progress: progress) }
                        }
                    }

                    if let e = tabErrors[2] {
                        errorView(e)
                    }

                    if viewModel.isBlockVisible(.aiHistory) {
                        historySection(type: "monthly")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Forecast Tab

    private var forecastTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isBlockVisible(.aiUsage) {
                    usageBadge(feature: "forecast")
                }

                if tabLoading[3] {
                    loadingView(for: 3)
                } else if let result = tabResults[3] {
                    resultView(result, tab: 3)
                } else if !viewModel.canUseFeature("forecast") {
                    exhaustedView
                } else {
                    VStack(spacing: 16) {
                        PennyLetIconTile(symbol: "chart.line.uptrend.xyaxis", tint: viewModel.primaryColor, size: 58, symbolScale: 0.42, shape: .diamond, isProminent: true)
                        Text(viewModel.loc("Spending Forecast"))
                            .font(.title3.weight(.semibold))
                        Button {
                            handleGenerate(feature: "forecast", tab: 3) {
                                await generate(for: 3) { progress in try await viewModel.generateForecast(progress: progress) }
                            }
                        } label: {
                            Label(viewModel.generateLabel, systemImage: "wand.and.stars")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .premiumActionFill(tint: viewModel.primaryColor, followsWallpaperOpacity: false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                if let e = tabErrors[3] {
                    errorView(e)
                }

                if viewModel.isBlockVisible(.aiHistory) {
                    historySection(type: "forecast")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Components

    private func usageBadge(feature: String) -> some View {
        let remaining = viewModel.remainingUses(feature)
        let limit = viewModel.usageLimit(feature)
        let used = limit - remaining
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(viewModel.loc("Usage"), systemImage: remaining > 0 ? "gauge" : "circle.slash")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Text(viewModel.isPro ? "\(used)/\(limit)" : "\(remaining)/\(limit)")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            ProgressView(value: Double(used), total: Double(limit))
                .tint(remaining > 0 ? viewModel.primaryColor : Color.orange)
                .scaleEffect(x: 1, y: 0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(remaining > 0 ? Color.secondary : Color.orange)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var exhaustedView: some View {
        VStack(spacing: 16) {
            PennyLetIconTile(
                symbol: viewModel.isPro ? "hourglass" : "crown.fill",
                tint: viewModel.isPro ? Color(.systemOrange) : Color(.systemYellow),
                size: 58,
                symbolScale: 0.42,
                shape: .circle,
                isProminent: true
            )
            Text(viewModel.isPro
                ? viewModel.loc("Monthly Limit Reached")
                : viewModel.loc("Free Uses Exhausted"))
                .font(.title3.weight(.semibold))
            Text(viewModel.isPro
                ? viewModel.loc("Your usage refreshes next month.")
                : viewModel.loc("Upgrade for more AI analyses."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !viewModel.isPro {
                Button {
                    showUpgradeOrGuestPrompt()
                } label: {
                    Text(viewModel.upgradeToProLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func loadingView(for tab: Int) -> some View {
        let phase = progressPhase(for: tab)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 42, shape: .circle, isProminent: true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(progressTitle(for: tab))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.primaryColor)
                    Text(viewModel.loc(progressPhaseTitleKey(for: phase, tab: tab)))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(viewModel.loc(progressPhaseDetailKey(for: phase)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentTransition(.opacity)

                Spacer()
            }

            aiProgressTrack(for: phase)

            HStack {
                Text(progressStepText(for: phase))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumPanel(tint: viewModel.primaryColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progressTitle(for: tab)), \(progressStepText(for: phase))")
        .accessibilityValue("\(viewModel.loc(progressPhaseTitleKey(for: phase, tab: tab))). \(viewModel.loc(progressPhaseDetailKey(for: phase)))")
    }

    private func aiProgressTrack(for phase: AppViewModel.AIProgressPhase) -> some View {
        let phases = AppViewModel.AIProgressPhase.orderedPhases
        let activeIndex = phases.firstIndex(of: phase) ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(activeIndex + 1), total: Double(phases.count))
                .tint(viewModel.primaryColor)
                .scaleEffect(x: 1, y: 0.75)

            HStack(spacing: 5) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, item in
                    Capsule(style: .continuous)
                        .fill(index <= activeIndex ? viewModel.primaryColor : Color(.quaternaryLabel))
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                        .opacity(index <= activeIndex ? 1 : 0.5)
                        .accessibilityLabel(viewModel.loc(item.messageKey))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.loc("AI progress"))
        .accessibilityValue("\(activeIndex + 1)/\(phases.count)")
    }

    private func resultView(_ r: AppViewModel.AIResult, tab: Int) -> some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 28, symbolScale: 0.43, shape: .circle)
                    Text(viewModel.resultLabel)
                        .font(.headline)
                    Spacer()
                    Button(viewModel.clearLabel) {
                        switch tab {
                        case 0: viewModel.currentDailyResult = nil
                        case 1: viewModel.currentWeeklyResult = nil
                        case 2: viewModel.currentMonthlyResult = nil
                        case 3: viewModel.currentForecastResult = nil
                        default: break
                        }
                    }
                    .font(.caption)
                }
                Text(r.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isPro {
                    if !r.categoryChart.isEmpty {
                        categoryChartView(r.categoryChart)
                    }
                    if !r.dailyChart.isEmpty {
                        dailyChartView(r.dailyChart)
                    }
                }
            }
            .padding(20)
            .premiumPanel(tint: viewModel.primaryColor)

            Button {
                generateAgain(for: tab)
            } label: {
                Label(viewModel.loc("Generate Again"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .premiumActionFill(tint: viewModel.primaryColor, followsWallpaperOpacity: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.loc("Generate Again"))
        }
    }

    // MARK: - Charts (Pro only)

    private let chartColors: [Color] = [
        Color(red: 0.94, green: 0.35, blue: 0.31),
        Color(red: 0.18, green: 0.67, blue: 0.95),
        Color(red: 0.96, green: 0.61, blue: 0.14),
        Color(red: 0.33, green: 0.73, blue: 0.35),
        Color(red: 0.64, green: 0.27, blue: 0.83),
        Color(red: 0.96, green: 0.20, blue: 0.49),
        Color(red: 0.00, green: 0.69, blue: 0.69),
        Color(red: 0.55, green: 0.55, blue: 0.85),
    ]

    private func categoryChartView(_ data: [(name: String, amount: Double)]) -> some View {
        let grouped = groupSmallCategories(data)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                PennyLetIconTile(symbol: "chart.pie.fill", tint: Color(.systemOrange), size: 26, symbolScale: 0.42, shape: .circle)
                Text(viewModel.loc("Category Breakdown"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Chart(grouped, id: \.name) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Category", item.name))
            }
            .chartForegroundStyleScale(
                domain: grouped.map(\.name),
                range: grouped.indices.map { chartColors[$0 % chartColors.count] }
            )
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 220)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func dailyChartView(_ data: [(day: String, amount: Double)]) -> some View {
        let topItems = Array(data.sorted(by: { $0.amount > $1.amount }).prefix(8))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                PennyLetIconTile(symbol: "chart.bar.fill", tint: viewModel.primaryColor, size: 26, symbolScale: 0.42, shape: .capsule)
                Text(viewModel.loc("Weekly Trend"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Chart(topItems, id: \.day) { item in
                BarMark(
                    x: .value("Category", item.day),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(by: .value("Category", item.day))
            }
            .chartForegroundStyleScale(
                domain: topItems.map(\.day),
                range: topItems.indices.map { chartColors[$0 % chartColors.count] }
            )
            .chartLegend(.hidden)
            .frame(height: 200)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func groupSmallCategories(_ data: [(name: String, amount: Double)]) -> [(name: String, amount: Double)] {
        let total = data.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return data }
        var result: [(name: String, amount: Double)] = []
        var otherAmount: Double = 0
        for item in data.sorted(by: { $0.amount > $1.amount }) {
            if item.amount / total < 0.04 && result.count >= 7 {
                otherAmount += item.amount
            } else {
                result.append(item)
            }
        }
        if otherAmount > 0 {
            result.append((name: viewModel.loc("Other"), amount: otherAmount))
        }
        return result
    }

    private func emptyView(title: String, feature: String, tab: Int, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 16) {
            PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 58, symbolScale: 0.42, shape: .circle, isProminent: true)
            Text(title)
                .font(.title3.weight(.semibold))

            Button {
                handleGenerate(feature: feature, tab: tab, action: action)
            } label: {
                Label(viewModel.generateLabel, systemImage: "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .premiumActionFill(tint: viewModel.primaryColor, followsWallpaperOpacity: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func historySection(type: String) -> some View {
        let filtered = viewModel.analysisHistory.filter { $0.type == type }
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(AnimationPresets.fold) {
                        showsHistory.toggle()
                    }
                } label: {
                    HStack {
                        Text(viewModel.historyLabel)
                            .font(.headline)
                        Spacer()
                        Text("\(filtered.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: showsHistory ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showsHistory {
                    VStack(spacing: 8) {
                        ForEach(filtered) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                if let date = item.analysisDate ?? item.createdDate {
                                    Text(formatDate(date))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(viewModel.primaryColor)
                                }
                                Text(item.content)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .themedMiniPanel(tint: viewModel.primaryColor, cornerRadius: 10, colorStrength: 0.75)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedHistoryItem = item }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteAnalysisHistory(item) }
                                } label: {
                                    Label(viewModel.deleteLabel, systemImage: "trash")
                                }
                            }
                        }
                    }
                    .transition(.foldReveal)
                }
            }
            .padding(16)
            .premiumPanel(tint: viewModel.primaryColor)
            .animation(AnimationPresets.fold, value: showsHistory)
        }
    }

    private var upgradePrompt: some View {
        VStack(spacing: 16) {
            PennyLetIconTile(symbol: "crown.fill", tint: Color(.systemYellow), size: 58, symbolScale: 0.42, shape: .diamond, isProminent: true)
            Text(viewModel.monthlyInsightRequiresPro)
                .font(.title3.weight(.semibold))
            Button {
                showUpgradeOrGuestPrompt()
            } label: {
                Text(viewModel.upgradeToProLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func showUpgradeOrGuestPrompt() {
        showUpgradeSheet = true
    }

    private func handleGenerate(feature: String, tab: Int? = nil, action: @escaping () async -> Void) {
        if viewModel.canUseFeature(feature) {
            if let tab {
                beginGenerating(for: tab)
            }
            Task { await action() }
        } else if viewModel.isPro {
            showUsageAlert = true
        } else {
            showUpgradeOrGuestPrompt()
        }
    }

    private func generateAgain(for tab: Int) {
        switch tab {
        case 0:
            handleGenerate(feature: "daily", tab: tab) {
                await generate(for: 0) { progress in try await viewModel.generateDailyAnalysis(progress: progress) }
            }
        case 1:
            handleGenerate(feature: "recap", tab: tab) {
                await generate(for: 1) { progress in try await viewModel.generateWeeklyAnalysis(progress: progress) }
            }
        case 2:
            handleGenerate(feature: "insight", tab: tab) {
                await generate(for: 2) { progress in try await viewModel.generateMonthlyAnalysis(progress: progress) }
            }
        case 3:
            handleGenerate(feature: "forecast", tab: tab) {
                await generate(for: 3) { progress in try await viewModel.generateForecast(progress: progress) }
            }
        default:
            break
        }
    }

    private func generate(
        for tab: Int,
        operation: @escaping (@escaping AppViewModel.AIProgressHandler) async throws -> AppViewModel.AIResult
    ) async {
        if tabLoading.indices.contains(tab), tabLoading[tab] == false {
            beginGenerating(for: tab)
        }
        await Task.yield()
        defer {
            tabLoading[tab] = false
        }
        do {
            _ = try await operation { phase in
                updateProgress(phase, for: tab)
            }
        } catch {
            tabErrors[tab] = aiErrorMessage(error)
        }
    }

    @MainActor
    private func beginGenerating(for tab: Int) {
        guard tabLoading.indices.contains(tab) else { return }
        updateProgress(.collectingData, for: tab)
        tabLoading[tab] = true
        tabErrors[tab] = nil
        switch tab {
        case 0: viewModel.currentDailyResult = nil
        case 1: viewModel.currentWeeklyResult = nil
        case 2: viewModel.currentMonthlyResult = nil
        case 3: viewModel.currentForecastResult = nil
        default: break
        }
    }

    private func aiErrorMessage(_ error: Error) -> String {
        if let clientError = error as? ClientError {
            switch clientError {
            case .requestTimedOut:
                return viewModel.loc("AI timed out. Try again.")
            case .unauthorized, .serverError:
                return viewModel.loc("AI service is unavailable. Please try again.")
            default:
                break
            }
        }
        return error.localizedDescription
    }

    @MainActor
    private func updateProgress(_ phase: AppViewModel.AIProgressPhase, for tab: Int) {
        guard tabProgressPhases.indices.contains(tab) else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            tabProgressPhases[tab] = phase
        }
    }

    private func progressPhase(for tab: Int) -> AppViewModel.AIProgressPhase {
        guard tabProgressPhases.indices.contains(tab) else { return .collectingData }
        return tabProgressPhases[tab]
    }

    private func progressTitle(for tab: Int) -> String {
        switch tab {
        case 0: return viewModel.loc("Preparing daily insight")
        case 1: return viewModel.loc("Building weekly recap")
        case 2: return viewModel.loc("Creating monthly insight")
        case 3: return viewModel.loc("Forecasting spending")
        default: return viewModel.generatingLabel
        }
    }

    private func progressStepText(for phase: AppViewModel.AIProgressPhase) -> String {
        viewModel.loc(phase.messageKey)
    }

    private func progressPhaseTitleKey(for phase: AppViewModel.AIProgressPhase, tab: Int) -> String {
        switch phase {
        case .collectingData:
            switch tab {
            case 0: return "Gathering today's transactions"
            case 1: return "Gathering this week's activity"
            case 2: return "Gathering this month's activity"
            case 3: return "Gathering forecast inputs"
            default: return "Reading local spending data"
            }
        case .requestPrepared:
            switch tab {
            case 0: return "Preparing the daily prompt"
            case 1: return "Preparing the weekly prompt"
            case 2: return "Preparing the monthly prompt"
            case 3: return "Preparing the forecast prompt"
            default: return "Preparing AI request"
            }
        case .waitingForAI:
            return "Waiting for AI response"
        case .usingLocalSummary:
            return "Finishing with a local summary"
        case .responseReceived:
            switch tab {
            case 0: return "Checking the daily result"
            case 1: return "Checking the weekly result"
            case 2: return "Checking the monthly result"
            case 3: return "Checking the forecast result"
            default: return "AI response received"
            }
        case .savingResult:
            switch tab {
            case 0: return "Saving your daily insight"
            case 1: return "Saving your weekly recap"
            case 2: return "Saving your monthly insight"
            case 3: return "Saving your forecast"
            default: return "Saving result locally"
            }
        case .finished:
            return "Result ready"
        }
    }

    private func progressPhaseDetailKey(for phase: AppViewModel.AIProgressPhase) -> String {
        switch phase {
        case .collectingData:
            return "Reading your local money data."
        case .requestPrepared:
            return "Preparing the AI request."
        case .waitingForAI:
            return "PennyLet waits briefly, then finishes with private local math if needed."
        case .usingLocalSummary:
            return "Your local spending summary is being turned into a readable result."
        case .responseReceived:
            return "Checking the result."
        case .savingResult:
            return "Saving on this device."
        case .finished:
            return "Your analysis is ready to read."
        }
    }

    private var dateLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(dateLocale))
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(dateLocale))
        }
        return iso
    }
}
