import SwiftUI

struct AddTransactionView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private let startAsSubscription: Bool

    @State private var type: Transaction.TransactionType = .expense
    @State private var amount = ""
    @State private var category = "food"
    @State private var note = ""
    @State private var date = Date()
    @State private var isSaving = false
    @FocusState private var isAmountFocused: Bool
    @State private var showReceiptScanner = false
    @State private var newCategoryName = ""
    @State private var showCustomCategoryField = false
    @State private var selectedCurrency = "native"
    @State private var convertedAmount: Double?
    @State private var conversionRate: Double?
    @State private var isConverting = false
    @State private var conversionError: String?
    @State private var isSubscription = false
    @State private var billingInterval: RecurringSubscription.BillingInterval = .monthly
    @State private var customIntervalDays = 30

    init(startAsSubscription: Bool = false) {
        self.startAsSubscription = startAsSubscription
        _isSubscription = State(initialValue: startAsSubscription)
        _category = State(initialValue: startAsSubscription ? "subscriptions" : "food")
    }

    private var datePickerLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }

    private var categoryList: [AppCategory] {
        var list = type == .income ? AppCategory.incomeCategories : AppCategory.expenseCategories
        if let customs = viewModel.currentBudget?.customCategories {
            for name in customs {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let normalized = AppCategory.customCategoryID(for: trimmed)
                guard !list.contains(where: { $0.id == normalized || $0.id == trimmed || $0.label.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else {
                    continue
                }
                list.append(AppCategory(id: trimmed, label: trimmed, icon: "tag.fill", color: .teal))
            }
        }
        return list
    }

    private var isValid: Bool {
        (parsedAmount ?? 0) > 0
    }

    private var parsedAmount: Double? {
        CurrencyFormat.parseInput(amount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    typeToggle
                    amountField
                    quickAmountChips
                    currencySelector
                    conversionPreview
                    quickActions
                    categoryGrid
                    if isSubscription {
                        subscriptionDetails
                            .transition(.foldReveal)
                    }
                    noteAndDate
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
            .navigationTitle(viewModel.addTransactionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton(viewModel.loc("Done"))
            .environment(\.locale, datePickerLocale)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        toolbarGlassLabel(viewModel.cancelLabel, tint: .secondary)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 62, height: 34)
                                .background(.regularMaterial, in: Capsule())
                        } else {
                            toolbarGlassLabel(viewModel.saveLabel, tint: type == .income ? .green : viewModel.primaryColor, isPrimary: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                isAmountFocused = true
                if startAsSubscription {
                    type = .expense
                    category = "subscriptions"
                }
            }
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerView { resultAmount, resultCategory, resultMerchant in
                if let amt = resultAmount { amount = String(format: "%.2f", amt) }
                if let cat = resultCategory { category = cat }
                if let merch = resultMerchant { note = merch }
                showReceiptScanner = false
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                showReceiptScanner = true
            } label: {
                Label(viewModel.scanReceiptLabel, systemImage: "doc.text.viewfinder")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isSubscription.toggle()
                    if isSubscription {
                        type = .expense
                        category = "subscriptions"
                    }
                }
            } label: {
                Label(viewModel.loc("Subscription"), systemImage: isSubscription ? "repeat.circle.fill" : "repeat")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(isSubscription ? .white : .primary)
                    .background(
                        isSubscription ? viewModel.primaryColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.primaryColor.opacity(isSubscription ? 0 : 0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Existing Views

    private var typeToggle: some View {
        HStack(spacing: 0) {
            ForEach([Transaction.TransactionType.expense, .income], id: \.self) { t in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        type = t
                        category = t == .income ? "salary" : "food"
                        if t == .income {
                            isSubscription = false
                        }
                    }
                } label: {
                    Label(
                        t == .income ? viewModel.incomeLabel : viewModel.expenseLabel,
                        systemImage: t == .income ? "arrow.down.forward" : "arrow.up.forward"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        type == t
                            ? (t == .income ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .foregroundStyle(type == t ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var amountField: some View {
        VStack(spacing: 10) {
            Text(viewModel.amountLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormat.currencySymbol(for: selectedCurrency == "native" ? viewModel.currency : selectedCurrency))
                    .font(.system(size: 36, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .premiumPanel(tint: type == .income ? .green : viewModel.primaryColor)
    }

    private var quickAmountChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Quick amounts"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(quickAmountValues, id: \.self) { value in
                    Button {
                        Haptics.selection()
                        amount = cleanAmountText(value)
                        if selectedCurrency != "native" {
                            Task { await performConversion() }
                        }
                    } label: {
                        Text("\(CurrencyFormat.currencySymbol(for: selectedCurrency == "native" ? viewModel.currency : selectedCurrency))\(cleanAmountText(value))")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background((type == .income ? Color.green : viewModel.primaryColor).opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickAmountValues: [Double] {
        let code = selectedCurrency == "native" ? viewModel.currency : selectedCurrency
        switch code {
        case "JPY", "KRW":
            return [500, 1000, 3000, 5000]
        case "CNY", "HKD", "TWD":
            return [20, 50, 100, 200]
        default:
            return [5, 10, 25, 50]
        }
    }

    private func cleanAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private var currencySelector: some View {
        VStack(spacing: 8) {
            Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                Text("\(viewModel.currency) \(CurrencyFormat.currencySymbol(for: viewModel.currency))").tag("native")
                ForEach(CurrencyRateService.supportedCurrencies, id: \.code) { cur in
                    if cur.code != viewModel.currency {
                        Text("\(cur.code) \(CurrencyFormat.currencySymbol(for: cur.code))").tag(cur.code)
                    }
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedCurrency) { _, _ in
                Task { await performConversion() }
            }
            .onChange(of: amount) { _, _ in
                if selectedCurrency != "native" {
                    Task { await performConversion() }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var conversionPreview: some View {
        if let converted = convertedAmount, let rate = conversionRate, selectedCurrency != "native", let value = parsedAmount {
            VStack(spacing: 4) {
                if isConverting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(viewModel.loc("Converting..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(CurrencyFormat.formatForeign(value, currency: selectedCurrency)) = \(CurrencyFormat.format(converted, currency: viewModel.currency))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(viewModel.loc("Rate")): 1 \(selectedCurrency) = \(String(format: "%.4f", rate)) \(viewModel.currency)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        } else if let error = conversionError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.categoryLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer(minLength: 8)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showCustomCategoryField.toggle()
                    }
                } label: {
                    Label(viewModel.loc(showCustomCategoryField ? "Cancel" : "New Category"), systemImage: showCustomCategoryField ? "xmark" : "plus")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(categoryList) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            category = cat.id
                            showCustomCategoryField = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(category == cat.id ? .white : cat.color)
                                .frame(width: 40, height: 40)
                                .background(
                                    category == cat.id ? cat.color : cat.color.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .scaleEffect(category == cat.id ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: category)
                            Text(viewModel.loc(cat.label))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(category == cat.id ? .primary : .secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 22, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showCustomCategoryField {
                HStack(spacing: 8) {
                    TextField(viewModel.loc("New Category"), text: $newCategoryName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(addCustomCategory)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    Button(viewModel.loc("Add")) {
                        addCustomCategory()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 8))
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let helper = selectedCategoryHelper {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(helper)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var noteAndDate: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField(viewModel.loc(isSubscription ? "Subscription name" : "Note"), text: $note)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
            }

            DatePicker(viewModel.dateLabel, selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private var subscriptionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PennyLetIconTile(symbol: "repeat.circle.fill", tint: Color(.systemTeal), size: 32, symbolScale: 0.42, shape: .capsule)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.loc("Track as subscription"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(viewModel.loc("Future charges will be added automatically."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer()
            }

            Menu {
                ForEach(RecurringSubscription.BillingInterval.allCases, id: \.self) { interval in
                    Button(billingIntervalTitle(interval)) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            billingInterval = interval
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.loc("Billing period"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(billingIntervalTitle(billingInterval))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if billingInterval == .custom {
                Stepper(
                    "\(viewModel.loc("Every")) \(customIntervalDays) \(viewModel.loc("days"))",
                    value: $customIntervalDays,
                    in: 1...365
                )
                .font(.subheadline)
                .transition(.foldReveal)
            }

            HStack(alignment: .top, spacing: 10) {
                Text(viewModel.loc("Next charge"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                Text(nextChargeDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale)))
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .background(viewModel.primaryColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.primaryColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var nextChargeDate: Date {
        let calendar = Calendar.current
        switch billingInterval {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom:
            return calendar.date(byAdding: .day, value: customIntervalDays, to: date) ?? date
        }
    }

    private func billingIntervalTitle(_ interval: RecurringSubscription.BillingInterval) -> String {
        switch interval {
        case .weekly:
            return viewModel.loc("Weekly")
        case .biweekly:
            return viewModel.loc("Every 2 weeks")
        case .monthly:
            return viewModel.loc("Monthly")
        case .custom:
            return viewModel.loc("Custom")
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSaving ? viewModel.savingDots : viewModel.saveLabel)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .premiumActionFill(tint: type == .income ? .green : viewModel.primaryColor, isEnabled: isValid)
        }
        .disabled(!isValid || isSaving)
    }

    private func toolbarGlassLabel(_ title: String, tint: Color, isPrimary: Bool = false) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isPrimary ? .white : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isPrimary ? tint.opacity(0.95) : Color(.secondarySystemGroupedBackground).opacity(0.86))
            }
            .overlay {
                Capsule()
                    .fill(.regularMaterial)
                    .opacity(isPrimary ? 0.16 : 0.42)
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isPrimary ? 0.26 : 0.18), lineWidth: 1)
            }
            .shadow(color: tint.opacity(isPrimary ? 0.18 : 0.06), radius: 10, y: 4)
    }

    private var selectedCategoryHelper: String? {
        switch AppCategory.normalizedCategoryID(for: category, type: type) {
        case "balance_adjustment":
            return viewModel.loc("Balance adjustments fix your starting balance. They stay out of spending reports.")
        case "ignore":
            return viewModel.loc("Ignore keeps the entry visible but leaves it out of budgets and reports.")
        case "reimbursement":
            return viewModel.loc("Reimbursement is money paid back to you. PennyLet uses it to lower the original cost when possible.")
        default:
            return nil
        }
    }

    private func addCustomCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        category = name
        viewModel.addCustomCategory(name)
        newCategoryName = ""
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            showCustomCategoryField = false
        }
    }

    private func save() {
        guard let value = parsedAmount, value > 0 else { return }
        isSaving = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let useForeign = selectedCurrency != "native" && convertedAmount != nil
        let finalAmount = useForeign ? (convertedAmount ?? value) : value

        let data = TransactionData(
            amount: finalAmount,
            type: type,
            category: category,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
            date: formatter.string(from: date),
            merchant: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
            isRecurring: isSubscription,
            tags: isSubscription ? ["subscription"] : nil,
            originalCurrency: useForeign ? selectedCurrency : nil,
            originalAmount: useForeign ? value : nil,
            exchangeRate: useForeign ? conversionRate : nil,
            baseCurrency: useForeign ? viewModel.currency : nil
        )
        Task {
            await viewModel.addTransaction(data)
            if isSubscription {
                await viewModel.addRecurringSubscription(
                    name: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? viewModel.loc("Subscription") : note.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: finalAmount,
                    currencyCode: viewModel.currency,
                    category: category,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines),
                    startDate: date,
                    interval: billingInterval,
                    customIntervalDays: billingInterval == .custom ? customIntervalDays : nil
                )
            }
            isSaving = false
            dismiss()
        }
    }

    private func performConversion() async {
        guard let value = parsedAmount, value > 0,
              selectedCurrency != "native" else {
            convertedAmount = nil
            conversionRate = nil
            return
        }
        isConverting = true
        conversionError = nil
        do {
            let result = try await CurrencyRateService.shared.convert(
                amount: value,
                from: selectedCurrency,
                to: viewModel.currency
            )
            convertedAmount = result.converted
            conversionRate = result.rate
        } catch let rateError as CurrencyRateError {
            conversionError = viewModel.loc(rateError.localizationKey)
            convertedAmount = nil
            conversionRate = nil
        } catch {
            conversionError = viewModel.loc("Could not fetch exchange rate.")
            convertedAmount = nil
            conversionRate = nil
        }
        isConverting = false
    }
}
