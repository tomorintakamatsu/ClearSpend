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

    func clearSpendScreenBackground(theme: AppTheme, allowsWallpaper: Bool = true) -> some View {
        background {
            PennyLetSurfaceBackground(theme: theme, allowsWallpaper: allowsWallpaper)
        }
        .environment(\.pennyLetAllowsWallpaperSurfaces, allowsWallpaper)
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

private struct PennyLetAllowsWallpaperSurfacesKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var pennyLetAllowsWallpaperSurfaces: Bool {
        get { self[PennyLetAllowsWallpaperSurfacesKey.self] }
        set { self[PennyLetAllowsWallpaperSurfacesKey.self] = newValue }
    }
}

private struct PremiumPanelModifier: ViewModifier {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.pennyLetAllowsWallpaperSurfaces) private var allowsWallpaperSurfaces
    let tint: Color?

    func body(content: Content) -> some View {
        let activeTint = tint ?? Color.primary
        let wallpaperPanelsActive = allowsWallpaperSurfaces && viewModel.hasWallpaperTheme
        let panelOpacity = wallpaperPanelsActive ? viewModel.wallpaperPanelOpacityValue : 1
        let tintOpacity = wallpaperPanelsActive ? 0.05 * max(panelOpacity, 0.18) : 0.018
        let separatorOpacity = wallpaperPanelsActive ? 0.13 : 0.08
        let shadowOpacity = wallpaperPanelsActive ? 0.09 : 0.035

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
                    .stroke(activeTint.opacity(wallpaperPanelsActive ? 0.14 : 0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: wallpaperPanelsActive ? 18 : 14, y: 5)
    }
}

private struct PennyLetSurfaceBackground: View {
    @Environment(AppViewModel.self) private var viewModel
    let theme: AppTheme
    let allowsWallpaper: Bool

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if allowsWallpaper, let image = viewModel.wallpaperUIImage {
                GeometryReader { proxy in
                    let offset = viewModel.wallpaperFrameOffset(in: proxy.size)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(viewModel.wallpaperZoomScale)
                        .offset(x: offset.width, y: offset.height)
                        .clipped()
                        .blur(radius: viewModel.wallpaperBlurValue)
                        .saturation(1.04)
                        .contrast(0.92)
                        .opacity(viewModel.wallpaperVisibilityOpacity)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()

                Color(.systemGroupedBackground)
                    .opacity(0.14)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        viewModel.primaryColor.opacity(0.10),
                        Color(.clear),
                        viewModel.accentColor.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}
