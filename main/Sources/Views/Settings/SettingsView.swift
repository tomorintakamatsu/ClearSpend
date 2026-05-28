import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct WallpaperCropSource: Identifiable {
    let id = UUID()
    let imageData: Data
    let image: UIImage
}

struct WallpaperCropResult {
    let imageData: Data
    let zoomPercent: Double
    let horizontalFrame: Double
    let verticalFrame: Double
}

private enum SettingsChunk: String, Hashable {
    case visibleBlocks
    case wallpaper
    case appearance
    case pro
    case budget
    case preferences
    case analysis
    case data
    case account
    case developer
    case legal
}

struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var exportItem: ExportShareItem?
    @State private var showCSVImport = false
    @State private var showResetConfirm = false
    @State private var importResult: (success: Bool, count: Int)?
    @State private var exportSuccess = false
    @State private var exportFileName = "pennylet_export"
    @State private var showFileNamePrompt = false
    @State private var pendingResetAfterExport = false
    @State private var ratesRefreshed = false
    @State private var developerTapCount = 0
    @State private var showDeveloperControls = false
    @State private var showDeveloperUnlockAlert = false
    @State private var showUpgrade = false
    @State private var selectedWallpaper: PhotosPickerItem?
    @State private var isAnalyzingWallpaper = false
    @State private var wallpaperError: String?
    @State private var pendingWallpaperCrop: WallpaperCropSource?
    @State private var profileSaveMessage: String?
    @State private var showProfileNamePrompt = false
    @State private var profileNameText = ""
    @State private var expandedChunks: Set<SettingsChunk> = [.visibleBlocks, .wallpaper]

    // Editable budget fields
    @State private var incomeText: String = ""
    @State private var essentialsText: String = ""
    @State private var savingsText: String = ""
    @State private var payDayVal: Int = 1
    @State private var budgetSaveTimer: Task<Void, Never>?

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "HKD", "SGD", "KRW", "BRL"]
    private let languages = ["en", "ja", "zh"]

    private var timeOptions: [String] {
        stride(from: 0, to: 24, by: 1).flatMap { h in
            [String(format: "%02d:00", h), String(format: "%02d:30", h)]
        }
    }

    var body: some View {
        Form {
            visibleBlocksSection
            wallpaperSection
            appearanceSection
            if !viewModel.isPro {
                proSection
            }
            budgetSection
            preferencesSection
            analysisSection
            dataSection
            accountSection
            if showDeveloperControls || viewModel.isDeveloperMode {
                developerSection
            }
            legalSection
        }
        .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
        .navigationTitle(viewModel.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton(viewModel.loc("Done"))
        .sheet(item: $exportItem, onDismiss: {
            exportSuccess = true
        }) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert(viewModel.loc("Export Successful"), isPresented: $exportSuccess) {
            Button(viewModel.loc("OK"), role: .cancel) {
                if pendingResetAfterExport {
                    viewModel.restoreDefaults()
                    pendingResetAfterExport = false
                }
            }
        } message: {
            Text("\(viewModel.loc("File saved as")) \(exportFileName).csv")
        }
        .alert(importResult?.success == true ? viewModel.loc("Import Successful") : viewModel.loc("Import Failed"), isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button(viewModel.loc("OK"), role: .cancel) {}
        } message: {
            if let r = importResult, r.success {
                Text("\(viewModel.loc("Imported")) \(r.count) \(viewModel.loc("transactions successfully."))")
            } else {
                Text(viewModel.loc("The file could not be read. Check the format and try again."))
            }
        }
        .alert(viewModel.loc("Export & Reset"), isPresented: $showResetConfirm) {
            Button(viewModel.loc("Export CSV & Reset")) { exportAndReset() }
            Button(viewModel.loc("Reset Without Export"), role: .destructive) { viewModel.restoreDefaults() }
            Button(viewModel.cancelLabel, role: .cancel) {}
        } message: {
            Text(viewModel.loc("Save your data as CSV before resetting? All local data will be cleared."))
        }
        .alert(viewModel.devModeEnabled, isPresented: $showDeveloperUnlockAlert) {
            Button(viewModel.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.developerUnlockMessage)
        }
        .alert(viewModel.loc("Name Profile"), isPresented: $showProfileNamePrompt) {
            TextField(viewModel.loc("Profile name"), text: $profileNameText)
            Button(viewModel.loc("Save")) {
                saveNamedWallpaperProfile()
            }
            Button(viewModel.cancelLabel, role: .cancel) {}
        } message: {
            Text(viewModel.loc("Save the current wallpaper, crop, and appearance settings as a profile."))
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .sheet(item: $pendingWallpaperCrop) { source in
            WallpaperCropEditor(source: source) { result in
                Task { await applyWallpaperCrop(result) }
            }
        }
    }

    private var proSection: some View {
        settingsSection(viewModel.loc("PennyLet Pro"), chunk: .pro) {
            Button {
                showUpgrade = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 34, height: 34)
                        .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.loc("PennyLet Pro"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(viewModel.upgradeToProLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        chunk: SettingsChunk,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedChunks.contains(chunk) },
                set: { isExpanded in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        if isExpanded {
                            expandedChunks.insert(chunk)
                        } else {
                            expandedChunks.remove(chunk)
                        }
                    }
                    Haptics.selection()
                }
            )) {
                content()
                    .padding(.top, 6)
            } label: {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsSection(viewModel.appearanceSection, chunk: .appearance) {
            themePicker
            colorModePicker
            fontPicker
            weekStartPicker
        }
    }

    private var wallpaperSection: some View {
        settingsSection(viewModel.loc("Wallpaper Theme"), chunk: .wallpaper) {
            wallpaperThemePicker
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.loc("Preset themes"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        Haptics.selection()
                        viewModel.selectTheme(theme)
                        savePreferences()
                    } label: {
                        VStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .fill(theme.primaryColor)
                                    .frame(width: 34, height: 34)
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 14, height: 14)
                                    .offset(x: 11, y: 11)
                            }
                            Text(viewModel.loc(theme.label))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .padding(.vertical, 7)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(!viewModel.isUsingCustomThemeColor && viewModel.theme == theme ? viewModel.primaryColor : Color(.separator).opacity(0.12), lineWidth: !viewModel.isUsingCustomThemeColor && viewModel.theme == theme ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            ColorPicker(
                selection: Binding(
                    get: { viewModel.customThemeColor },
                    set: {
                        viewModel.setCustomThemeColor($0)
                        savePreferences()
                    }
                ),
                supportsOpacity: false
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "eyedropper.halffull")
                        .foregroundStyle(viewModel.primaryColor)
                    Text(viewModel.loc("Custom color"))
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var colorModePicker: some View {
        Picker(viewModel.colorModeLabel, selection: Binding(
            get: { viewModel.colorMode },
            set: { viewModel.colorMode = $0; savePreferences() }
        )) {
            ForEach(AppColorMode.allCases, id: \.self) { mode in
                Text(viewModel.loc(mode.label)).tag(mode)
            }
        }
    }

    private var wallpaperThemePicker: some View {
        let pickerTitle = viewModel.loc(viewModel.hasWallpaperTheme ? "Change Wallpaper" : "Import Wallpaper")
        let pickerTint = viewModel.primaryColor

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(viewModel.primaryColor)
                    .frame(width: 34, height: 34)
                    .background(viewModel.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.loc("Wallpaper Theme"))
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.loc("PennyLet reads the main colors from your wallpaper and tints the app automatically."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if !viewModel.wallpaperProfiles.isEmpty {
                wallpaperProfileScroller
            }

            if let image = viewModel.wallpaperUIImage {
                wallpaperFramePreview(image)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.loc("Wallpaper colors active"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            paletteDot(viewModel.wallpaperPalette?.primaryColor ?? viewModel.primaryColor)
                            paletteDot(viewModel.wallpaperPalette?.accentColor ?? viewModel.accentColor)
                            paletteDot(viewModel.wallpaperPalette?.backgroundColor ?? viewModel.backgroundColor)
                        }
                    }

                    Spacer()
                }

                VStack(spacing: 12) {
                    wallpaperSlider(
                        viewModel.loc("Wallpaper visibility"),
                        value: Binding(
                            get: { viewModel.wallpaperVisibility },
                            set: { viewModel.wallpaperVisibility = $0 }
                        )
                    )

                    wallpaperSlider(
                        viewModel.loc("Wallpaper blur"),
                        value: Binding(
                            get: { viewModel.wallpaperBlurRadius },
                            set: { viewModel.wallpaperBlurRadius = $0 }
                        )
                    )

                    wallpaperSlider(
                        viewModel.loc("Card opacity"),
                        value: Binding(
                            get: { viewModel.wallpaperPanelOpacity },
                            set: { viewModel.wallpaperPanelOpacity = $0 }
                        )
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        profileNameText = viewModel.activeWallpaperProfile?.name ?? viewModel.loc("Wallpaper")
                        showProfileNamePrompt = true
                    } label: {
                        Label(viewModel.loc("Save Profile"), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)

                    if let profileSaveMessage {
                        Text(profileSaveMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.primaryColor)
                            .transition(.opacity)
                    }
                }
            }

            if isAnalyzingWallpaper {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(viewModel.loc("Analyzing wallpaper colors..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let wallpaperError {
                Text(wallpaperError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(spacing: 10) {
                PhotosPicker(selection: $selectedWallpaper, matching: .images) {
                    Label(pickerTitle, systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(pickerTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isAnalyzingWallpaper)

                if viewModel.hasWallpaperTheme {
                    Button(role: .destructive) {
                        Haptics.selection()
                        viewModel.clearWallpaperTheme()
                    } label: {
                        Label(viewModel.loc("Remove Wallpaper Theme"), systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.systemRed))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemRed).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(.systemRed).opacity(0.18), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzingWallpaper)
                }
            }
        }
        .padding(.vertical, 6)
        .onChange(of: selectedWallpaper) { _, item in
            guard let item else { return }
            Task { await importWallpaper(item) }
        }
    }

    private func paletteDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
            }
    }

    private var wallpaperProfileScroller: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Saved Wallpaper Profiles"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.wallpaperProfiles) { profile in
                        Button {
                            Haptics.selection()
                            viewModel.selectWallpaperProfile(profile)
                            profileSaveMessage = nil
                        } label: {
                            wallpaperProfileCard(profile)
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func wallpaperProfileCard(_ profile: WallpaperThemeProfile) -> some View {
        let isSelected = profile.id == viewModel.activeWallpaperProfileID

        return VStack(alignment: .leading, spacing: 6) {
            if let image = viewModel.wallpaperProfileImages[profile.id] {
                WallpaperImageSurface(
                    image: image,
                    aspectRatio: phoneAspectRatio,
                    zoomPercent: profile.zoomPercent,
                    horizontalFrame: profile.horizontalFrame,
                    verticalFrame: profile.verticalFrame,
                    blurRadius: min(profile.blurRadius, 8),
                    visibility: 1
                )
                .frame(width: 76, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 76, height: 148)
            }

            Text(profile.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(width: 86, alignment: .leading)
        }
        .padding(9)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? viewModel.primaryColor : Color(.separator).opacity(0.14), lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isSelected ? 1 : 0.98)
    }

    private func wallpaperFramePreview(_ image: UIImage) -> some View {
        HStack {
            Spacer(minLength: 0)

            WallpaperImageSurface(
                image: image,
                aspectRatio: phoneAspectRatio,
                zoomPercent: viewModel.wallpaperZoomPercent,
                horizontalFrame: viewModel.wallpaperHorizontalFrame,
                verticalFrame: viewModel.wallpaperVerticalFrame,
                blurRadius: viewModel.wallpaperBlurRadius,
                visibility: viewModel.wallpaperVisibilityOpacity
            )
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear, viewModel.primaryColor.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(viewModel.wallpaperPanelOpacityValue))
                        .frame(width: 130, height: 34)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(viewModel.wallpaperPanelOpacityValue * 0.82))
                        .frame(width: 96, height: 24)
                }
                .padding(14)
            }
            .frame(width: previewPhoneWidth, height: previewPhoneWidth / phoneAspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)

            Spacer(minLength: 0)
        }
    }

    private var previewPhoneWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.56, 210)
    }

    private var phoneAspectRatio: CGFloat {
        let size = UIScreen.main.bounds.size
        let shortSide = max(1, min(size.width, size.height))
        let longSide = max(shortSide, max(size.width, size.height))
        return shortSide / longSide
    }

    private func wallpaperSlider(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        let clampedValue = Binding<Double>(
            get: { min(max(value.wrappedValue, 0), 100) },
            set: { newValue in
                var transaction = SwiftUI.Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    value.wrappedValue = min(max(newValue, 0), 100)
                }
            }
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(clampedValue.wrappedValue.rounded()))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(viewModel.primaryColor)
            }

            Slider(value: clampedValue, in: 0...100) { isEditing in
                if !isEditing {
                    viewModel.saveWallpaperAppearance()
                    Haptics.selection()
                }
            }
            .tint(viewModel.primaryColor)
            .frame(height: 34)
            .contentShape(Rectangle())
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .padding(.vertical, 3)
    }

    private var fontPicker: some View {
        Picker(viewModel.fontLabel, selection: Binding(
            get: { viewModel.font },
            set: { viewModel.font = $0; savePreferences() }
        )) {
            ForEach(AppFont.allCases, id: \.self) { font in
                Text(viewModel.loc(font.label)).tag(font)
            }
        }
    }

    private var weekStartPicker: some View {
        Picker(viewModel.weekStartsLabel, selection: Binding(
            get: { viewModel.currentBudget?.startOfWeek ?? "sunday" },
            set: { savePreference("start_of_week", $0) }
        )) {
            Text(viewModel.sundayLabel).tag("sunday")
            Text(viewModel.mondayLabel).tag("monday")
        }
    }

    // MARK: - Visible Blocks

    private var visibleBlocksSection: some View {
        settingsSection(viewModel.loc("Visible Blocks"), chunk: .visibleBlocks) {
            DisclosureGroup(viewModel.homeTab) {
                blockToggle(.homeSafeToSpend, title: viewModel.loc("Safe to Spend Today"))
                blockToggle(.homeMonthlyPulse, title: viewModel.loc("Monthly pulse"))
                blockToggle(.homeTopCategories, title: viewModel.loc("Top Categories"))
                blockToggle(.homeRecentActivity, title: viewModel.loc("Recent Activity"))
            }

            DisclosureGroup(viewModel.activityTab) {
                blockToggle(.activityFilter, title: viewModel.loc("Filter"))
                blockToggle(.activitySummary, title: viewModel.loc("Activity Summary"))
            }

            DisclosureGroup(viewModel.goalsTab) {
                blockToggle(.goalsOverview, title: viewModel.loc("Savings direction"))
            }

            DisclosureGroup(viewModel.aiTab) {
                blockToggle(.aiIntro, title: viewModel.loc("PennyLet Intelligence"))
                blockToggle(.aiUsage, title: viewModel.loc("Usage"))
                blockToggle(.aiHistory, title: viewModel.loc("AI History"))
            }

            DisclosureGroup(viewModel.moreTab) {
                blockToggle(.moreOverview, title: viewModel.loc("Money cockpit"))
                blockToggle(.subscriptionsOverview, title: viewModel.loc("Active Subscriptions"))
                blockToggle(.subscriptionsSuggestions, title: viewModel.loc("Suggested subscriptions"))
                blockToggle(.budgetOverview, title: viewModel.loc("Budget Overview"))
                blockToggle(.budgetCategories, title: viewModel.loc("Spending by Category"))
                blockToggle(.budgetIncomeChart, title: viewModel.loc("Income vs Spending"))
                blockToggle(.budgetKeyNumbers, title: viewModel.loc("Key numbers"))
            }

            Button {
                viewModel.resetVisibleBlocks()
            } label: {
                Label(viewModel.loc("Reset Visible Blocks"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func blockToggle(_ block: AppDisplayBlock, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { viewModel.isBlockVisible(block) },
            set: { viewModel.setBlock(block, visible: $0) }
        ))
    }

    // MARK: - Budget

    private var budgetSection: some View {
        settingsSection(viewModel.budgetSection, chunk: .budget) {
            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.monthlyIncomeLabel, text: $incomeText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: incomeText) { _, _ in scheduleBudgetSave() }

            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.essentialsLabel, text: $essentialsText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: essentialsText) { _, _ in scheduleBudgetSave() }

            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.savingsGoalLabel, text: $savingsText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: savingsText) { _, _ in scheduleBudgetSave() }

            Stepper("\(viewModel.payDayLabel): \(payDayVal)", value: $payDayVal, in: 1...31)
                .onChange(of: payDayVal) { _, _ in saveBudgetNow() }
        }
        .onAppear {
            if let budget = viewModel.currentBudget {
                incomeText = String(format: "%.0f", budget.monthlyIncome)
                essentialsText = budget.monthlyEssentials.map { String(format: "%.0f", $0) } ?? ""
                savingsText = budget.monthlySavingsGoal.map { String(format: "%.0f", $0) } ?? ""
                payDayVal = budget.payDay ?? 1
            }
        }
        .onChange(of: viewModel.currentBudget?.id) { _, _ in
            if let budget = viewModel.currentBudget {
                incomeText = String(format: "%.0f", budget.monthlyIncome)
                essentialsText = budget.monthlyEssentials.map { String(format: "%.0f", $0) } ?? ""
                savingsText = budget.monthlySavingsGoal.map { String(format: "%.0f", $0) } ?? ""
                payDayVal = budget.payDay ?? 1
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        settingsSection(viewModel.preferencesSection, chunk: .preferences) {
            Picker(viewModel.currencyLabel, selection: Binding(
                get: { viewModel.currency },
                set: { viewModel.currency = $0; savePreferences() }
            )) {
                ForEach(currencies, id: \.self) { c in
                    Text("\(c) (\(CurrencyFormat.currencySymbol(for: c)))").tag(c)
                }
            }
            Picker(viewModel.languageLabel, selection: Binding(
                get: { viewModel.language },
                set: { viewModel.language = $0; savePreferences() }
            )) {
                ForEach(languages, id: \.self) { code in
                    Text(viewModel.languageDisplayName(for: code)).tag(code)
                }
            }
        }
    }

    // MARK: - Analysis Scheduling

    @State private var showAutoAnalysisHelp = false

    @ViewBuilder
    private var analysisSection: some View {
        if viewModel.isPro {
            analysisSettingsSection
                .alert(viewModel.loc("Auto Analysis Help"), isPresented: $showAutoAnalysisHelp) {
                    Button(viewModel.loc("OK"), role: .cancel) {}
                } message: {
                    Text(viewModel.loc("Auto Analysis automatically generates daily, weekly, and monthly AI spending insights at your scheduled times. Enable it and set your preferred times below."))
                }
        }
    }

    private var analysisSettingsSection: some View {
        settingsSection(viewModel.analysisSectionLabel, chunk: .analysis) {
            HStack {
                Text(viewModel.autoAnalysisLabel)
                Spacer()
                Button {
                    showAutoAnalysisHelp = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(viewModel.primaryColor)
                }
                .buttonStyle(.plain)
            }
            Toggle(viewModel.autoAnalysisLabel, isOn: Binding(
                get: { viewModel.currentBudget?.autoAnalysisEnabled ?? false },
                set: { savePreference("auto_analysis_enabled", $0) }
            ))
            if viewModel.currentBudget?.autoAnalysisEnabled == true {
                HStack {
                    Text(viewModel.dailyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.dailyAnalysisTime ?? "21:00" },
                        set: { savePreference("daily_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                HStack {
                    Text(viewModel.weeklyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.weeklyAnalysisTime ?? "09:00" },
                        set: { savePreference("weekly_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                HStack {
                    Text(viewModel.monthlyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.monthlyAnalysisTime ?? "09:00" },
                        set: { savePreference("monthly_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        settingsSection(viewModel.dataSectionLabel, chunk: .data) {
            Button {
                pendingResetAfterExport = false
                showFileNamePrompt = true
            } label: {
                Label(viewModel.exportCSVLabel, systemImage: "square.and.arrow.up")
            }
            Button {
                showCSVImport = true
            } label: {
                Label(viewModel.loc("Import CSV"), systemImage: "square.and.arrow.down")
            }
            Button {
                Task {
                    await viewModel.refreshExchangeRates()
                    ratesRefreshed = true
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    ratesRefreshed = false
                }
            } label: {
                Label(
                    ratesRefreshed ? viewModel.loc("Exchange rates updated") : viewModel.loc("Refresh Exchange Rates"),
                    systemImage: ratesRefreshed ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                )
            }
            .disabled(ratesRefreshed)
        }
        .fileImporter(isPresented: $showCSVImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result {
                importCSV(from: url)
            }
        }
        .alert(viewModel.loc("Export CSV"), isPresented: $showFileNamePrompt) {
            TextField(viewModel.loc("File name"), text: $exportFileName)
            Button(viewModel.loc("Export")) { exportCSV() }
            Button(viewModel.cancelLabel, role: .cancel) {}
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        settingsSection(viewModel.accountSectionLabel, chunk: .account) {
            Button {
                registerDeveloperTap()
            } label: {
                HStack {
                    Label(viewModel.appVersionLabel, systemImage: "info.circle")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label(viewModel.loc("Export & Reset"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var developerSection: some View {
        settingsSection(viewModel.developerToolsLabel, chunk: .developer) {
            Toggle(isOn: Binding(
                get: { viewModel.isDeveloperMode },
                set: { viewModel.setDeveloperMode($0) }
            )) {
                Label(viewModel.developerProAccessLabel, systemImage: viewModel.isDeveloperMode ? "crown.fill" : "crown")
            }

            Text(viewModel.isDeveloperMode ? viewModel.devModeUnlimited : viewModel.developerModeDisabledMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        settingsSection(viewModel.loc("Legal"), chunk: .legal) {
            Link(destination: URL(string: "https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf")!) {
                Label(viewModel.loc("Privacy Policy"), systemImage: "hand.raised.fill")
            }
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                Label(viewModel.loc("Terms of Use (EULA)"), systemImage: "doc.text.fill")
            }
        }
    }

    // MARK: - Actions

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private func registerDeveloperTap() {
        guard !showDeveloperControls else { return }
        developerTapCount += 1
        if developerTapCount >= 5 {
            developerTapCount = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showDeveloperControls = true
            }
            showDeveloperUnlockAlert = true
        }
    }

    private func saveNamedWallpaperProfile() {
        let fallback = viewModel.activeWallpaperProfile?.name ?? viewModel.loc("Wallpaper")
        let name = profileNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : profileNameText
        viewModel.saveCurrentWallpaperProfile(named: name)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            profileSaveMessage = viewModel.loc("Profile saved")
        }
        Haptics.success()
    }

    private func scheduleBudgetSave() {
        budgetSaveTimer?.cancel()
        budgetSaveTimer = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            saveBudgetNow()
        }
    }

    private func saveBudgetNow() {
        guard let income = CurrencyFormat.parseInput(incomeText), income > 0,
              viewModel.currentBudget != nil else { return }
        // Only update the budget fields that changed; updateBudgetLocally preserves nil fields
        viewModel.updateBudgetLocally(BudgetData(
            monthlyIncome: income,
            monthlyEssentials: CurrencyFormat.parseInput(essentialsText),
            monthlySavingsGoal: CurrencyFormat.parseInput(savingsText),
            payDay: payDayVal
        ))
    }

    private func savePreferences() {
        viewModel.savePreferencesToDisk()
        guard let budget = viewModel.currentBudget else { return }
        let data = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            currency: viewModel.currency,
            language: viewModel.language,
            theme: viewModel.theme.rawValue,
            colorMode: viewModel.colorMode.rawValue,
            font: viewModel.font.rawValue
        )
        viewModel.updateBudgetLocally(data)
    }

    private func importWallpaper(_ item: PhotosPickerItem) async {
        isAnalyzingWallpaper = true
        wallpaperError = nil
        defer {
            isAnalyzingWallpaper = false
            selectedWallpaper = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                wallpaperError = viewModel.loc("Could not read that image. Try another wallpaper.")
                return
            }
            guard let image = UIImage(data: data) else {
                wallpaperError = viewModel.loc("Could not read that image. Try another wallpaper.")
                return
            }
            pendingWallpaperCrop = WallpaperCropSource(imageData: data, image: image)
        } catch {
            wallpaperError = viewModel.loc("Could not read that image. Try another wallpaper.")
        }
    }

    private func applyWallpaperCrop(_ result: WallpaperCropResult) async {
        isAnalyzingWallpaper = true
        wallpaperError = nil
        defer { isAnalyzingWallpaper = false }

        do {
            try await viewModel.importWallpaperTheme(
                from: result.imageData,
                zoomPercent: result.zoomPercent,
                horizontalFrame: result.horizontalFrame,
                verticalFrame: result.verticalFrame
            )
            profileSaveMessage = viewModel.loc("Profile saved")
            Haptics.success()
        } catch {
            wallpaperError = viewModel.loc("Could not read that image. Try another wallpaper.")
        }
    }

    private func savePreference(_ key: String, _ value: Any) {
        guard let budget = viewModel.currentBudget else { return }
        var update = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            currency: budget.currency,
            language: budget.language,
            theme: budget.theme,
            colorMode: budget.colorMode,
            font: budget.font
        )
        switch key {
        case "start_of_week": update.startOfWeek = value as? String
        case "auto_analysis_enabled": update.autoAnalysisEnabled = value as? Bool
        case "daily_analysis_time": update.dailyAnalysisTime = value as? String
        case "weekly_analysis_time": update.weeklyAnalysisTime = value as? String
        case "monthly_analysis_time": update.monthlyAnalysisTime = value as? String
        default: break
        }
        viewModel.updateBudgetLocally(update)
    }

    private func exportAndReset() {
        pendingResetAfterExport = true
        showFileNamePrompt = true
    }

    private func exportCSV() {
        var csv = viewModel.loc("Date,Type,Category,Amount,Note,Merchant,OriginalCurrency,OriginalAmount,ExchangeRate") + "\n"
        for tx in viewModel.transactions {
            let note = (tx.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let merchant = (tx.merchant ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let origCur = tx.originalCurrency ?? ""
            let origAmt = tx.originalAmount.map { String(format: "%.2f", $0) } ?? ""
            let xrate = tx.exchangeRate.map { String(format: "%.4f", $0) } ?? ""
            csv += "\(tx.date),\(tx.type.rawValue),\(tx.category ?? ""),\(tx.amount),\"\(note)\",\"\(merchant)\",\(origCur),\(origAmt),\(xrate)\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(exportFileName).csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportItem = ExportShareItem(url: tempURL)
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResult = (false, 0)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            importResult = (false, 0)
            return
        }
        let lines = content.components(separatedBy: "\n").dropFirst()
        var count = 0
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 4 else { continue }
            let date = cols[0].trimmingCharacters(in: .whitespaces)
            let type: Transaction.TransactionType = cols[1].trimmingCharacters(in: .whitespaces).lowercased() == "income" ? .income : .expense
            let category = cols[2].trimmingCharacters(in: .whitespaces)
            let amount = Double(cols[3].trimmingCharacters(in: .whitespaces)) ?? 0
            let note = cols.count > 4 ? cols[4].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces) : nil
            let merchant = cols.count > 5 ? cols[5].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces) : nil
            let origCurrency: String? = {
                guard cols.count > 6 else { return nil }
                let c = cols[6].trimmingCharacters(in: .whitespaces)
                return c.isEmpty ? nil : c
            }()
            let origAmount = cols.count > 7 ? Double(cols[7].trimmingCharacters(in: .whitespaces)) : nil
            let exchangeRate = cols.count > 8 ? Double(cols[8].trimmingCharacters(in: .whitespaces)) : nil
            guard amount > 0 else { continue }
            let txn = Transaction(
                id: "import-\(UUID().uuidString)", amount: amount, type: type,
                category: category.isEmpty ? nil : category,
                note: note, date: date, merchant: merchant,
                isRecurring: false, tags: nil,
                originalCurrency: origCurrency,
                originalAmount: origAmount,
                exchangeRate: exchangeRate,
                baseCurrency: origCurrency != nil ? viewModel.currency : nil
            )
            viewModel.transactions.append(txn)
            count += 1
        }
        viewModel.saveLocalData()
        importResult = count > 0 ? (true, count) : (false, 0)
    }
}

private struct WallpaperImageSurface: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let zoomPercent: Double
    let horizontalFrame: Double
    let verticalFrame: Double
    let blurRadius: Double
    let visibility: Double

    var body: some View {
        GeometryReader { proxy in
            let offset = frameOffset(in: proxy.size)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(zoomScale)
                .offset(x: offset.width, y: offset.height)
                .blur(radius: CGFloat(blurRadius))
                .opacity(visibility)
                .clipped()
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
    }

    private var zoomScale: CGFloat {
        1 + CGFloat(clamped(zoomPercent) / 100 * 1.6)
    }

    private func frameOffset(in size: CGSize) -> CGSize {
        let horizontal = (clamped(horizontalFrame) - 50) / 50
        let vertical = (clamped(verticalFrame) - 50) / 50
        let travel = 0.08 + (clamped(zoomPercent) / 100 * 0.58)
        return CGSize(width: size.width * travel * horizontal, height: size.height * travel * vertical)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

private struct WallpaperCropEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let source: WallpaperCropSource
    let onSave: (WallpaperCropResult) -> Void

    @State private var zoomPercent: Double = 24
    @State private var horizontalFrame: Double = 50
    @State private var verticalFrame: Double = 50
    @State private var dragStartHorizontal: Double?
    @State private var dragStartVertical: Double?
    @State private var zoomStartPercent: Double?

    private var phoneAspectRatio: CGFloat {
        let size = UIScreen.main.bounds.size
        let shortSide = max(1, min(size.width, size.height))
        let longSide = max(shortSide, max(size.width, size.height))
        return shortSide / longSide
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(viewModel.loc("Pinch and drag to frame your wallpaper."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                GeometryReader { proxy in
                    let cropSize = phoneCropSize(in: proxy.size)

                    ZStack {
                        WallpaperImageSurface(
                            image: source.image,
                            aspectRatio: phoneAspectRatio,
                            zoomPercent: zoomPercent,
                            horizontalFrame: horizontalFrame,
                            verticalFrame: verticalFrame,
                            blurRadius: 0,
                            visibility: 1
                        )
                        .frame(width: cropSize.width, height: cropSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.34), lineWidth: 1.5)
                        }
                        .overlay {
                            cropGrid
                                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                                .allowsHitTesting(false)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                        .gesture(cropGesture(size: cropSize))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                    Text("\(viewModel.loc("Zoom")) \(Int(zoomPercent.rounded()))%")
                    Text("•")
                    Text("\(viewModel.loc("Horizontal frame")) \(Int(horizontalFrame.rounded()))%")
                }
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 18)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(viewModel.loc("Crop Wallpaper"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelLabel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.loc("Use Crop")) {
                        onSave(WallpaperCropResult(
                            imageData: source.imageData,
                            zoomPercent: zoomPercent,
                            horizontalFrame: horizontalFrame,
                            verticalFrame: verticalFrame
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var cropGrid: some View {
        GeometryReader { proxy in
            Path { path in
                let thirdWidth = proxy.size.width / 3
                let thirdHeight = proxy.size.height / 3
                for index in 1...2 {
                    let x = thirdWidth * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    let y = thirdHeight * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.36), lineWidth: 0.8)
        }
    }

    private func phoneCropSize(in available: CGSize) -> CGSize {
        let maxWidth = max(180, available.width)
        let maxHeight = max(220, available.height)
        let widthFromHeight = maxHeight * phoneAspectRatio
        if widthFromHeight <= maxWidth {
            return CGSize(width: widthFromHeight, height: maxHeight)
        }

        return CGSize(width: maxWidth, height: maxWidth / phoneAspectRatio)
    }

    private func cropGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartHorizontal == nil {
                    dragStartHorizontal = horizontalFrame
                    dragStartVertical = verticalFrame
                }
                let horizontalDelta = Double(value.translation.width / max(size.width, 1)) * 120
                let verticalDelta = Double(value.translation.height / max(size.height, 1)) * 120
                horizontalFrame = clamped((dragStartHorizontal ?? 50) + horizontalDelta)
                verticalFrame = clamped((dragStartVertical ?? 50) + verticalDelta)
            }
            .onEnded { _ in
                dragStartHorizontal = nil
                dragStartVertical = nil
                Haptics.selection()
            }
            .simultaneously(with: MagnificationGesture()
                .onChanged { value in
                    if zoomStartPercent == nil {
                        zoomStartPercent = zoomPercent
                    }
                    let startScale = zoomScale(for: zoomStartPercent ?? zoomPercent)
                    let newScale = min(max(startScale * value, 1.0), 2.6)
                    zoomPercent = clamped((Double(newScale) - 1.0) / 1.6 * 100)
                }
                .onEnded { _ in
                    zoomStartPercent = nil
                    Haptics.selection()
                }
            )
    }

    private func zoomScale(for percent: Double) -> CGFloat {
        1 + CGFloat(clamped(percent) / 100 * 1.6)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIKit UIActivityViewController wrapped for SwiftUI
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
