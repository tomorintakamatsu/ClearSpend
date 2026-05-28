import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showHelp = false

    private var hasTransactions: Bool {
        !viewModel.transactions.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if viewModel.isBlockVisible(.homeSafeToSpend) {
                    SpendHeroCard(summary: viewModel.spendSummary, currency: viewModel.currency, theme: viewModel.theme)
                        .cardEntrance(index: 0)
                }

                if hasTransactions {
                    if viewModel.isBlockVisible(.homeMonthlyPulse) {
                        QuickStatsRow(summary: viewModel.spendSummary, currency: viewModel.currency)
                            .cardEntrance(index: 1)
                    }

                    if viewModel.isBlockVisible(.homeTopCategories), !viewModel.categoryBreakdown.isEmpty {
                        TopCategoriesList(breakdown: viewModel.categoryBreakdown, currency: viewModel.currency)
                            .cardEntrance(index: 2)
                    }

                    if viewModel.isBlockVisible(.homeRecentActivity) {
                        RecentActivityList(transactions: viewModel.recentTransactions, currency: viewModel.currency)
                            .cardEntrance(index: 3)
                    }
                } else if !viewModel.isLoadingData {
                    QuietDashboardStartCard()
                        .cardEntrance(index: 1)
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
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(viewModel.primaryColor)
                }
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
    }

    private var helpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.loc("How PennyLet Works"))
                    .font(.title2.weight(.bold))

                helpSection(
                    icon: "dollarsign.circle.fill",
                    title: viewModel.loc("Balance"),
                    body: viewModel.loc("This month's income minus expenses. Positive means you're in the green; negative means you're overspending.")
                )
                helpSection(
                    icon: "shield.checkered",
                    title: viewModel.loc("Safe to Spend Today"),
                    body: viewModel.loc("(Monthly income − essentials − savings goal − already spent) ÷ days remaining. If you spend more than this per day, you'll run out before month-end.")
                )
                helpSection(
                    icon: "chart.pie.fill",
                    title: viewModel.loc("Top Categories"),
                    body: viewModel.loc("Your spending this month broken down by category. Instantly see where your money goes.")
                )
                helpSection(
                    icon: "sparkles",
                    title: viewModel.loc("AI Analysis"),
                    body: viewModel.loc("AI analyzes your spending patterns and provides daily, weekly, and monthly insights. Free tier includes limited uses.")
                )
                helpSection(
                    icon: "creditcard.fill",
                    title: viewModel.loc("Subscriptions"),
                    body: viewModel.loc("Auto-detects App Store subscriptions on this device and shows monthly and yearly totals.")
                )
            }
            .padding(24)
        }
        .navigationTitle(viewModel.loc("Help"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Done")) { showHelp = false }
            }
        }
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(viewModel.primaryColor)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
            }
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuietDashboardStartCard: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 14) {
            PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 42, shape: .circle, isProminent: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loc("No transactions yet"))
                    .font(.title3.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }
}
