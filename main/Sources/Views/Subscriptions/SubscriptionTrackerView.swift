import SwiftUI

struct SubscriptionTrackerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var detectedSubs: [SubscriptionDetectionService.DetectedSubscription] = []
    @State private var isLoading = false
    @State private var hasScanned = false
    @State private var showAddSubscription = false
    @State private var scanMessage = ""
    @State private var inferredSubs: [SubscriptionDetectionService.InferredSubscription] = []
    @State private var addingInferredSubscriptionIDs: Set<String> = []
    @State private var addedInferredSubscriptionIDs: Set<String> = []
    @State private var pendingDeleteManualSubscription: RecurringSubscription?

    private func makeSnapshot() -> SubscriptionTrackerSnapshot {
        let manualSubscriptions = viewModel.recurringSubscriptions.filter(\.isActive)
        let activeDetected = detectedSubs.filter(\.isActive)
        let expiredDetected = detectedSubs.filter { !$0.isActive }
        let existingNames = Set(
            manualSubscriptions.map { normalizedName($0.name) } +
            detectedSubs.map { normalizedName($0.displayName) }
        )
        let suggestedSubscriptions = inferredSubs.filter { !existingNames.contains(normalizedName($0.name)) }
        var values: [(currency: String, monthly: Double)] = activeDetected.map { sub in
            (sub.currencyCode, monthlyValue(for: sub))
        }
        values.append(contentsOf: manualSubscriptions.map { ($0.currencyCode, monthlyValue(for: $0)) })
        let currencyTotals: [(currency: String, formattedMonthly: String, count: Int)] = Dictionary(grouping: values, by: { $0.currency })
            .map { code, subs in
                let monthly = subs.reduce(0.0) { $0 + $1.monthly }
                return (code, CurrencyFormat.format(monthly, currency: code), subs.count)
            }
            .sorted { $0.currency < $1.currency }

        return SubscriptionTrackerSnapshot(
            activeDetected: activeDetected,
            expiredDetected: expiredDetected,
            manualSubscriptions: manualSubscriptions,
            suggestedSubscriptions: suggestedSubscriptions,
            currencyTotals: currencyTotals
        )
    }

    private let averageDaysPerMonth = 365.2425 / 12.0
    private let weeksPerMonth = (365.2425 / 12.0) / 7.0

    var body: some View {
        let snapshot = makeSnapshot()

        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isBlockVisible(.subscriptionsOverview) {
                    summaryCard(snapshot: snapshot)
                }

                actionBar

                if !snapshot.manualSubscriptions.isEmpty {
                    manualList(snapshot.manualSubscriptions)
                }

                if viewModel.isBlockVisible(.subscriptionsSuggestions), !snapshot.suggestedSubscriptions.isEmpty {
                    suggestedList(snapshot.suggestedSubscriptions)
                }

                if !snapshot.activeDetected.isEmpty {
                    activeList(snapshot.activeDetected)
                }

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(scanMessage.isEmpty ? viewModel.loc("Scanning subscriptions...") : scanMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(viewModel.loc("Checking App Store purchase info iOS allows."))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if detectedSubs.isEmpty && snapshot.manualSubscriptions.isEmpty && hasScanned {
                    emptyState
                }

                if !snapshot.expiredDetected.isEmpty {
                    expiredList(snapshot.expiredDetected)
                }

                if !hasScanned && detectedSubs.isEmpty {
                    scanPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle(viewModel.loc("Subscriptions"))
        .clearSpendScreenBackground(theme: viewModel.theme)
        .task {
            if !hasScanned {
                await scanSubs()
            }
        }
        .refreshable {
            await scanSubs()
        }
        .sheet(isPresented: $showAddSubscription) {
            AddSubscriptionSheet()
        }
        .confirmationDialog(
            viewModel.loc("Delete subscription?"),
            isPresented: Binding(
                get: { pendingDeleteManualSubscription != nil },
                set: { if !$0 { pendingDeleteManualSubscription = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let subscription = pendingDeleteManualSubscription {
                Button(viewModel.loc("Delete"), role: .destructive) {
                    Haptics.warning()
                    viewModel.deleteRecurringSubscription(subscription)
                    pendingDeleteManualSubscription = nil
                }
            }
            Button(viewModel.cancelLabel, role: .cancel) {}
        } message: {
            if let subscription = pendingDeleteManualSubscription {
                Text(subscription.name)
            }
        }
    }

    // MARK: - Actions

    private func scanSubs() async {
        isLoading = true
        scanMessage = viewModel.loc("Checking active entitlements...")
        let service = SubscriptionDetectionService()
        try? await Task.sleep(nanoseconds: 250_000_000)
        scanMessage = viewModel.loc("Reviewing purchase history...")
        await service.detectSubscriptions()
        detectedSubs = service.detectedSubs
        scanMessage = viewModel.loc("Scanning transaction history...")
        inferredSubs = SubscriptionDetectionService.inferLocalSubscriptions(
            from: viewModel.transactions,
            currencyCode: viewModel.currency
        )
        scanMessage = ""
        isLoading = false
        hasScanned = true
    }

    // MARK: - Summary

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                showAddSubscription = true
            } label: {
                Label(viewModel.loc("Add Subscription"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .premiumActionFill(tint: viewModel.primaryColor)
            }
            .buttonStyle(.plain)

            Button {
                Task { await scanSubs() }
            } label: {
                Label(viewModel.loc("Scan Again"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.primaryColor.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private func summaryCard(snapshot: SubscriptionTrackerSnapshot) -> some View {
        let totalCount = snapshot.activeDetected.count + snapshot.manualSubscriptions.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.loc("Active Subscriptions"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("\(totalCount) \(viewModel.loc("tracked"))")
                        .font(.headline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PennyLetIconTile(symbol: "creditcard.fill", tint: Color(.systemTeal), size: 42, shape: .circle, isProminent: true)
            }

            summarySourceCounts(snapshot: snapshot)

            VStack(alignment: .leading, spacing: 10) {
                if snapshot.currencyTotals.isEmpty {
                    Text(viewModel.loc("No App Store subscriptions found"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(snapshot.currencyTotals, id: \.currency) { item in
                        HStack(alignment: .center, spacing: 10) {
                            Text(item.currency)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.formattedMonthly)
                                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                    .currencyAmountDisplay(minScale: 0.54)
                                Text("/\(viewModel.loc("mo"))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .layoutPriority(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(20)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private func summarySourceCounts(snapshot: SubscriptionTrackerSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            summaryCountPill(
                title: viewModel.loc("App Store subscriptions"),
                count: snapshot.activeDetected.count,
                color: viewModel.primaryColor
            )
            summaryCountPill(
                title: viewModel.loc("Manual subscriptions"),
                count: snapshot.manualSubscriptions.count,
                color: Color(.systemTeal)
            )
            summaryCountPill(
                title: viewModel.loc("Suggested subscriptions"),
                count: snapshot.suggestedSubscriptions.count,
                color: Color(.systemOrange)
            )
        }
    }

    private func summaryCountPill(title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Lists

    private func activeList(_ subscriptions: [SubscriptionDetectionService.DetectedSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("App Store subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(subscriptions) { sub in
                subscriptionRow(sub)
            }
        }
    }

    private func manualList(_ subscriptions: [RecurringSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Manual subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(subscriptions) { sub in
                manualSubscriptionRow(sub)
            }
        }
    }

    private func suggestedList(_ subscriptions: [SubscriptionDetectionService.InferredSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Suggested subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(subscriptions) { sub in
                inferredSubscriptionRow(sub)
            }
        }
    }

    private func expiredList(_ subscriptions: [SubscriptionDetectionService.DetectedSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Expired"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ForEach(subscriptions) { sub in
                subscriptionRow(sub)
            }
        }
    }

    private func subscriptionRow(_ sub: SubscriptionDetectionService.DetectedSubscription) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                PennyLetIconTile(
                    symbol: sub.isActive ? "checkmark.seal.fill" : "xmark.seal.fill",
                    tint: sub.isActive ? Color(.systemTeal) : .gray,
                    size: 46,
                    shape: sub.isActive ? .circle : .roundedSquare,
                    isProminent: sub.isActive
                )
                Text(sub.period.prefix(1).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(sub.isActive ? viewModel.primaryColor : .gray, in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(sub.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                subscriptionMeta(
                    price: formatPrice(sub.price, sub.currencyCode),
                    interval: periodLabel(sub.period)
                )
                if let renewal = sub.renewalDate, sub.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("\(viewModel.loc("Renews")) \(renewal.formatted(.relative(presentation: .named).locale(viewModel.appLocale)))")
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 2) {
                Text(monthlyEquivalent(sub))
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .currencyAmountDisplay(minScale: 0.54)
                Text("/\(viewModel.loc("mo"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(minWidth: 54, alignment: .trailing)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .opacity(sub.isActive ? 1 : 0.5)
    }

    private func formatPrice(_ price: Decimal, _ code: String) -> String {
        let value = NSDecimalNumber(decimal: price).doubleValue
        return CurrencyFormat.format(value, currency: code)
    }

    private func monthlyEquivalent(_ sub: SubscriptionDetectionService.DetectedSubscription) -> String {
        let monthly = monthlyValue(for: sub)
        return CurrencyFormat.format(monthly, currency: sub.currencyCode)
    }

    private func monthlyValue(for sub: SubscriptionDetectionService.DetectedSubscription) -> Double {
        let value = NSDecimalNumber(decimal: sub.price).doubleValue
        switch sub.period {
        case "yearly": return value / 12
        case "weekly": return value * weeksPerMonth
        case "biweekly": return value * (weeksPerMonth / 2.0)
        case "daily": return value * averageDaysPerMonth
        default:
            if let parsed = parseDynamicPeriod(sub.period) {
                switch parsed.unit {
                case "day", "days": return value * (averageDaysPerMonth / Double(max(1, parsed.count)))
                case "week", "weeks": return value * (weeksPerMonth / Double(max(1, parsed.count)))
                case "month", "months": return value / Double(max(1, parsed.count))
                case "year", "years": return value / (12 * Double(max(1, parsed.count)))
                default: break
                }
            }
            return value
        }
    }

    private func manualSubscriptionRow(_ sub: RecurringSubscription) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PennyLetIconTile(symbol: "repeat", tint: Color(.systemTeal), size: 48, shape: .capsule, isProminent: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                subscriptionMeta(
                    price: formatPrice(Decimal(sub.amount), sub.currencyCode),
                    interval: intervalLabel(sub)
                )
                Text("\(viewModel.loc("Next charge")) \(formattedDate(sub.nextBillingDate))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button(role: .destructive) {
                pendingDeleteManualSubscription = sub
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func inferredSubscriptionRow(_ sub: SubscriptionDetectionService.InferredSubscription) -> some View {
        let isAdding = addingInferredSubscriptionIDs.contains(sub.id)
        let isAdded = addedInferredSubscriptionIDs.contains(sub.id)

        return HStack(alignment: .top, spacing: 14) {
            PennyLetIconTile(symbol: "sparkle.magnifyingglass", tint: Color(.systemOrange), size: 48, shape: .diamond, isProminent: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                subscriptionMeta(
                    price: formatPrice(Decimal(sub.amount), sub.currencyCode),
                    interval: intervalLabel(sub.interval, customIntervalDays: sub.customIntervalDays)
                )
                Text("\(sub.matchedTransactions) \(viewModel.loc("matches")) · \(viewModel.loc("Next charge")) \(sub.nextBillingDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button {
                addInferredSubscription(sub)
            } label: {
                suggestedAddButton(isAdded: isAdded)
            }
            .buttonStyle(.plain)
            .disabled(isAdding || isAdded)
            .accessibilityLabel(isAdded ? viewModel.loc("Added") : viewModel.loc("Add Subscription"))
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func suggestedAddButton(isAdded: Bool) -> some View {
        ZStack {
            Image(systemName: "plus")
                .scaleEffect(isAdded ? 0.25 : 1)
                .rotationEffect(.degrees(isAdded ? -90 : 0))
                .opacity(isAdded ? 0 : 1)

            Image(systemName: "checkmark")
                .scaleEffect(isAdded ? 1 : 0.35)
                .rotationEffect(.degrees(isAdded ? 0 : 90))
                .opacity(isAdded ? 1 : 0)
        }
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .background {
            Circle()
                .fill(viewModel.primaryColor)
        }
        .overlay {
            Circle()
                .stroke(.white.opacity(isAdded ? 0.48 : 0.24), lineWidth: 1)
        }
        .shadow(color: viewModel.primaryColor.opacity(isAdded ? 0.34 : 0.22), radius: isAdded ? 14 : 10, y: 5)
        .scaleEffect(isAdded ? 1.06 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isAdded)
    }

    private func subscriptionMeta(price: String, interval: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(price)
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(interval)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func monthlyValue(for sub: RecurringSubscription) -> Double {
        switch sub.interval {
        case .weekly: return sub.amount * weeksPerMonth
        case .biweekly: return sub.amount * (weeksPerMonth / 2.0)
        case .monthly: return sub.amount
        case .custom:
            let days = max(1, sub.customIntervalDays ?? 30)
            return sub.amount * (averageDaysPerMonth / Double(days))
        }
    }

    private func intervalLabel(_ sub: RecurringSubscription) -> String {
        intervalLabel(sub.interval, customIntervalDays: sub.customIntervalDays)
    }

    private func intervalLabel(
        _ interval: RecurringSubscription.BillingInterval,
        customIntervalDays: Int?
    ) -> String {
        switch interval {
        case .weekly: return viewModel.loc("Weekly")
        case .biweekly: return viewModel.loc("Every 2 weeks")
        case .monthly: return viewModel.loc("Monthly")
        case .custom:
            return "\(viewModel.loc("Every")) \(customIntervalDays ?? 30) \(viewModel.loc("days"))"
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        guard let date = Date.fromDateString(dateString) else { return dateString }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale))
    }

    private func addInferredSubscription(_ sub: SubscriptionDetectionService.InferredSubscription) {
        guard !addingInferredSubscriptionIDs.contains(sub.id),
              !addedInferredSubscriptionIDs.contains(sub.id) else { return }

        Haptics.selection()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            addingInferredSubscriptionIDs.insert(sub.id)
            addedInferredSubscriptionIDs.insert(sub.id)
        }

        Task {
            await viewModel.addRecurringSubscription(
                name: sub.name,
                amount: sub.amount,
                currencyCode: sub.currencyCode,
                category: sub.category ?? "subscriptions",
                note: nil,
                startDate: sub.latestTransactionDate,
                interval: sub.interval,
                customIntervalDays: sub.customIntervalDays
            )
            Haptics.success()
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                inferredSubs.removeAll { $0.id == sub.id }
                addingInferredSubscriptionIDs.remove(sub.id)
                addedInferredSubscriptionIDs.remove(sub.id)
            }
        }
    }

    private func periodLabel(_ period: String) -> String {
        switch period {
        case "daily", "weekly", "biweekly", "monthly", "yearly", "subscription", "unknown":
            return viewModel.loc(period)
        default:
            if let parsed = parseDynamicPeriod(period) {
                return "\(viewModel.loc("Every")) \(parsed.count) \(viewModel.loc(parsed.unit))"
            }
            return period
        }
    }

    private func parseDynamicPeriod(_ period: String) -> (count: Int, unit: String)? {
        let parts = period.split(separator: " ")
        guard parts.count == 3,
              parts[0].lowercased() == "every",
              let count = Int(parts[1]) else { return nil }
        return (count, String(parts[2]).lowercased())
    }

    private func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Empty & Prompt

    private var emptyState: some View {
        VStack(spacing: 16) {
            PennyLetIconTile(symbol: "creditcard.trianglebadge.exclamationmark", tint: Color(.systemTeal), size: 58, symbolScale: 0.42, shape: .circle, isProminent: true)
            Text(viewModel.loc("No App Store subscriptions found"))
                .font(.headline)
            Text(viewModel.loc("Apple subscriptions appear here."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(viewModel.loc("Add non-App Store subscriptions manually."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                showAddSubscription = true
            } label: {
                Label(viewModel.loc("Add Subscription"), systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.primaryColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var scanPrompt: some View {
        VStack(spacing: 16) {
            PennyLetIconTile(symbol: "magnifyingglass.circle.fill", tint: viewModel.primaryColor, size: 58, symbolScale: 0.42, shape: .circle, isProminent: true)
            Text(viewModel.loc("Scan for Subscriptions"))
                .font(.title3.weight(.semibold))
            Text(viewModel.loc("PennyLet can scan eligible App Store subscriptions."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(viewModel.loc("Uses only purchase info Apple shares with this app."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await scanSubs() }
            } label: {
                Label(viewModel.loc("Scan Now"), systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(viewModel.primaryColor, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct SubscriptionTrackerSnapshot {
    let activeDetected: [SubscriptionDetectionService.DetectedSubscription]
    let expiredDetected: [SubscriptionDetectionService.DetectedSubscription]
    let manualSubscriptions: [RecurringSubscription]
    let suggestedSubscriptions: [SubscriptionDetectionService.InferredSubscription]
    let currencyTotals: [(currency: String, formattedMonthly: String, count: Int)]
}

private struct AddSubscriptionSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCurrency = ""
    @State private var startDate = Date()
    @State private var billingInterval: RecurringSubscription.BillingInterval = .monthly
    @State private var customIntervalDays = 30
    @State private var note = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?
    private let averageDaysPerMonth = 365.2425 / 12.0
    private let weeksPerMonth = (365.2425 / 12.0) / 7.0

    private enum Field {
        case name
        case amount
        case note
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double? {
        CurrencyFormat.parseInput(amount)
    }

    private var currencyCode: String {
        selectedCurrency.isEmpty ? viewModel.currency : selectedCurrency
    }

    private var currencyOptions: [(code: String, name: String, symbol: String)] {
        var options = CurrencyRateService.supportedCurrencies
        if !options.contains(where: { $0.code == viewModel.currency }) {
            options.insert(
                (viewModel.currency, viewModel.currency, CurrencyFormat.currencySymbol(for: viewModel.currency)),
                at: 0
            )
        }
        return options
    }

    private var canSave: Bool {
        guard let value = parsedAmount else { return false }
        return !trimmedName.isEmpty && value > 0
    }

    private var monthlyPreview: Double {
        let value = parsedAmount ?? 0
        switch billingInterval {
        case .weekly: return value * weeksPerMonth
        case .biweekly: return value * (weeksPerMonth / 2.0)
        case .monthly: return value
        case .custom: return value * (averageDaysPerMonth / Double(max(1, customIntervalDays)))
        }
    }

    private var nextChargeDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var candidate = calendar.startOfDay(for: startDate)
        while candidate <= today {
            candidate = nextBillingDate(after: candidate)
        }
        return candidate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    detailsCard
                    billingCard
                    noteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
            .navigationTitle(viewModel.loc("New Subscription"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveFooter
            }
        }
        .onAppear {
            if selectedCurrency.isEmpty {
                selectedCurrency = viewModel.currency
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                PennyLetIconTile(symbol: "repeat.circle.fill", tint: Color(.systemTeal), size: 46, symbolScale: 0.48, shape: .capsule, isProminent: true)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormat.format(monthlyPreview, currency: currencyCode))
                        .font(.title2.weight(.bold))
                        .currencyAmountDisplay(minScale: 0.54)
                    Text("/\(viewModel.loc("mo"))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.loc("Subscription Tracker"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(viewModel.primaryColor)
                Text(viewModel.loc("Track recurring charges and renewal dates."))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Details"), icon: "text.cursor")

            TextField(viewModel.loc("Name"), text: $name)
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.words)
                .font(.headline)
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Text(CurrencyFormat.currencySymbol(for: currencyCode))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(viewModel.primaryColor)
                    .frame(width: 38, height: 44)
                    .background(viewModel.primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                TextField("0.00", text: $amount)
                    .focused($focusedField, equals: .amount)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)

                Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                    ForEach(currencyOptions, id: \.code) { currency in
                        Text(currencyLabel(currency)).tag(currency.code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(viewModel.primaryColor)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            DatePicker(
                viewModel.loc("First charge"),
                selection: $startDate,
                displayedComponents: .date
            )
            .font(.subheadline.weight(.semibold))
            .padding(13)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var billingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Billing"), icon: "calendar")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                intervalButton(.weekly, title: viewModel.loc("Weekly"), subtitle: viewModel.loc("Every 7 days"))
                intervalButton(.biweekly, title: viewModel.loc("2 weeks"), subtitle: viewModel.loc("Every 14 days"))
                intervalButton(.monthly, title: viewModel.loc("Monthly"), subtitle: viewModel.loc("Most common"))
                intervalButton(.custom, title: viewModel.loc("Custom"), subtitle: viewModel.loc("Pick days"))
            }

            if billingInterval == .custom {
                Stepper(value: $customIntervalDays, in: 1...365) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(viewModel.loc("Every")) \(customIntervalDays) \(viewModel.loc("days"))")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.loc("Custom renewal interval"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                PennyLetIconTile(symbol: "bell.badge", tint: Color(.systemOrange), size: 30, symbolScale: 0.42, shape: .diamond)
                Text("\(viewModel.loc("Next charge")) \(nextChargeDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale)))")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(viewModel.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Note"), icon: "note.text")

            TextField(viewModel.loc("Optional note"), text: $note, axis: .vertical)
                .focused($focusedField, equals: .note)
                .lineLimit(2...4)
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var saveFooter: some View {
        VStack(spacing: 0) {
            Button {
                saveSubscription()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(viewModel.loc("Save Subscription"))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .premiumActionFill(tint: viewModel.primaryColor, isEnabled: canSave)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            PennyLetIconTile(symbol: icon, tint: Color(.systemTeal), size: 28, symbolScale: 0.4, shape: .circle)
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
        }
    }

    private func currencyLabel(_ currency: (code: String, name: String, symbol: String)) -> String {
        "\(currency.code) \(currency.symbol)"
    }

    private func intervalButton(
        _ interval: RecurringSubscription.BillingInterval,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = billingInterval == interval
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                billingInterval = interval
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Spacer()
                }
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(isSelected ? .white.opacity(0.72) : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                isSelected
                    ? viewModel.primaryColor
                    : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveSubscription() {
        guard canSave, let value = parsedAmount else { return }
        isSaving = true
        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote
        let intervalDays = billingInterval == .custom ? customIntervalDays : nil

        Task {
            await viewModel.addRecurringSubscription(
                name: trimmedName,
                amount: value,
                currencyCode: currencyCode,
                category: "subscriptions",
                note: noteValue,
                startDate: startDate,
                interval: billingInterval,
                customIntervalDays: intervalDays
            )
            isSaving = false
            dismiss()
        }
    }

    private func nextBillingDate(after date: Date) -> Date {
        let calendar = Calendar.current
        switch billingInterval {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom:
            return calendar.date(byAdding: .day, value: max(1, customIntervalDays), to: date) ?? date
        }
    }
}
