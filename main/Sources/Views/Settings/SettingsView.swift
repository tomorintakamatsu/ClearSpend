import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct WallpaperCropSource: Identifiable {
    let id = UUID()
    let imageData: Data
    let image: UIImage
    var updatesCurrentProfile = false
    var initialZoomPercent: Double = 24
    var initialHorizontalFrame: Double = 50
    var initialVerticalFrame: Double = 50
}

struct WallpaperCropResult {
    let imageData: Data
    let zoomPercent: Double
    let horizontalFrame: Double
    let verticalFrame: Double
}

struct WallpaperActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let foreground: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum SettingsChunk: String, Hashable {
    case visibleBlocks
    case wallpaper
    case pro
    case budget
    case goalQuickAdd
    case preferences
    case analysis
    case data
    case developer
    case legal
}

struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportItem: ExportShareItem?
    @State private var showCSVImport = false
    @State private var showResetConfirm = false
    @State private var importResult: (success: Bool, count: Int)?
    @State private var exportSuccess = false
    @State private var isExporting = false
    @State private var exportFileName = "pennylet_export"
    @State private var showFileNamePrompt = false
    @State private var pendingResetAfterExport = false
    @State private var ratesRefreshed = false
    @State private var developerTapCount = 0
    @State private var showDeveloperControls = false
    @State private var showDeveloperUnlockAlert = false
    @State private var showUpgrade = false
    @State private var selectedWallpaper: PhotosPickerItem?
    @State private var showWallpaperPicker = false
    @State private var isAnalyzingWallpaper = false
    @State private var wallpaperError: String?
    @State private var pendingWallpaperCrop: WallpaperCropSource?
    @State private var profileSaveMessage: String?
    @State private var showProfileNamePrompt = false
    @State private var profileNameText = ""
    @State private var goalQuickAddTexts: [String] = []
    @State private var pendingDeleteWallpaperProfile: WallpaperThemeProfile?

    // Editable budget fields
    @State private var incomeText: String = ""
    @State private var essentialsText: String = ""
    @State private var savingsText: String = ""
    @State private var payDayVal: Int = 1
    @State private var draftPayDayVal: Int = 1
    @State private var showPayDayPicker = false
    @State private var currentSpendableText: String = ""
    @State private var cashOnHandText: String = ""
    @State private var keepUntouchedText: String = ""
    @State private var nextIncomeAmountText: String = ""
    @State private var nextIncomeDateVal: Date = Date()
    @State private var incomeCadenceVal: String = "monthly"
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
            if let importResult {
                settingsRootSection {
                    dataFeedbackBanner(importResult)
                }
            } else if isExporting {
                settingsRootSection {
                    exportBusyBanner
                }
            }

            settingsRootSection(viewModel.loc("Money Setup")) {
                settingsNavigationRow(.budget)
                settingsNavigationRow(.goalQuickAdd)
                settingsNavigationRow(.preferences)
                if viewModel.isPro {
                    settingsNavigationRow(.analysis)
                }
            }

            settingsRootSection(viewModel.loc("Customize")) {
                settingsNavigationRow(.visibleBlocks)
                settingsNavigationRow(.wallpaper)
            }

            if !viewModel.isPro {
                settingsRootSection {
                    settingsNavigationRow(.pro)
                }
            }

            settingsRootSection {
                settingsNavigationRow(.data)
                settingsNavigationRow(.legal)
            }

            if showDeveloperControls || viewModel.isDeveloperMode {
                settingsRootSection {
                    settingsNavigationRow(.developer)
                }
            }
        }
        .navigationDestination(for: SettingsChunk.self) { destination in
            settingsDestination(destination)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .font(.body)
        .tint(viewModel.primaryColor)
        .keyboardDoneButton(viewModel.loc("Done"))
        .listSectionSpacing(18)
        .environment(\.defaultMinListRowHeight, 74)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.loc("Done")) {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(item: $exportItem, onDismiss: {
            exportSuccess = true
        }) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert(viewModel.loc("Export Successful"), isPresented: $exportSuccess) {
            Button(viewModel.loc("OK"), role: .cancel) {
                if pendingResetAfterExport {
                    resetAfterExport()
                    pendingResetAfterExport = false
                }
            }
        } message: {
            Text("\(viewModel.loc("File saved as")) \(exportFileName).csv")
        }
        .alert(viewModel.loc("Export & Reset"), isPresented: $showResetConfirm) {
            Button(viewModel.loc("Export CSV & Reset")) { exportAndReset() }
            Button(viewModel.loc("Reset Without Export"), role: .destructive) { resetAfterExport() }
            Button(viewModel.cancelLabel, role: .cancel) {}
        } message: {
            Text(viewModel.loc("Export a CSV first? Reset clears local data."))
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
            Text(viewModel.loc("Save this wallpaper as a profile."))
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .sheet(isPresented: $showPayDayPicker) {
            paydayPickerSheet
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $pendingWallpaperCrop) { source in
            WallpaperCropEditor(source: source) { result in
                Task {
                    await applyWallpaperCrop(
                        result,
                        updatesCurrentProfile: source.updatesCurrentProfile
                    )
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    @ViewBuilder
    private func settingsDestination(_ destination: SettingsChunk) -> some View {
        switch destination {
        case .visibleBlocks:
            settingsDestinationForm(title: settingsTitle(for: destination)) { visibleBlocksSection }
        case .wallpaper:
            settingsDestinationForm(title: settingsTitle(for: destination)) {
                appearanceSection
                wallpaperSection
            }
        case .pro:
            UpgradeView()
        case .budget:
            settingsDestinationForm(title: settingsTitle(for: destination)) { budgetSection }
        case .goalQuickAdd:
            settingsDestinationForm(title: settingsTitle(for: destination)) { goalQuickAddSection }
        case .preferences:
            settingsDestinationForm(title: settingsTitle(for: destination)) { preferencesSection }
        case .analysis:
            settingsDestinationForm(title: settingsTitle(for: destination)) { analysisSection }
        case .data:
            settingsDestinationForm(title: settingsTitle(for: .data)) {
                dataSection
                accountSection
            }
        case .developer:
            settingsDestinationForm(title: settingsTitle(for: destination)) { developerSection }
        case .legal:
            settingsDestinationForm(title: settingsTitle(for: destination)) { legalSection }
        }
    }

    private func settingsDestinationForm<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Form {
            content()
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(viewModel.primaryColor)
        .keyboardDoneButton(viewModel.loc("Done"))
        .listSectionSpacing(22)
        .environment(\.defaultMinListRowHeight, 74)
    }

    private func settingsRootSection<Content: View>(
        _ title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            content()
        } header: {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 2, trailing: 18))
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private func settingsNavigationRow(_ destination: SettingsChunk) -> some View {
        if destination == .pro {
            Button {
                showUpgrade = true
            } label: {
                HStack(spacing: 8) {
                    settingsNavigationLabel(destination)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: destination) {
                settingsNavigationLabel(destination)
            }
        }
    }

    private func settingsNavigationLabel(_ destination: SettingsChunk) -> some View {
            HStack(spacing: 16) {
                Image(systemName: settingsIcon(for: destination))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(settingsTint(for: destination), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(settingsTitle(for: destination))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle = settingsSubtitle(for: destination) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
            .padding(.vertical, 12)
    }

    private func settingsTitle(for destination: SettingsChunk) -> String {
        switch destination {
        case .visibleBlocks:
            return viewModel.loc("Visible Blocks")
        case .wallpaper:
            return viewModel.loc("Appearance & Wallpaper")
        case .pro:
            return viewModel.loc("PennyLet Pro")
        case .budget:
            return viewModel.loc("Budget & Payday")
        case .goalQuickAdd:
            return viewModel.loc("Goal Quick Add")
        case .preferences:
            return viewModel.preferencesSection
        case .analysis:
            return viewModel.analysisSectionLabel
        case .data:
            return viewModel.dataSectionLabel
        case .developer:
            return viewModel.developerToolsLabel
        case .legal:
            return viewModel.loc("Legal")
        }
    }

    private func settingsSubtitle(for destination: SettingsChunk) -> String? {
        switch destination {
        case .visibleBlocks:
            return viewModel.loc("Choose what appears in each tab.")
        case .wallpaper:
            return viewModel.loc("Theme, wallpaper, colors, and card opacity.")
        case .pro:
            return viewModel.upgradeToProLabel
        case .budget:
            return viewModel.loc("Income, payday, and today's money.")
        case .goalQuickAdd:
            return viewModel.loc("Customize goal deposit buttons.")
        case .preferences:
            return viewModel.loc("Language and currency.")
        case .analysis:
            return viewModel.loc("Automatic AI schedules.")
        case .data:
            return viewModel.loc("Import, export, reset, and app version.")
        case .developer:
            return viewModel.loc("Developer tools and Pro testing.")
        case .legal:
            return viewModel.loc("Privacy policy and terms.")
        }
    }

    private func settingsIcon(for destination: SettingsChunk) -> String {
        switch destination {
        case .visibleBlocks: return "rectangle.grid.2x2"
        case .wallpaper: return "paintpalette.fill"
        case .pro: return "crown.fill"
        case .budget: return "calendar.badge.clock"
        case .goalQuickAdd: return "target"
        case .preferences: return "globe"
        case .analysis: return "sparkles"
        case .data: return "externaldrive.fill"
        case .developer: return "hammer.fill"
        case .legal: return "doc.text.fill"
        }
    }

    private func settingsTint(for destination: SettingsChunk) -> Color {
        switch destination {
        case .visibleBlocks: return viewModel.primaryColor
        case .wallpaper: return Color(.systemPurple)
        case .pro: return Color(.systemYellow)
        case .budget: return Color(.systemGreen)
        case .goalQuickAdd: return Color(.systemIndigo)
        case .preferences: return Color(.systemTeal)
        case .analysis: return Color(.systemOrange)
        case .data: return Color(.systemGray)
        case .developer: return Color(.systemRed)
        case .legal: return Color(.systemBrown)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        trailingIcon: String? = nil,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                content()
                    .padding(.vertical, 4)
            }
        } header: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                Spacer(minLength: 8)
                if let trailingIcon, let trailingAction {
                    Button {
                        trailingAction()
                    } label: {
                        Image(systemName: trailingIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.primaryColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 2, trailing: 18))
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }

    private func staticSettingsSection<Content: View>(
        _ title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .font(.body)
            .padding(.vertical, 6)
        } header: {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 2, trailing: 18))
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }

    private func settingsDivider() -> some View {
        Divider()
            .padding(.leading, 0)
            .opacity(0.55)
    }

    private func settingsActionLabel(_ title: String, systemImage: String, tint: Color? = nil) -> some View {
        Label {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(tint ?? Color.primary)
        } icon: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint ?? viewModel.primaryColor)
                .frame(width: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    private func settingsControlRow<Control: View>(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(.vertical, 18)
    }

    private var exportBusyBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(viewModel.primaryColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.loc("Preparing export..."))
                    .font(.body.weight(.semibold))
                Text(viewModel.loc("Preparing your CSV."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    private func dataFeedbackBanner(_ result: (success: Bool, count: Int)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(result.success ? Color(.systemGreen) : Color(.systemOrange))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.success ? viewModel.loc("Import Successful") : viewModel.loc("Import Failed"))
                    .font(.body.weight(.semibold))
                Text(result.success
                     ? "\(viewModel.loc("Imported")) \(result.count) \(viewModel.loc("transactions successfully."))"
                     : viewModel.loc("The file could not be read. Check the format and try again."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsSection(viewModel.appearanceSection) {
            themePicker
            colorModePicker
            fontPicker
            weekStartPicker
        }
    }

    private var wallpaperSection: some View {
        settingsSection(viewModel.loc("Wallpaper Theme")) {
            wallpaperThemePicker
        }
    }

    private var themePicker: some View {
        settingsControlRow(
            title: viewModel.loc("Custom color"),
            systemImage: "eyedropper.halffull",
            tint: viewModel.primaryColor
        ) {
            ColorPicker(
                "",
                selection: Binding(
                    get: { viewModel.customThemeColor },
                    set: {
                        viewModel.setCustomThemeColor($0)
                        savePreferences()
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 48, height: 48)
            .padding(5)
            .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
    }

    private var colorModePicker: some View {
        settingsControlRow(
            title: viewModel.colorModeLabel,
            systemImage: "circle.lefthalf.filled",
            tint: Color(.systemIndigo)
        ) {
            Picker("", selection: Binding(
                get: { viewModel.colorMode },
                set: { viewModel.colorMode = $0; savePreferences() }
            )) {
                ForEach(AppColorMode.allCases, id: \.self) { mode in
                    Text(viewModel.loc(mode.label)).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .tint(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
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
                    .background(viewModel.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.loc("Wallpaper Theme"))
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.loc("PennyLet pulls colors from your wallpaper."))
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
                wallpaperFramePickerPreview(image, pickerTitle: pickerTitle)

                wallpaperColorThemeRows

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
                        openCurrentWallpaperCrop()
                    } label: {
                        Label(viewModel.loc("Crop Current Wallpaper"), systemImage: "crop")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.wallpaperImageData == nil || viewModel.wallpaperUIImage == nil)

                    Button {
                        profileNameText = viewModel.activeWallpaperProfile?.name ?? viewModel.loc("Wallpaper")
                        showProfileNamePrompt = true
                    } label: {
                        Label(viewModel.loc("Save Profile"), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

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
                if !viewModel.hasWallpaperTheme || viewModel.wallpaperUIImage == nil {
                    Button {
                        Haptics.selection()
                        showWallpaperPicker = true
                    } label: {
                        WallpaperActionButton(
                            title: pickerTitle,
                            systemImage: "photo.badge.plus",
                            tint: pickerTint,
                            foreground: .white
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzingWallpaper)
                }

                if viewModel.hasWallpaperTheme {
                    Button(role: .destructive) {
                        Haptics.selection()
                        viewModel.clearWallpaperTheme()
                    } label: {
                        WallpaperActionButton(
                            title: viewModel.loc("Remove Wallpaper Theme"),
                            systemImage: "trash",
                            tint: Color(.systemRed).opacity(0.12),
                            foreground: Color(.systemRed)
                        )
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
        .photosPicker(isPresented: $showWallpaperPicker, selection: $selectedWallpaper, matching: .images)
    }

    private var wallpaperColorThemeRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            swatchRow(title: viewModel.loc("Wallpaper color themes")) {
                ForEach(Array(viewModel.wallpaperThemeColorOptions.enumerated()), id: \.offset) { index, color in
                    paletteButton(
                        color: color,
                        isSelected: isWallpaperThemeColorSelected(color, index: index),
                        label: viewModel.loc("Wallpaper color themes")
                    ) {
                        viewModel.selectWallpaperThemeColor(color, usesExtractedPalette: index == 0)
                    }
                }
            }

            swatchRow(title: viewModel.loc("Card box color themes")) {
                ForEach(Array(viewModel.wallpaperCardColorOptions.enumerated()), id: \.offset) { _, color in
                    paletteButton(
                        color: color,
                        isSelected: isWallpaperCardColorSelected(color),
                        label: viewModel.loc("Card box color themes")
                    ) {
                        viewModel.selectWallpaperCardColor(color)
                    }
                }
            }
        }
    }

    private func swatchRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                content()
            }
        }
    }

    private func paletteButton(
        color: Color,
        isSelected: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(isSelected ? viewModel.primaryColor : Color(.separator).opacity(0.18), lineWidth: isSelected ? 2.5 : 1)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func isCustomPaletteColorSelected(_ color: Color) -> Bool {
        viewModel.isUsingCustomThemeColor && colorHex(viewModel.customThemeColor) == colorHex(color)
    }

    private func isWallpaperThemeColorSelected(_ color: Color, index: Int) -> Bool {
        if index == 0 {
            return viewModel.isUsingWallpaperThemeColor
        }
        return isCustomPaletteColorSelected(color)
    }

    private func isWallpaperCardColorSelected(_ color: Color) -> Bool {
        viewModel.isUsingWallpaperCardColor && colorHex(viewModel.wallpaperCardColor) == colorHex(color)
    }

    private func colorHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        guard let converted = uiColor.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ),
              let components = converted.components else {
            return ""
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

    private var wallpaperProfileScroller: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Saved Wallpaper Profiles"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.wallpaperProfiles) { profile in
                        wallpaperProfileCard(profile)
                            .padding(3)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture {
                                Haptics.selection()
                                viewModel.selectWallpaperProfile(profile)
                                profileSaveMessage = nil
                            }
                            .onLongPressGesture(minimumDuration: 0.45) {
                                Haptics.impact(.medium)
                                pendingDeleteWallpaperProfile = profile
                            }
                            .popover(
                                isPresented: Binding(
                                    get: { pendingDeleteWallpaperProfile?.id == profile.id },
                                    set: { isPresented in
                                        if !isPresented, pendingDeleteWallpaperProfile?.id == profile.id {
                                            pendingDeleteWallpaperProfile = nil
                                        }
                                    }
                                ),
                                attachmentAnchor: .rect(.bounds),
                                arrowEdge: .bottom
                            ) {
                                wallpaperProfileDeletePopover(profile)
                                    .presentationCompactAdaptation(.popover)
                            }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
        }
    }

    private func wallpaperProfileCard(_ profile: WallpaperThemeProfile) -> some View {
        let isSelected = profile.id == viewModel.activeWallpaperProfileID
        let isPendingDelete = profile.id == pendingDeleteWallpaperProfile?.id

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
                .stroke(
                    isPendingDelete ? Color(.systemRed) : (isSelected ? viewModel.primaryColor : Color(.separator).opacity(0.14)),
                    lineWidth: isPendingDelete || isSelected ? 2.5 : 1
                )
        }
        .shadow(color: isPendingDelete ? Color(.systemRed).opacity(0.22) : .clear, radius: 12, y: 5)
        .scaleEffect(isPendingDelete ? 1.06 : (isSelected ? 1 : 0.98))
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: pendingDeleteWallpaperProfile?.id)
    }

    private func wallpaperProfileDeletePopover(_ profile: WallpaperThemeProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loc("Delete Wallpaper Theme?"))
                    .font(.headline.weight(.semibold))
                Text(viewModel.loc("Only this saved wallpaper theme will be deleted."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(viewModel.cancelLabel) {
                    pendingDeleteWallpaperProfile = nil
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    Haptics.warning()
                    pendingDeleteWallpaperProfile = nil
                    viewModel.deleteWallpaperProfile(profile)
                } label: {
                    Label(viewModel.loc("Delete"), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 270)
    }

    private func wallpaperFramePickerPreview(_ image: UIImage, pickerTitle: String) -> some View {
        HStack {
            Spacer(minLength: 0)

            Button {
                Haptics.selection()
                showWallpaperPicker = true
            } label: {
                wallpaperFramePreview(image, actionTitle: pickerTitle)
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzingWallpaper)
            .accessibilityLabel(pickerTitle)

            Spacer(minLength: 0)
        }
    }

    private func wallpaperFramePreview(_ image: UIImage, actionTitle: String) -> some View {
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
                VStack(alignment: .leading, spacing: 9) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(viewModel.cardBoxColor.opacity(0.36 + 0.18 * viewModel.wallpaperPanelOpacityValue))
                        .background(
                            Color(.secondarySystemGroupedBackground).opacity(0.46 + 0.20 * viewModel.wallpaperPanelOpacityValue),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(viewModel.cardBoxColor.opacity(0.34), lineWidth: 1)
                        }
                        .frame(width: 130, height: 34)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(viewModel.cardBoxColor.opacity(0.32 + 0.16 * viewModel.wallpaperPanelOpacityValue))
                        .background(
                            Color(.secondarySystemGroupedBackground).opacity(0.42 + 0.18 * viewModel.wallpaperPanelOpacityValue),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(viewModel.cardBoxColor.opacity(0.30), lineWidth: 1)
                        }
                        .frame(width: 96, height: 24)

                    Label(actionTitle, systemImage: "photo.badge.plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: previewPhoneWidth - 28, alignment: .leading)
                        .background(.black.opacity(0.44), in: Capsule())
                        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                }
                .padding(14)
                .padding(.bottom, 8)
            }
            .frame(width: previewPhoneWidth, height: previewPhoneWidth / phoneAspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
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
        settingsControlRow(
            title: viewModel.fontLabel,
            systemImage: "textformat.size",
            tint: Color(.systemPurple)
        ) {
            Picker("", selection: Binding(
                get: { viewModel.font },
                set: { viewModel.font = $0; savePreferences() }
            )) {
                ForEach(AppFont.allCases, id: \.self) { font in
                    Text(viewModel.loc(font.label)).tag(font)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .tint(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
        }
    }

    private var weekStartPicker: some View {
        settingsControlRow(
            title: viewModel.weekStartsLabel,
            systemImage: "calendar",
            tint: Color(.systemTeal)
        ) {
            Picker("", selection: Binding(
                get: { viewModel.currentBudget?.startOfWeek ?? "sunday" },
                set: { savePreference("start_of_week", $0) }
            )) {
                Text(viewModel.sundayLabel).tag("sunday")
                Text(viewModel.mondayLabel).tag("monday")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .tint(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
        }
    }

    // MARK: - Visible Blocks

    private var visibleBlocksSection: some View {
        Group {
            staticSettingsSection {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.loc("Visible Blocks"))
                            .font(.headline.weight(.semibold))
                        Text(viewModel.loc("Drag to reorder. Tap plus or check to show or hide."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    EditButton()
                        .font(.subheadline.weight(.semibold))
                }
            }

            Section {
                ForEach(viewModel.homeDisplayBlockOrder, id: \.self) { block in
                    homeBlockControlRow(block)
                }
                .onMove(perform: viewModel.moveHomeBlock)
            } header: {
                Text(viewModel.homeTab)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 2, trailing: 18))
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            staticSettingsSection {
                Button {
                    Haptics.selection()
                    viewModel.resetHomeBlockLayout()
                } label: {
                    settingsActionLabel(viewModel.loc("Reset Home Layout"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
            }

            staticSettingsSection(viewModel.activityTab) {
                blockControlRow(.activityFilter, title: viewModel.loc("Filter"))
                settingsDivider()
                blockControlRow(.activitySummary, title: viewModel.loc("Activity Summary"))
            }
            staticSettingsSection(viewModel.goalsTab) {
                blockControlRow(.goalsOverview, title: viewModel.loc("Savings direction"))
            }
            staticSettingsSection(viewModel.aiTab) {
                blockControlRow(.aiIntro, title: viewModel.loc("PennyLet Intelligence"))
                settingsDivider()
                blockControlRow(.aiUsage, title: viewModel.loc("Usage"))
                settingsDivider()
                blockControlRow(.aiHistory, title: viewModel.loc("AI History"))
            }
            staticSettingsSection(viewModel.moreTab) {
                blockControlRow(.moreOverview, title: viewModel.loc("Money cockpit"))
                settingsDivider()
                blockControlRow(.subscriptionsOverview, title: viewModel.loc("Active Subscriptions"))
                settingsDivider()
                blockControlRow(.subscriptionsSuggestions, title: viewModel.loc("Suggested subscriptions"))
                settingsDivider()
                blockControlRow(.budgetOverview, title: viewModel.loc("Budget Overview"))
                settingsDivider()
                blockControlRow(.budgetCategories, title: viewModel.loc("Spending by Category"))
                settingsDivider()
                blockControlRow(.budgetIncomeChart, title: viewModel.loc("Income vs Spending"))
                settingsDivider()
                blockControlRow(.budgetKeyNumbers, title: viewModel.loc("Key numbers"))
            }
        }
    }

    private func homeBlockControlRow(_ block: AppDisplayBlock) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .frame(width: 22)

            Image(systemName: blockIcon(block))
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(viewModel.primaryColor.opacity(viewModel.isBlockVisible(block) ? 0.95 : 0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(blockTitle(block))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Spacer()

            Button {
                Haptics.selection()
                viewModel.setBlock(block, visible: !viewModel.isBlockVisible(block))
            } label: {
                Image(systemName: viewModel.isBlockVisible(block) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.isBlockVisible(block) ? viewModel.primaryColor : viewModel.primaryColor.opacity(0.72))
                    .frame(width: 42, height: 42)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isBlockVisible(block) ? viewModel.loc("Hide") : viewModel.loc("Show"))
        }
        .padding(.vertical, 12)
    }

    private func blockControlRow(_ block: AppDisplayBlock, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: blockIcon(block))
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(viewModel.primaryColor.opacity(viewModel.isBlockVisible(block) ? 0.95 : 0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer()
            Button {
                Haptics.selection()
                viewModel.setBlock(block, visible: !viewModel.isBlockVisible(block))
            } label: {
                Image(systemName: viewModel.isBlockVisible(block) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.isBlockVisible(block) ? viewModel.primaryColor : viewModel.primaryColor.opacity(0.72))
                    .frame(width: 42, height: 42)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }

    private func blockTitle(_ block: AppDisplayBlock) -> String {
        switch block {
        case .homeSafeToSpend: return viewModel.loc("Safe Until Payday")
        case .homeMonthlyPulse: return viewModel.loc("Monthly pulse")
        case .homeReviewQueue: return viewModel.loc("Review Queue")
        case .homeWatchlists: return viewModel.loc("Watchlists")
        case .homeTopCategories: return viewModel.loc("Top Categories")
        case .homeRecentActivity: return viewModel.loc("Recent Activity")
        default: return block.rawValue
        }
    }

    private func blockIcon(_ block: AppDisplayBlock) -> String {
        switch block {
        case .homeSafeToSpend: return "calendar.badge.clock"
        case .homeMonthlyPulse: return "chart.bar.fill"
        case .homeReviewQueue: return "checklist.checked"
        case .homeWatchlists: return "eye.circle.fill"
        case .homeTopCategories, .budgetCategories: return "tag.fill"
        case .homeRecentActivity: return "clock.arrow.circlepath"
        case .activityFilter: return "line.3.horizontal.decrease.circle"
        case .activitySummary: return "sum"
        case .goalsOverview: return "target"
        case .aiIntro: return "sparkles"
        case .aiUsage: return "gauge.with.dots.needle.67percent"
        case .aiHistory: return "clock.fill"
        case .moreOverview: return "square.grid.2x2"
        case .subscriptionsOverview: return "repeat.circle.fill"
        case .subscriptionsSuggestions: return "sparkle.magnifyingglass"
        case .budgetOverview: return "chart.pie.fill"
        case .budgetIncomeChart: return "arrow.up.arrow.down.circle.fill"
        case .budgetKeyNumbers: return "number.circle.fill"
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        settingsSection(viewModel.budgetSection) {
            VStack(alignment: .leading, spacing: 0) {
                settingsGroupCaption(viewModel.loc("Monthly plan"))
                budgetAmountRow(
                    title: viewModel.loc("Monthly income"),
                    description: viewModel.loc("Usual take-home pay each month."),
                    text: $incomeText
                )
                settingsDivider()
                budgetAmountRow(
                    title: viewModel.loc("Fixed bills"),
                    description: viewModel.loc("Rent, utilities, subscriptions, and must-pay costs."),
                    text: $essentialsText
                )
                settingsDivider()
                budgetAmountRow(
                    title: viewModel.loc("Money to save"),
                    description: viewModel.loc("Money to protect each month."),
                    text: $savingsText
                )

                settingsGroupCaption(viewModel.loc("Pay schedule"))
                    .padding(.top, 14)
                paydaySelectionRow
                settingsDivider()
                payRhythmPicker

                settingsGroupCaption(viewModel.loc("Today snapshot"))
                    .padding(.top, 14)
                budgetAmountRow(
                    title: viewModel.loc("Today's money"),
                    description: viewModel.loc("Money in your bank/checking today."),
                    text: $currentSpendableText
                )
                settingsDivider()
                budgetAmountRow(
                    title: viewModel.loc("Cash"),
                    description: viewModel.loc("Cash you want PennyLet to count."),
                    text: $cashOnHandText
                )
                settingsDivider()
                budgetAmountRow(
                    title: viewModel.loc("Keep untouched"),
                    description: viewModel.loc("Savings or buffer money to protect."),
                    text: $keepUntouchedText
                )
                settingsDivider()
                budgetAmountRow(
                    title: viewModel.loc("Next paycheck"),
                    description: viewModel.loc("Leave blank to use monthly income."),
                    text: $nextIncomeAmountText
                )
            }
        }
        .onAppear {
            if let budget = viewModel.currentBudget {
                populateBudgetFields(from: budget)
            }
        }
        .onChange(of: viewModel.currentBudget?.id) { _, _ in
            if let budget = viewModel.currentBudget {
                populateBudgetFields(from: budget)
            }
        }
    }

    private func settingsGroupCaption(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.bottom, 6)
            .padding(.top, 2)
    }

    private func budgetAmountRow(
        title: String,
        description: String,
        text: Binding<String>
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Text(currencyInputLabel)
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                TextField(title, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.headline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .padding(.vertical, 13)
        .onChange(of: text.wrappedValue) { _, _ in scheduleBudgetSave() }
    }

    private var currencyInputLabel: String {
        CurrencyFormat.currencySymbol(for: viewModel.currency)
    }

    private var paydaySelectionRow: some View {
        Button {
            draftPayDayVal = payDayVal
            showPayDayPicker = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.loc("Payday"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(viewModel.loc("Choose the day of the month your pay usually arrives."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    Text("\(payDayVal)")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var payRhythmPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Pay rhythm"))
                .font(.body)
                .foregroundStyle(.primary)
            Picker(viewModel.loc("Pay rhythm"), selection: $incomeCadenceVal) {
                ForEach(["weekly", "biweekly", "semimonthly", "monthly"], id: \.self) { cadence in
                    Text(viewModel.loc(cadence)).tag(cadence)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: incomeCadenceVal) { _, _ in saveBudgetNow() }
        }
        .padding(.vertical, 10)
    }

    private var paydayPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(viewModel.loc("Choose payday"))
                    .font(.headline.weight(.semibold))
                    .padding(.top, 6)

                Picker(viewModel.loc("Payday"), selection: $draftPayDayVal) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(.horizontal, 20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelLabel) {
                        showPayDayPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.loc("Done")) {
                        commitPaydaySelection()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func commitPaydaySelection() {
        payDayVal = draftPayDayVal
        nextIncomeDateVal = nextPaydayDate(day: draftPayDayVal)
        saveBudgetNow()
        showPayDayPicker = false
        Haptics.selection()
    }

    private func nextPaydayDate(day: Int, from today: Date = Date(), calendar: Calendar = .current) -> Date {
        let safeDay = min(max(day, 1), 31)
        var components = calendar.dateComponents([.year, .month], from: today)
        let daysInCurrentMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        components.day = min(safeDay, daysInCurrentMonth)

        if let candidate = calendar.date(from: components), candidate >= calendar.startOfDay(for: today) {
            return candidate
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) else {
            return today
        }
        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        let nextDays = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 30
        nextComponents.day = min(safeDay, nextDays)
        return calendar.date(from: nextComponents) ?? today
    }

    private func populateBudgetFields(from budget: Budget) {
        incomeText = String(format: "%.0f", budget.monthlyIncome)
        essentialsText = budget.monthlyEssentials.map { String(format: "%.0f", $0) } ?? ""
        savingsText = budget.monthlySavingsGoal.map { String(format: "%.0f", $0) } ?? ""
        payDayVal = budget.payDay ?? 1
        draftPayDayVal = budget.payDay ?? 1
        currentSpendableText = budget.currentSpendableBalance.map { String(format: "%.0f", $0) } ?? ""
        cashOnHandText = budget.cashOnHand.map { String(format: "%.0f", $0) } ?? ""
        keepUntouchedText = budget.moneyToKeepUntouched.map { String(format: "%.0f", $0) } ?? ""
        nextIncomeAmountText = budget.nextIncomeAmount.map { String(format: "%.0f", $0) } ?? ""
        nextIncomeDateVal = budget.nextIncomeDate.flatMap(AppViewModel.dateFromStoredString) ?? Date()
        incomeCadenceVal = budget.incomeCadence ?? "monthly"
    }

    private var goalQuickAddSection: some View {
        settingsSection(viewModel.loc("Goal Quick Add")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.loc("Set the four amounts that appear on goal cards."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(0..<4, id: \.self) { index in
                    goalQuickAddRow(index: index)
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            syncGoalQuickAddTexts()
        }
    }

    private func goalQuickAddRow(index: Int) -> some View {
        HStack(spacing: 14) {
            Text("\(index + 1)")
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(.systemIndigo), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.loc("Quick amount")) \(index + 1)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(viewModel.loc("Goal deposit shortcut"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(currencyInputLabel)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                TextField(
                    viewModel.amountLabel,
                    text: Binding(
                        get: { goalQuickAddText(at: index) },
                        set: { updateGoalQuickAddText($0, at: index) }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.headline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(width: 90)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func goalQuickAddText(at index: Int) -> String {
        if goalQuickAddTexts.indices.contains(index) {
            return goalQuickAddTexts[index]
        }
        if viewModel.goalQuickAddAmounts.indices.contains(index) {
            return cleanAmountText(viewModel.goalQuickAddAmounts[index])
        }
        return ""
    }

    private func updateGoalQuickAddText(_ value: String, at index: Int) {
        while goalQuickAddTexts.count < 4 {
            let fallbackIndex = goalQuickAddTexts.count
            let fallback = viewModel.goalQuickAddAmounts.indices.contains(fallbackIndex)
                ? viewModel.goalQuickAddAmounts[fallbackIndex]
                : 0
            goalQuickAddTexts.append(cleanAmountText(fallback))
        }
        goalQuickAddTexts[index] = value
        if let amount = CurrencyFormat.parseInput(value), amount > 0 {
            viewModel.setGoalQuickAddAmount(at: index, amount: amount)
        }
    }

    private func syncGoalQuickAddTexts() {
        goalQuickAddTexts = viewModel.goalQuickAddAmounts.map(cleanAmountText)
    }

    private func cleanAmountText(_ amount: Double) -> String {
        amount.rounded() == amount ? String(format: "%.0f", amount) : String(amount)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        settingsSection(viewModel.preferencesSection) {
            settingsControlRow(
                title: viewModel.currencyLabel,
                systemImage: "banknote.fill",
                tint: Color(.systemGreen)
            ) {
                Picker("", selection: Binding(
                    get: { viewModel.currency },
                    set: { viewModel.currency = $0; savePreferences() }
                )) {
                    ForEach(currencies, id: \.self) { c in
                        Text("\(c) \(CurrencyFormat.currencySymbol(for: c))").tag(c)
                    }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .tint(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
        }
        settingsDivider()
        settingsControlRow(
                title: viewModel.languageLabel,
                systemImage: "globe",
                tint: Color(.systemTeal)
            ) {
                Picker("", selection: Binding(
                    get: { viewModel.language },
                    set: { viewModel.language = $0; savePreferences() }
                )) {
                    ForEach(languages, id: \.self) { code in
                        Text(viewModel.languageDisplayName(for: code)).tag(code)
                    }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .tint(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule(style: .continuous))
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
                    Text(viewModel.loc("Auto Analysis runs at the times you choose."))
                }
        }
    }

    private var analysisSettingsSection: some View {
        settingsSection(viewModel.analysisSectionLabel) {
            HStack(spacing: 12) {
                Toggle(viewModel.autoAnalysisLabel, isOn: Binding(
                    get: { viewModel.currentBudget?.autoAnalysisEnabled ?? false },
                    set: { savePreference("auto_analysis_enabled", $0) }
                ))

                Button {
                    showAutoAnalysisHelp = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(viewModel.primaryColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.loc("Auto Analysis Help"))
            }

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

            settingsDivider()

            Button {
                Haptics.selection()
                viewModel.clearSavedInsights()
            } label: {
                settingsActionLabel(
                    viewModel.loc("Clear saved insights"),
                    systemImage: "sparkles.slash",
                    tint: Color(.systemPurple)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        staticSettingsSection(viewModel.dataSectionLabel) {
            Button {
                pendingResetAfterExport = false
                showFileNamePrompt = true
            } label: {
                settingsActionLabel(isExporting ? viewModel.loc("Preparing export...") : viewModel.exportCSVLabel, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            settingsDivider()

            Button {
                showCSVImport = true
            } label: {
                settingsActionLabel(viewModel.loc("Import CSV"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            settingsDivider()

            Button {
                Task {
                    await viewModel.refreshExchangeRates()
                    ratesRefreshed = true
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    ratesRefreshed = false
                }
            } label: {
                settingsActionLabel(
                    ratesRefreshed ? viewModel.loc("Exchange rates updated") : viewModel.loc("Refresh Exchange Rates"),
                    systemImage: ratesRefreshed ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                )
            }
            .buttonStyle(.plain)
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
        staticSettingsSection {
            Button {
                registerDeveloperTap()
            } label: {
                HStack(spacing: 12) {
                    settingsActionLabel(viewModel.appVersionLabel, systemImage: "info.circle")
                    Spacer()
                    Text(appVersionString)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            settingsDivider()

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                settingsActionLabel(isExporting ? viewModel.loc("Preparing export...") : viewModel.loc("Export & Reset"), systemImage: "arrow.counterclockwise", tint: Color(.systemRed))
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
    }

    private var developerSection: some View {
        settingsSection(viewModel.developerToolsLabel) {
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
        staticSettingsSection(viewModel.loc("Legal")) {
            Link(destination: URL(string: "https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf")!) {
                settingsActionLabel(viewModel.loc("Privacy Policy"), systemImage: "hand.raised.fill")
            }
            .buttonStyle(.plain)
            settingsDivider()

            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                settingsActionLabel(viewModel.loc("Terms of Use (EULA)"), systemImage: "doc.text.fill")
            }
            .buttonStyle(.plain)
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
        let essentials = CurrencyFormat.parseInput(essentialsText) ?? 0
        let savings = CurrencyFormat.parseInput(savingsText) ?? 0
        // Only update the budget fields that changed; updateBudgetLocally preserves nil fields
        viewModel.updateBudgetLocally(BudgetData(
            monthlyIncome: income,
            monthlyEssentials: essentials,
            monthlySavingsGoal: savings,
            payDay: payDayVal,
            startDate: viewModel.currentBudget?.startDate ?? AppViewModel.storedDateString(from: Date()),
            currentSpendableBalance: CurrencyFormat.parseInput(currentSpendableText) ?? 0,
            cashOnHand: CurrencyFormat.parseInput(cashOnHandText) ?? 0,
            moneyToKeepUntouched: CurrencyFormat.parseInput(keepUntouchedText) ?? 0,
            billsDueBeforeNextIncome: essentials,
            savingsDueBeforeNextIncome: savings,
            nextIncomeDate: AppViewModel.storedDateString(from: nextIncomeDateVal),
            nextIncomeAmount: CurrencyFormat.parseInput(nextIncomeAmountText) ?? income,
            incomeCadence: incomeCadenceVal
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

    private func openCurrentWallpaperCrop() {
        guard let data = viewModel.wallpaperImageData,
              let image = viewModel.wallpaperUIImage else { return }
        pendingWallpaperCrop = WallpaperCropSource(
            imageData: data,
            image: image,
            updatesCurrentProfile: true,
            initialZoomPercent: viewModel.wallpaperZoomPercent,
            initialHorizontalFrame: viewModel.wallpaperHorizontalFrame,
            initialVerticalFrame: viewModel.wallpaperVerticalFrame
        )
    }

    private func applyWallpaperCrop(
        _ result: WallpaperCropResult,
        updatesCurrentProfile: Bool
    ) async {
        isAnalyzingWallpaper = true
        wallpaperError = nil
        defer { isAnalyzingWallpaper = false }

        if updatesCurrentProfile {
            viewModel.updateCurrentWallpaperCrop(
                zoomPercent: result.zoomPercent,
                horizontalFrame: result.horizontalFrame,
                verticalFrame: result.verticalFrame
            )
            profileSaveMessage = viewModel.loc("Profile saved")
            Haptics.success()
            return
        }

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
        guard !isExporting else { return }
        isExporting = true
        let transactions = viewModel.transactions
        let header = viewModel.loc("Date,Type,Category,Amount,Note,Merchant,OriginalCurrency,OriginalAmount,ExchangeRate")
        let fileName = sanitizedExportFileName(exportFileName)
        exportFileName = fileName

        Task {
            await Task.yield()
            var csv = header + "\n"
            for tx in transactions {
                let note = (tx.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let merchant = (tx.merchant ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let category = (tx.category ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let origCur = tx.originalCurrency ?? ""
                let origAmt = tx.originalAmount.map { String(format: "%.2f", $0) } ?? ""
                let xrate = tx.exchangeRate.map { String(format: "%.4f", $0) } ?? ""
                csv += "\(tx.date),\(tx.type.rawValue),\"\(category)\",\(tx.amount),\"\(note)\",\"\(merchant)\",\(origCur),\(origAmt),\(xrate)\n"
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).csv")
            try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportItem = ExportShareItem(url: tempURL)
            isExporting = false
        }
    }

    private func resetAfterExport() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            await Task.yield()
            viewModel.restoreDefaults()
            isExporting = false
        }
    }

    private func sanitizedExportFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "pennylet_export" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback.components(separatedBy: invalid).joined(separator: "-")
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
        let count = viewModel.importTransactionsCSV(content: content)
        importResult = count > 0 ? (true, count) : (false, 0)
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            importResult = nil
        }
    }
}

struct WallpaperImageSurface: View {
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

struct WallpaperCropEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let source: WallpaperCropSource
    let onSave: (WallpaperCropResult) -> Void

    @State private var zoomPercent: Double
    @State private var horizontalFrame: Double
    @State private var verticalFrame: Double
    @State private var dragStartHorizontal: Double?
    @State private var dragStartVertical: Double?
    @State private var zoomStartPercent: Double?

    init(source: WallpaperCropSource, onSave: @escaping (WallpaperCropResult) -> Void) {
        self.source = source
        self.onSave = onSave
        _zoomPercent = State(initialValue: source.initialZoomPercent)
        _horizontalFrame = State(initialValue: source.initialHorizontalFrame)
        _verticalFrame = State(initialValue: source.initialVerticalFrame)
    }

    private var phoneAspectRatio: CGFloat {
        let size = UIScreen.main.bounds.size
        let shortSide = max(1, min(size.width, size.height))
        let longSide = max(shortSide, max(size.width, size.height))
        return shortSide / longSide
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(viewModel.loc("Pinch and drag to frame it."))
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
