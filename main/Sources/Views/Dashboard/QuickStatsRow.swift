import SwiftUI

struct QuickStatsRow: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.spent > 0 {
                QuietStatRow(
                    title: viewModel.loc("Spent"),
                    amount: summary.spent,
                    icon: "arrow.up.forward",
                    color: .red,
                    currency: currency
                )
            }

            if summary.incomeThisMonth > 0 {
                QuietStatRow(
                    title: viewModel.loc("Income"),
                    amount: summary.incomeThisMonth,
                    icon: "arrow.down.forward",
                    color: .green,
                    currency: currency
                )
            }

            if summary.spent > 0 && summary.incomeThisMonth > 0 {
                Divider()
                QuietStatRow(
                    title: viewModel.loc("Balance"),
                    amount: abs(summary.balance),
                    icon: "equal",
                    color: summary.balance >= 0 ? .blue : .red,
                    currency: currency,
                    isSubtle: true
                )
            }
        }
        .padding(14)
        .premiumPanel(tint: viewModel.theme.primaryColor)
    }
}

private struct QuietStatRow: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let currency: String
    var isSubtle = false

    var body: some View {
        HStack(spacing: 8) {
            PennyLetIconTile(symbol: icon, tint: color, size: 26, symbolScale: 0.42, shape: tileShape)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(CurrencyFormat.format(abs(amount), currency: currency))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(isSubtle ? .secondary : .primary)
                .currencyAmountDisplay(minScale: 0.56)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground).opacity(isSubtle ? 0.45 : 0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tileShape: PennyLetIconShape {
        switch icon {
        case "arrow.up.forward": return .diamond
        case "arrow.down.forward": return .circle
        default: return .capsule
        }
    }
}
