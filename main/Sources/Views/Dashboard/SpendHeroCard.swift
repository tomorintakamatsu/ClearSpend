import SwiftUI

struct SpendHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    let currency: String
    let theme: AppTheme

    private var tint: Color {
        viewModel.primaryColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.loc("Safe to Spend Today"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }

                Spacer()

                Text(summary.isOverBudget ? viewModel.loc("Over budget") : viewModel.loc("On track"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(summary.isOverBudget ? Color(.systemRed) : tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((summary.isOverBudget ? Color(.systemRed) : tint).opacity(0.10), in: Capsule(style: .continuous))
            }

            HStack(alignment: .center, spacing: 18) {
                Text(CurrencyFormat.format(summary.safeDaily, currency: currency))
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .currencyAmountDisplay(minScale: 0.56)
                    .layoutPriority(1)

                SpendRing(progress: min(summary.spendPercent / 100, 1), tint: tint, isOverBudget: summary.isOverBudget)
                    .frame(width: 60, height: 60)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 12) {
                progressBar

                HStack(alignment: .lastTextBaseline) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(summary.daysLeft)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(viewModel.loc("d left"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                    Spacer(minLength: 12)

                    Text("\(Int(summary.spendPercent.rounded()))%")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(summary.isOverBudget ? Color(.systemRed) : tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
        }
        .padding(26)
        .premiumPanel(tint: tint)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(summary.spendPercent / 100, 1)), height: 8)
            }
        }
        .frame(height: 8)
    }
}

private struct SpendRing: View {
    let progress: Double
    let tint: Color
    let isOverBudget: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.04, progress))
                .stroke(isOverBudget ? Color(.systemRed) : tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
