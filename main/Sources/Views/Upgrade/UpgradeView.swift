import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var products: [StoreKit.Product] = []
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isYearly = true
    @State private var purchaseError: String?
    @State private var restoreMessage: String?

    private var monthly: StoreKit.Product? { products.first(where: { $0.id == APIConstants.monthlyProductID }) }
    private var yearly: StoreKit.Product?  { products.first(where: { $0.id == APIConstants.yearlyProductID  }) }
    private var selectedProduct: StoreKit.Product? { isYearly ? (yearly ?? monthly) : (monthly ?? yearly) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    proHero
                        .cardEntrance(index: 0)

                    if isLoading {
                        ProgressView()
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .premiumPanel(tint: .yellow)
                            .cardEntrance(index: 1)
                    } else {
                        pricingSection
                            .cardEntrance(index: 1)
                    }

                    featuresList
                        .cardEntrance(index: 2)

                    comparisonTable
                        .cardEntrance(index: 3)

                    if let product = selectedProduct {
                        subscribeButton(for: product)
                            .cardEntrance(index: 4)
                        .disabled(isPurchasing)
                    }

                    if let msg = purchaseError {
                        Text(msg).font(.caption).foregroundStyle(.red)
                    }

                    Button(viewModel.loc("Restore Purchases")) {
                        Task { await restore() }
                    }
                    .font(.subheadline).foregroundStyle(viewModel.primaryColor)

                    if let msg = restoreMessage {
                        Text(msg).font(.caption)
                            .foregroundStyle(msg.contains("✅") ? .green : .secondary)
                    }

                    VStack(spacing: 6) {
                        Link(viewModel.loc("Privacy Policy"),
                             destination: URL(string: "https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf")!)
                            .font(.caption2)
                        Link(viewModel.loc("Terms of Use (EULA)"),
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.caption2)
                    }.padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .clearSpendScreenBackground(theme: viewModel.theme, allowsWallpaper: false)
            .navigationTitle(viewModel.loc("Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.loc("Done")) { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .task { await loadProducts() }
    }

    // MARK: - Pricing

    private var proHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.yellow)
                    .frame(width: 48, height: 48)
                    .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.loc("PennyLet Pro"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
            }

            HStack(spacing: 8) {
                heroChip(viewModel.loc("Higher AI limits"))
                heroChip(viewModel.loc("Forecasts"))
                heroChip(viewModel.loc("Charts"))
            }
        }
        .padding(20)
        .premiumPanel(tint: .yellow)
    }

    private func heroChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.64)
            .allowsTightening(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(viewModel.loc("Plan"), selection: $isYearly) {
                Text(viewModel.loc("Monthly")).tag(false)
                Text(viewModel.loc("Yearly (save 40%)")).tag(true)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                if let m = monthly {
                    priceCard(product: m, period: viewModel.loc("Monthly"), price: m.displayPrice, selected: !isYearly) {
                        withAnimation(AnimationPresets.snappy) { isYearly = false }
                    }
                }
                if let y = yearly {
                    priceCard(product: y, period: viewModel.loc("Yearly"), price: y.displayPrice, badge: viewModel.loc("Save 40%"), selected: isYearly) {
                        withAnimation(AnimationPresets.snappy) { isYearly = true }
                    }
                }
            }
        }
    }

    private func priceCard(product: StoreKit.Product, period: String, price: String,
                           badge: String? = nil, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.yellow, in: Capsule())
                    }
                }
                .frame(height: 20)

                Text(price)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.50)
                    .allowsTightening(true)
                    .frame(height: 36)
                Text(period)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 118, maxHeight: 118)
            .padding(.vertical, 16)
            .background(
                selected ? Color.yellow.opacity(0.15) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.yellow : Color.gray.opacity(0.22), lineWidth: selected ? 1.5 : 1)
            }
            .shadow(color: selected ? Color.yellow.opacity(0.18) : Color.black.opacity(0.035), radius: selected ? 14 : 8, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feature List

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.loc("Pro unlocks"))
                .font(.headline.weight(.bold))

            ForEach(Array(proFeatures.enumerated()), id: \.element.0) { index, feature in
                let (icon, title, _) = feature
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 30, height: 30)
                        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                    }
                    Spacer()
                }
                .staggeredEntrance(index: index)
            }
        }
        .padding(16)
        .premiumPanel(tint: .yellow)
    }

    private var proFeatures: [(String, String, String)] {
        [
            ("sparkles", viewModel.loc("More AI Analyses"), viewModel.loc("30 daily, 15 weekly, 10 monthly, and 3 forecasts every month")),
            ("chart.line.uptrend.xyaxis", viewModel.loc("Spending Forecasts"), viewModel.loc("AI predicts next month's spending based on your history")),
            ("chart.pie.fill", viewModel.loc("Visual Pie Charts"), viewModel.loc("Beautiful spending breakdown charts in weekly and monthly reports")),
            ("tag.fill", viewModel.loc("Custom Categories"), viewModel.loc("Create your own spending and income categories")),
            ("clock.arrow.2.circlepath", viewModel.autoAnalysisLabel, viewModel.loc("Schedule automatic daily, weekly, and monthly AI analysis")),
            ("wand.and.stars", viewModel.loc("Richer AI reports"), viewModel.loc("Extra anomaly checks and tailored tips in AI reports")),
        ]
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.loc("Free vs Pro"))
                .font(.headline.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)

            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.loc("Free")).font(.caption.weight(.semibold)).frame(width: 60)
                Text(viewModel.loc("Pro")).font(.caption.weight(.semibold)).frame(width: 60).foregroundStyle(.yellow)
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            comparisonRow(icon: "sparkles", label: viewModel.dailyAnalysisTitle, free: "5\(viewModel.loc("/mo"))", pro: "30\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.bar.fill", label: viewModel.weeklyRecapTitle, free: "1\(viewModel.loc("/mo"))", pro: "15\(viewModel.loc("/mo"))")
            comparisonRow(icon: "doc.text.magnifyingglass", label: viewModel.monthlyInsightTitle, free: "—", pro: "10\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.line.uptrend.xyaxis", label: viewModel.loc("Spending Forecasts"), free: "—", pro: "3\(viewModel.loc("/mo"))")
            comparisonRow(icon: "camera.viewfinder", label: viewModel.scanReceiptLabel, free: viewModel.loc("Included"), pro: viewModel.loc("Included"))
            comparisonRow(icon: "creditcard.fill", label: viewModel.loc("Subscription Tracker"), free: viewModel.loc("Included"), pro: viewModel.loc("Included"))
            comparisonRow(icon: "heart.fill", label: viewModel.loc("Budget Health"), free: viewModel.loc("Included"), pro: viewModel.loc("Included"))
            comparisonRow(icon: "clock.arrow.2.circlepath", label: viewModel.autoAnalysisLabel, free: "—", pro: viewModel.loc("Included"))
            comparisonRow(icon: "tag.fill", label: viewModel.loc("Custom Categories"), free: "—", pro: viewModel.loc("Included"))
            comparisonRow(icon: "chart.pie.fill", label: viewModel.loc("Visual Pie Charts"), free: "—", pro: viewModel.loc("Included"))
            comparisonRow(icon: "wand.and.stars", label: viewModel.loc("Richer AI reports"), free: "—", pro: viewModel.loc("Included"))
        }
        .font(.caption2).padding(.vertical, 8)
        .premiumPanel(tint: .yellow)
    }

    private func comparisonRow(icon: String, label: String, free: String, pro: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption2).foregroundStyle(.secondary).frame(width: 16)
                Text(label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(free)
                    .frame(width: 60)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(pro)
                    .frame(width: 60)
                    .foregroundStyle(.yellow)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }.padding(.horizontal, 12).padding(.vertical, 7)
            Divider().padding(.leading, 36)
        }
    }

    private func subscribeButton(for product: StoreKit.Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.black)
                }
                Text(isPurchasing ? viewModel.loc("Processing...") : viewModel.loc("Subscribe"))
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .premiumActionFill(tint: .yellow, isEnabled: !isPurchasing)
        }
        .buttonStyle(.plain)
    }

    // MARK: - StoreKit

    private func loadProducts() async {
        isLoading = true
        let ids = [APIConstants.monthlyProductID, APIConstants.yearlyProductID]
        do {
            let loaded = try await StoreKit.Product.products(for: ids)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            purchaseError = viewModel.loc("Unable to load pricing. Please try again.")
        }
        isLoading = false
    }

    private func purchase(_ product: StoreKit.Product) async {
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    viewModel.hasProSubscription = true
                    restoreMessage = "✅ \(viewModel.loc("Pro unlocked! Refreshing..."))"
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            case .userCancelled: break
            case .pending: purchaseError = viewModel.loc("Purchase pending approval.")
            @unknown default: break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    private func restore() async {
        restoreMessage = nil
        var found = false
        for await result in StoreKit.Transaction.all {
            guard case .verified(let txn) = result,
                  txn.productType == .autoRenewable || txn.productType == .nonRenewable,
                  txn.revocationDate == nil,
                  txn.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            found = true; break
        }
        if found {
            viewModel.hasProSubscription = true
            restoreMessage = "✅ \(viewModel.loc("Purchase restored! Pro features are now unlocked."))"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } else {
            restoreMessage = viewModel.loc("No active subscription found.")
        }
    }
}
