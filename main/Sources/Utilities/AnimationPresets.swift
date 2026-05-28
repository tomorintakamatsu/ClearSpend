import SwiftUI

enum AnimationPresets {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.75)
    static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.65)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.1)
    static let gentle = Animation.easeInOut(duration: 0.35)
    static let fold = Animation.spring(response: 0.44, dampingFraction: 0.9, blendDuration: 0.06)
    static let pullDown = Animation.easeInOut(duration: 0.26)
}

extension AnyTransition {
    static var foldReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
                .combined(with: .scale(scale: 0.985, anchor: .top))
        )
    }

    static var pullDownReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }

    static var underHeaderReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
                .combined(with: .scale(scale: 0.985, anchor: .top))
        )
    }
}

// MARK: - Button press modifier

struct PressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {}
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Staggered entrance modifier

struct StaggeredEntrance: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                value: isVisible
            )
            .onAppear { isVisible = true }
    }
}

// MARK: - Card entrance modifier

struct CardEntrance: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    init(delay: Double = 0) {
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.965)
            .offset(y: isVisible ? 0 : 18)
            .blur(radius: isVisible ? 0 : 5)
            .animation(
                .spring(response: 0.58, dampingFraction: 0.84)
                    .delay(delay),
                value: isVisible
            )
            .onAppear { isVisible = true }
    }
}

// MARK: - Edge push transition

struct EdgePushTransition: ViewModifier {
    let edge: Edge
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: edge == .leading ? (isVisible ? 0 : -20) : (edge == .trailing ? (isVisible ? 0 : 20) : 0),
                    y: edge == .top ? (isVisible ? 0 : -20) : (edge == .bottom ? (isVisible ? 0 : 20) : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .onAppear { isVisible = true }
    }
}

// MARK: - Convenience extensions

extension View {
    func pressEffect() -> some View {
        modifier(PressEffect())
    }

    func staggeredEntrance(index: Int) -> some View {
        modifier(StaggeredEntrance(index: index))
    }

    func cardEntrance() -> some View {
        modifier(CardEntrance(delay: 0))
    }

    func cardEntrance(index: Int) -> some View {
        modifier(CardEntrance(delay: min(Double(index) * 0.055, 0.24)))
    }

    func edgePush(from edge: Edge) -> some View {
        modifier(EdgePushTransition(edge: edge))
    }
}
