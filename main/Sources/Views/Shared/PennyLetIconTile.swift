import SwiftUI

enum PennyLetIconShape {
    case roundedSquare
    case circle
    case capsule
    case diamond
}

struct PennyLetIconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 42
    var symbolScale: CGFloat = 0.42
    var shape: PennyLetIconShape = .roundedSquare
    var isProminent = false

    var body: some View {
        ZStack {
            tileShape

            Image(systemName: symbol)
                .font(.system(size: size * symbolScale, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(isProminent ? Color.white : tint, isProminent ? Color.white.opacity(0.62) : tint.opacity(0.42))
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(isProminent ? 0.12 : 0.07), radius: isProminent ? 10 : 7, y: 4)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var tileShape: some View {
        switch shape {
        case .roundedSquare:
            RoundedRectangle(cornerRadius: min(12, size * 0.28), style: .continuous)
                .fill(isProminent ? tint : tint.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: min(12, size * 0.28), style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.18) : tint.opacity(0.18), lineWidth: 1)
                }
        case .circle:
            Circle()
                .fill(isProminent ? tint : tint.opacity(0.16))
                .overlay {
                    Circle()
                        .stroke(isProminent ? Color.white.opacity(0.18) : tint.opacity(0.18), lineWidth: 1)
                }
        case .capsule:
            Capsule(style: .continuous)
                .fill(isProminent ? tint : tint.opacity(0.16))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.18) : tint.opacity(0.18), lineWidth: 1)
                }
        case .diamond:
            RoundedRectangle(cornerRadius: min(10, size * 0.22), style: .continuous)
                .fill(isProminent ? tint : tint.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: min(10, size * 0.22), style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.18) : tint.opacity(0.18), lineWidth: 1)
                }
                .frame(width: size * 0.74, height: size * 0.74)
                .rotationEffect(.degrees(45))
        }
    }

}
