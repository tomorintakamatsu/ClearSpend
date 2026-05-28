import SwiftUI
import Charts

struct BudgetHealthView: View {
    @Environment(AppViewModel.self) private var viewModel

    var summary: SpendSummary { viewModel.spendSummary }
    var breakdown: [CategoryBreakdown] { viewModel.categoryBreakdown }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isBlockVisible(.budgetOverview), let budget = viewModel.currentBudget {
                    budgetOverview(budget)
                        .modifier(CardEntrance())
                }
                if viewModel.isBlockVisible(.budgetCategories) {
                    pieChartSection
                        .modifier(CardEntrance())
                }
                if viewModel.isBlockVisible(.budgetIncomeChart) {
                    barChartSection
                        .modifier(CardEntrance())
                }
                if viewModel.isBlockVisible(.budgetKeyNumbers) {
                    statCardsSection
                        .modifier(CardEntrance())
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle(viewModel.loc("Budget Health"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func budgetOverview(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.loc("Monthly Disposable"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.primaryColor)
                    Text(CurrencyFormat.format(summary.monthlyDisposable, currency: viewModel.currency))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .currencyAmountDisplay(minScale: 0.54)
                }

                Spacer()

                PennyLetIconTile(
                    symbol: summary.isOverBudget ? "exclamationmark.triangle.fill" : "heart.fill",
                    tint: summary.isOverBudget ? Color(.systemRed) : Color(.systemPink),
                    size: 42,
                    shape: .circle,
                    isProminent: true
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Text("\(Int(summary.spendPercent))" + viewModel.loc("% of budget used"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(CurrencyFormat.format(summary.remaining, currency: viewModel.currency))
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(summary.isOverBudget ? .red : viewModel.primaryColor)
                    .currencyAmountDisplay(minScale: 0.54)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PennyLetIconTile(symbol: "chart.pie.fill", tint: Color(.systemOrange), size: 30, symbolScale: 0.43, shape: .circle)
                Text(viewModel.loc("Spending by Category"))
                    .font(.headline)
                Spacer()
            }

            if breakdown.isEmpty {
                Text(viewModel.loc("No spending data this month"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                Chart(breakdown) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(item.category.color)
                }
                .frame(height: 200)

                VStack(spacing: 8) {
                    ForEach(breakdown.prefix(6)) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 10, height: 10)
                            Text(viewModel.loc(item.category.label))
                                .font(.caption)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Spacer(minLength: 8)
                            Text(CurrencyFormat.format(item.amount, currency: viewModel.currency))
                                .font(.caption.weight(.medium).monospacedDigit())
                                .currencyAmountDisplay(minScale: 0.54)
                        }
                    }
                }
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PennyLetIconTile(symbol: "chart.bar.xaxis", tint: Color(.systemBlue), size: 30, symbolScale: 0.43, shape: .capsule)
                Text(viewModel.loc("Income vs Spending"))
                    .font(.headline)
                Spacer()
            }

            Chart {
                BarMark(
                    x: .value("Type", viewModel.loc("Income")),
                    y: .value("Amount", summary.incomeThisMonth)
                )
                .foregroundStyle(.green)
                BarMark(
                    x: .value("Type", viewModel.loc("Spent")),
                    y: .value("Amount", summary.spent)
                )
                .foregroundStyle(.red)
                if summary.monthlyDisposable > 0 {
                    BarMark(
                        x: .value("Type", viewModel.loc("Budget")),
                        y: .value("Amount", summary.monthlyDisposable)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var statCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PennyLetIconTile(symbol: "number.square.fill", tint: Color(.systemIndigo), size: 30, symbolScale: 0.43, shape: .diamond)
                Text(viewModel.loc("Key numbers"))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                statCard(viewModel.loc("Remaining"), value: summary.remaining, color: summary.isOverBudget ? .red : .green)
                statCard(viewModel.loc("Safe Daily"), value: summary.safeDaily, color: viewModel.primaryColor)
                statCard(viewModel.loc("Days Left"), value: Double(summary.daysLeft), color: .blue, isWhole: true)
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private func statCard(_ title: String, value: Double, color: Color, isWhole: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(isWhole
                ? "\(Int(value))"
                : CurrencyFormat.format(value, currency: viewModel.currency)
            )
            .font(.headline.weight(.bold).monospacedDigit())
            .foregroundStyle(color)
            .currencyAmountDisplay(minScale: 0.52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.12), lineWidth: 1)
        }
    }
}
