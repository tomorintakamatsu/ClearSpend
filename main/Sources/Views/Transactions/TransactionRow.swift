import SwiftUI

struct TransactionRow: View {
    @Environment(AppViewModel.self) private var viewModel
    let transaction: Transaction
    let currency: String
    var isEmbedded = false

    var body: some View {
        rowContent
            .padding(.horizontal, isEmbedded ? 0 : 14)
            .padding(.vertical, isEmbedded ? 8 : 10)
            .modifier(TransactionRowSurface(isEmbedded: isEmbedded))
            .contentShape(.rect)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            let cat = AppCategory.category(for: transaction.category, type: transaction.type)
            PennyLetIconTile(symbol: cat.icon, tint: cat.color, size: 36, symbolScale: 0.4, shape: tileShape(for: cat.id))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? transaction.note ?? viewModel.loc(cat.label))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(viewModel.loc(cat.label))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormat.formatSigned(transaction.signedAmount, currency: currency))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.type == .income ? .green : .primary)
                    .currencyAmountDisplay(minScale: 0.52)
                if let origCurrency = transaction.originalCurrency,
                   let origAmount = transaction.originalAmount {
                    let signedOrig = transaction.type == .expense ? -origAmount : origAmount
                    Text(CurrencyFormat.formatForeignSigned(signedOrig, currency: origCurrency))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .currencyAmountDisplay(minScale: 0.56)
                }
                if let date = transaction.dateValue {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func tileShape(for id: String) -> PennyLetIconShape {
        switch id {
        case "food", "salary", "shopping", "rent": return .circle
        case "transport", "subscriptions", "freelance": return .capsule
        case "health", "gifts", "gift_in": return .diamond
        default: return .roundedSquare
        }
    }
}

private struct TransactionRowSurface: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.04), radius: 10, y: 6)
        }
    }
}
