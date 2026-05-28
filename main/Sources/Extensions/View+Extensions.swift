import SwiftUI
import UIKit

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
        modifier(PremiumPanelModifier(tint: tint))
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

private struct PremiumPanelModifier: ViewModifier {
    @Environment(AppViewModel.self) private var viewModel
    let tint: Color?

    func body(content: Content) -> some View {
        let activeTint = tint ?? Color.primary
        let panelOpacity = viewModel.hasWallpaperTheme ? viewModel.wallpaperPanelOpacity : 1
        let tintOpacity = viewModel.hasWallpaperTheme ? 0.052 : 0.018
        let separatorOpacity = viewModel.hasWallpaperTheme ? 0.12 : 0.08
        let shadowOpacity = viewModel.hasWallpaperTheme ? 0.085 : 0.035

        content
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(panelOpacity))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(activeTint.opacity(tintOpacity))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(separatorOpacity), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(activeTint.opacity(viewModel.hasWallpaperTheme ? 0.13 : 0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: viewModel.hasWallpaperTheme ? 18 : 14, y: 5)
    }
}

private struct PennyLetSurfaceBackground: View {
    @Environment(AppViewModel.self) private var viewModel
    let theme: AppTheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if let data = viewModel.wallpaperImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: viewModel.wallpaperBlurRadius)
                    .saturation(1.04)
                    .contrast(0.92)
                    .opacity(viewModel.wallpaperVisibility)
                    .accessibilityHidden(true)

                Color(.systemGroupedBackground)
                    .opacity(0.18)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        viewModel.primaryColor.opacity(0.13),
                        Color(.clear),
                        viewModel.accentColor.opacity(0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}
