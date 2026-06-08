import SwiftUI

struct WelcomeView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var step = 0
    @State private var monthlyIncome = ""
    @State private var currentSpendableBalance = ""
    @State private var cashOnHand = ""
    @State private var moneyToKeepUntouched = ""
    @State private var billsBeforePayday = ""
    @State private var monthlySavings = ""
    @State private var nextPaycheckAmount = ""
    @State private var nextPaydayDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var incomeCadence = "monthly"
    @State private var payDay = 1
    @State private var selectedCurrency = "USD"
    @State private var selectedLanguage = "en"
    @State private var selectedTheme: AppTheme = .sage
    @State private var selectedColorMode: AppColorMode = .system
    @State private var selectedFont: AppFont = .inter
    @State private var isSaving = false
    @State private var onboardingError: String?
    @State private var showCSVImport = false
    @State private var csvImportResult: (success: Bool, count: Int)?
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "HKD", "SGD", "KRW", "BRL"]
    private let languages = ["en", "ja", "zh"]
    private let incomeCadences = ["weekly", "biweekly", "semimonthly", "monthly"]

    private var setupPrimaryText: Color { Color(.label) }
    private var setupSecondaryText: Color { Color(.secondaryLabel) }
    private var setupTertiaryText: Color { Color(.tertiaryLabel) }
    private var setupBackground: Color { Color(.systemGroupedBackground) }
    private var setupPanelBackground: Color { Color(.secondarySystemGroupedBackground) }
    private var setupAccent: Color { viewModel.primaryColor }

    var body: some View {
        VStack {
            TabView(selection: $step) {
                splashStep.tag(0)
                preferencesStep.tag(1)
                todaySnapshotStep.tag(2)
                rhythmStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            setupPageIndicator

            if let error = onboardingError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let csvImportResult {
                importStatusBanner(csvImportResult)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
                if step > 0 {
                    Button(viewModel.loc("Back")) { withAnimation { step -= 1 } }
                }
                Spacer()
                Button(step == 3 ? (isSaving ? viewModel.loc("Saving...") : viewModel.loc("Get Started")) : viewModel.loc("Next")) {
                    if step == 3 {
                        saveAndContinue()
                    } else {
                        onboardingError = nil
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .background(setupBackground.ignoresSafeArea())
        .foregroundStyle(setupPrimaryText)
        .tint(setupAccent)
    }

    private var setupPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == step ? setupAccent : setupTertiaryText.opacity(0.30))
                    .frame(width: index == step ? 8 : 7, height: index == step ? 8 : 7)
                    .animation(.spring(response: 0.25, dampingFraction: 0.82), value: step)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .accessibilityHidden(true)
    }

    private var splashStep: some View {
        VStack(spacing: 20) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(viewModel.loc("Welcome to PennyLet"))
                .font(.title.weight(.bold))
            Text(viewModel.loc("Start today. No bank import needed."))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(setupPrimaryText)
                .padding(.horizontal, 36)

            Text(viewModel.loc("Tell PennyLet what you have now. It helps from here."))
                .multilineTextAlignment(.center)
                .foregroundStyle(setupSecondaryText)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                splashPromiseRow(icon: "lock.fill", title: viewModel.loc("No bank login"))
                splashPromiseRow(icon: "clock.badge.checkmark", title: viewModel.loc("No old cleanup"))
                splashPromiseRow(icon: "checkmark.seal.fill", title: viewModel.loc("Explainable local numbers"))
            }
            .padding(.horizontal, 34)

            Picker(viewModel.loc("Language"), selection: $selectedLanguage) {
                ForEach(languages, id: \.self) { code in
                    Text(viewModel.languageDisplayName(for: code)).tag(code)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            .onChange(of: selectedLanguage) { _, new in
                viewModel.language = new
                viewModel.savePreferencesToDisk()
            }

            Button {
                showCSVImport = true
            } label: {
                Label(viewModel.loc("Have a CSV? Import it."), systemImage: "square.and.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(setupPrimaryText)
            }

            Text(viewModel.loc("Optional. You can start without old data."))
                .font(.caption2)
                .foregroundStyle(setupTertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .fileImporter(isPresented: $showCSVImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result {
                importCSV(from: url)
            }
        }
        .alert(csvImportResult?.success == true ? viewModel.loc("Import Successful") : viewModel.loc("Import Failed"), isPresented: Binding(
            get: { csvImportResult != nil },
            set: { if !$0 { csvImportResult = nil } }
        )) {
            Button(viewModel.loc("OK"), role: .cancel) {}
        } message: {
            if let r = csvImportResult, r.success {
                Text("\(viewModel.loc("Imported")) \(r.count) \(viewModel.loc("transactions successfully."))")
            } else {
                Text(viewModel.loc("The file could not be read. Check the format and try again."))
            }
        }
    }

    private func splashPromiseRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(setupAccent)
                .frame(width: 26, height: 26)
                .background(setupAccent.opacity(0.10), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(setupPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(setupPanelBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var todaySnapshotStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.loc("What do you have today?"))
                        .font(.title2.weight(.bold))
                    Text(viewModel.loc("Use what you have right now. Payday does not need to match."))
                        .font(.subheadline)
                        .foregroundStyle(setupSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                preferenceSection(viewModel.loc("Currency")) {
                    Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(currencyPickerLabel(c)).tag(c)
                        }
                    }
                    .onChange(of: selectedCurrency) { _, new in
                        viewModel.currency = new
                        viewModel.savePreferencesToDisk()
                    }
                }

                labeledField(viewModel.loc("Spendable balance today"), value: $currentSpendableBalance, icon: "banknote.fill", hint: viewModel.loc("Money you can use before payday, like checking."))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Cash in pocket"), value: $cashOnHand, icon: "wallet.pass.fill", hint: viewModel.loc("Cash you physically have, like money in your wallet."))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Keep untouched"), value: $moneyToKeepUntouched, icon: "lock.fill", hint: viewModel.loc("Money to protect, like emergency savings."))
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var rhythmStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.loc("What is coming next?"))
                        .font(.title2.weight(.bold))
                    Text(viewModel.loc("This connects today to payday."))
                        .font(.subheadline)
                        .foregroundStyle(setupSecondaryText)
                }

                labeledField(viewModel.loc("Normal monthly income"), value: $monthlyIncome, icon: "arrow.down.forward", hint: viewModel.loc("Your usual take-home for a full month."))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Next paycheck amount"), value: $nextPaycheckAmount, icon: "calendar.badge.plus", hint: viewModel.loc("Leave blank to use monthly income."))
                    .keyboardType(.decimalPad)

                DatePicker(viewModel.loc("Next payday"), selection: $nextPaydayDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .onChange(of: nextPaydayDate) { _, newDate in
                        payDay = Calendar.current.component(.day, from: newDate)
                    }

                Picker(viewModel.loc("Pay rhythm"), selection: $incomeCadence) {
                    ForEach(incomeCadences, id: \.self) { cadence in
                        Text(viewModel.loc(cadence)).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)

                labeledField(viewModel.loc("Bills before payday"), value: $billsBeforePayday, icon: "house.fill", hint: viewModel.loc("Bills due before payday, like rent or subscriptions."))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Save before payday"), value: $monthlySavings, icon: "target", hint: viewModel.loc("Money to set aside before payday."))
                    .keyboardType(.decimalPad)

                onboardingNote(
                    icon: "calendar.badge.clock",
                    text: viewModel.loc("After payday, PennyLet uses your normal rhythm.")
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var preferencesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.loc("Make PennyLet yours"))
                        .font(.title2.weight(.bold))
                    Text(viewModel.loc("Pick the basics now. You can customize wallpaper later."))
                        .font(.subheadline)
                        .foregroundStyle(setupSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                preferenceSection(viewModel.loc("Theme")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: selectedTheme == theme ? 2 : 0)
                                            )
                                        Text(viewModel.loc(theme.label))
                                            .font(.caption2)
                                            .foregroundStyle(setupSecondaryText)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.75)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: 60)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                preferenceSection(viewModel.loc("Appearance")) {
                    Picker(viewModel.loc("Color Mode"), selection: $selectedColorMode) {
                        ForEach(AppColorMode.allCases, id: \.self) { mode in
                            Text(viewModel.loc(mode.label)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(viewModel.loc("Font"), selection: $selectedFont) {
                        ForEach(AppFont.allCases, id: \.self) { font in
                            Text(viewModel.loc(font.label)).tag(font)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                onboardingNote(
                    icon: "photo.on.rectangle.angled",
                    text: viewModel.loc("Wallpaper themes live in Settings, so setup stays quick.")
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onChange(of: selectedTheme) { _, new in
            viewModel.theme = new
            viewModel.savePreferencesToDisk()
        }
        .onChange(of: selectedColorMode) { _, new in
            viewModel.colorMode = new
            viewModel.savePreferencesToDisk()
        }
        .onChange(of: selectedFont) { _, new in
            viewModel.font = new
            viewModel.savePreferencesToDisk()
        }
    }

    private func preferenceSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(setupPrimaryText)
            content()
        }
    }

    private func labeledField(_ label: String, value: Binding<String>, icon: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Label(label, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(setupPrimaryText)
                Text("(\(hint))")
                    .font(.caption2)
                    .foregroundStyle(setupSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Text(CurrencyFormat.currencySymbol(for: selectedCurrency))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(setupSecondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                TextField(viewModel.loc("Amount"), text: value)
                    .font(.title3)
                    .foregroundStyle(setupPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(12)
            .background(setupPanelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func currencyPickerLabel(_ code: String) -> String {
        "\(code) \(CurrencyFormat.currencySymbol(for: code))"
    }

    private func importStatusBanner(_ result: (success: Bool, count: Int)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.success ? Color(.systemGreen) : Color(.systemOrange))
            Text(result.success
                 ? "\(viewModel.loc("Imported")) \(result.count) \(viewModel.loc("transactions successfully."))"
                 : viewModel.loc("The file could not be read. Check the format and try again."))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(setupPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(setupPanelBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((result.success ? Color(.systemGreen) : Color(.systemOrange)).opacity(0.24), lineWidth: 1)
        }
    }

    private func onboardingNote(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(setupAccent)
                .frame(width: 24, height: 24)
            Text(text)
                .font(.footnote)
                .foregroundStyle(setupSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(setupPanelBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            csvImportResult = (false, 0)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            csvImportResult = (false, 0)
            return
        }
        let count = viewModel.importTransactionsCSV(content: content)
        csvImportResult = count > 0 ? (true, count) : (false, 0)
    }

    private func saveAndContinue() {
        guard let income = CurrencyFormat.parseInput(monthlyIncome), income > 0 else {
            onboardingError = viewModel.loc("Please enter a valid monthly income")
            return
        }
        onboardingError = nil
        isSaving = true
        Task {
            let localBudget = Budget(
                id: UUID().uuidString,
                monthlyIncome: income,
                monthlyEssentials: CurrencyFormat.parseInput(billsBeforePayday),
                monthlySavingsGoal: CurrencyFormat.parseInput(monthlySavings),
                payDay: Calendar.current.component(.day, from: nextPaydayDate),
                startDate: AppViewModel.storedDateString(from: Date()),
                currentSpendableBalance: CurrencyFormat.parseInput(currentSpendableBalance) ?? 0,
                cashOnHand: CurrencyFormat.parseInput(cashOnHand) ?? 0,
                moneyToKeepUntouched: CurrencyFormat.parseInput(moneyToKeepUntouched) ?? 0,
                billsDueBeforeNextIncome: CurrencyFormat.parseInput(billsBeforePayday) ?? 0,
                savingsDueBeforeNextIncome: CurrencyFormat.parseInput(monthlySavings) ?? 0,
                nextIncomeDate: AppViewModel.storedDateString(from: nextPaydayDate),
                nextIncomeAmount: CurrencyFormat.parseInput(nextPaycheckAmount) ?? income,
                incomeCadence: incomeCadence,
                currency: selectedCurrency,
                language: selectedLanguage,
                theme: selectedTheme.rawValue,
                colorMode: selectedColorMode.rawValue,
                font: selectedFont.rawValue,
                createdDate: ISO8601DateFormatter().string(from: Date()),
                updatedDate: ISO8601DateFormatter().string(from: Date())
            )
            await MainActor.run {
                viewModel.budgets = [localBudget]
                viewModel.saveLocalData()
                viewModel.savePreferencesToDisk()
                isSaving = false
            }
        }
    }
}

extension AppViewModel {
    func applyBudgetPreferencesFromBudget(_ budget: Budget) {
        if let t = budget.theme, let appTheme = AppTheme(rawValue: t) { theme = appTheme }
        if let cm = budget.colorMode, let mode = AppColorMode(rawValue: cm) { colorMode = mode }
        if let f = budget.font, let appFont = AppFont(rawValue: f) { font = appFont }
        if let c = budget.currency { currency = c }
        if let l = budget.language { language = l }
    }
}
