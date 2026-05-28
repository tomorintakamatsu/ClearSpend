import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.08), lineWidth: 1)
            }
    }

    func gradientCard(colors: [Color]) -> some View {
        let tint = colors.first ?? .primary

        return self
            .padding(24)
            .premiumPanel(tint: tint)
    }

    func clearSpendScreenBackground(theme: AppTheme) -> some View {
        background {
            PennyLetSurfaceBackground(theme: theme)
        }
        .scrollContentBackground(.hidden)
    }

    func premiumPanel(tint: Color? = nil) -> some View {
        background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill((tint ?? Color.primary).opacity(0.018))
                }
        }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.08), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((tint ?? Color.primary).opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 14, y: 5)
    }

    func premiumActionFill(tint: Color, isEnabled: Bool = true) -> some View {
        background(isEnabled ? tint : Color.gray.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(isEnabled ? 0.16 : 0.08), lineWidth: 1)
            }
            .shadow(color: isEnabled ? tint.opacity(0.18) : .clear, radius: 14, y: 6)
    }

    func currencyAmountDisplay(minScale: CGFloat = 0.58) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
            .contentTransition(.numericText())
    }
}

private struct PennyLetSurfaceBackground: View {
    let theme: AppTheme

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}
