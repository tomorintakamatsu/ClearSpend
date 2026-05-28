import SwiftUI

struct TopCategoriesList: View {
    @Environment(AppViewModel.self) private var viewModel
    let breakdown: [CategoryBreakdown]
    let currency: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptics.selection()
                withAnimation(AnimationPresets.fold) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    PennyLetIconTile(symbol: "chart.pie.fill", tint: Color(.systemOrange), size: 30, symbolScale: 0.43, shape: .circle)
                    Text(viewModel.loc("Top Categories"))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zIndex(1)

            if isExpanded {
                Group {
                    if breakdown.isEmpty {
                        Text(viewModel.loc("No spending this month"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        categoryRows
                    }
                }
                .transition(.underHeaderReveal)
                .clipped()
                .zIndex(0)
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.theme.primaryColor)
        .animation(AnimationPresets.fold, value: isExpanded)
    }

    private var categoryRows: some View {
        VStack(spacing: 12) {
            ForEach(breakdown.prefix(5)) { item in
                let cat = item.category
                let total = breakdown.reduce(0) { $0 + $1.amount }
                let pct = total > 0 ? item.amount / total : 0

                HStack(alignment: .top, spacing: 12) {
                    PennyLetIconTile(symbol: cat.icon, tint: cat.color, size: 32, symbolScale: 0.4, shape: tileShape(for: cat.id))

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(viewModel.loc(cat.label))
                                .font(.subheadline)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)

                            Text(CurrencyFormat.format(item.amount, currency: currency))
                                .font(.headline.weight(.bold).monospacedDigit())
                                .foregroundStyle(.primary)
                                .currencyAmountDisplay(minScale: 0.54)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(.quaternary)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(cat.color)
                                    .frame(width: max(geo.size.width * CGFloat(pct), 4), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func tileShape(for id: String) -> PennyLetIconShape {
        switch id {
        case "food", "shopping", "rent", "investment": return .circle
        case "transport", "subscriptions", "salary": return .capsule
        case "health", "gifts", "gift_in": return .diamond
        default: return .roundedSquare
        }
    }
}
