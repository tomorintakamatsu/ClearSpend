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

    func premiumPanel(tint: Color? = nil, followsWallpaperOpacity: Bool = true) -> some View {
        modifier(PremiumPanelModifier(tint: tint, followsWallpaperOpacity: followsWallpaperOpacity))
    }

    func premiumActionFill(tint: Color, isEnabled: Bool = true, followsWallpaperOpacity: Bool = true) -> some View {
        modifier(PremiumActionFillModifier(tint: tint, isEnabled: isEnabled, followsWallpaperOpacity: followsWallpaperOpacity))
    }

    func themedMiniPanel(
        tint: Color? = nil,
        cornerRadius: CGFloat = 14,
        colorStrength: Double = 1
    ) -> some View {
        modifier(ThemedMiniPanelModifier(tint: tint, cornerRadius: cornerRadius, colorStrength: colorStrength))
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

extension EnvironmentValues {
    var pennyLetAllowsWallpaperSurfaces: Bool {
        get { self[PennyLetAllowsWallpaperSurfacesKey.self] }
        set { self[PennyLetAllowsWallpaperSurfacesKey.self] = newValue }
    }
}

private struct PremiumPanelModifier: ViewModifier {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.pennyLetAllowsWallpaperSurfaces) private var allowsWallpaperSurfaces
    let tint: Color?
    let followsWallpaperOpacity: Bool

    func body(content: Content) -> some View {
        let wallpaperPanelsActive = followsWallpaperOpacity && allowsWallpaperSurfaces && viewModel.hasWallpaperTheme
        let activeTint = wallpaperPanelsActive ? viewModel.cardBoxColor : (tint ?? Color.primary)
        let panelOpacity = wallpaperPanelsActive ? viewModel.wallpaperPanelOpacityValue : 1
        let baseOpacity = wallpaperPanelsActive ? 0.10 + 0.78 * panelOpacity : 1
        let tintOpacity = wallpaperPanelsActive ? (0.20 + 0.34 * panelOpacity) * panelOpacity : 0.018
        let separatorOpacity = wallpaperPanelsActive ? 0.18 : 0.08
        let shadowOpacity = wallpaperPanelsActive ? 0.035 + 0.085 * panelOpacity : 0.035

        content
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(baseOpacity))
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
                    .stroke(activeTint.opacity(wallpaperPanelsActive ? 0.24 : 0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: wallpaperPanelsActive ? 18 : 14, y: 5)
    }
}

private struct PremiumActionFillModifier: ViewModifier {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.pennyLetAllowsWallpaperSurfaces) private var allowsWallpaperSurfaces
    let tint: Color
    let isEnabled: Bool
    let followsWallpaperOpacity: Bool

    func body(content: Content) -> some View {
        let wallpaperActionsActive = followsWallpaperOpacity && allowsWallpaperSurfaces && viewModel.hasWallpaperTheme
        let actionOpacity = wallpaperActionsActive ? max(viewModel.wallpaperPanelOpacityValue, 0.42) : 1
        let fill = isEnabled ? tint.opacity(actionOpacity) : Color.gray.opacity(wallpaperActionsActive ? max(0.22, 0.34 * actionOpacity) : 0.34)

        content
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(isEnabled ? max(0.08, 0.16 * actionOpacity) : 0.08), lineWidth: 1)
            }
            .shadow(color: isEnabled ? tint.opacity(0.18 * actionOpacity) : .clear, radius: 14, y: 6)
    }
}

private struct ThemedMiniPanelModifier: ViewModifier {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.pennyLetAllowsWallpaperSurfaces) private var allowsWallpaperSurfaces
    let tint: Color?
    let cornerRadius: CGFloat
    let colorStrength: Double

    func body(content: Content) -> some View {
        let wallpaperActive = allowsWallpaperSurfaces && viewModel.hasWallpaperTheme
        let activeTint = wallpaperActive ? viewModel.cardBoxColor : (tint ?? viewModel.primaryColor)
        let panelOpacity = wallpaperActive ? viewModel.wallpaperPanelOpacityValue : 1
        let baseOpacity = wallpaperActive ? 0.08 + 0.72 * panelOpacity : 0.72
        let tintOpacity = wallpaperActive ? (0.20 + 0.34 * panelOpacity) * panelOpacity * colorStrength : 0.025 * colorStrength
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(Color(.secondarySystemGroupedBackground).opacity(baseOpacity))
                    .overlay {
                        shape.fill(activeTint.opacity(tintOpacity))
                    }
            }
            .overlay {
                shape
                    .stroke(activeTint.opacity(wallpaperActive ? 0.16 + 0.12 * panelOpacity : 0.08), lineWidth: 1)
            }
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
