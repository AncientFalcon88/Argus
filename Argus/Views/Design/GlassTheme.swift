import SwiftUI

enum GlassTheme {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.65)
    static let stroke = Color.white.opacity(0.2)
}

struct AppBackground: View {
    var body: some View {
        GlassTheme.background
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
            }
            .ignoresSafeArea()
    }
}

/// Liquid Glass: ultra-thin material fill with a 1pt hairline stroke.
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlassTheme.stroke, lineWidth: 1)
            }
    }
}

typealias GlassCardModifier = LiquidGlassModifier

extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        liquidGlass(cornerRadius: cornerRadius)
    }

    func richLiquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                ZStack {
                    Rectangle().fill(.thinMaterial)
                    
                    // Subtle dark gradient for depth, removing the white glare
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.3), location: 0.8),
                            .init(color: .black.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Thick border without white coloring (using grays instead)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .gray.opacity(0.6), location: 0.0),
                                .init(color: .gray.opacity(0.2), location: 0.2),
                                .init(color: .gray.opacity(0.1), location: 0.5),
                                .init(color: .gray.opacity(0.2), location: 0.8),
                                .init(color: .gray.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // Inner rim for 3D thickness
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                    .padding(1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 10)
            )
    }

    func activeLiquidGlass(isActive: Bool, cornerRadius: CGFloat = 16, activeColor: Color = .blue) -> some View {
        self
            .background(isActive ? activeColor.opacity(0.3) : .white.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? activeColor.opacity(0.8) : .white.opacity(0.2), lineWidth: 1)
            )
    }
}

