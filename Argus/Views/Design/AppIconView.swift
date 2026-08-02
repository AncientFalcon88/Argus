import SwiftUI

/// Shield + film reel mark used in-app and for programmatic icon export.
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ShieldFilmReelShape()
                .fill(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(18)
                .shadow(color: .white.opacity(0.15), radius: 6, y: 2)
        }
    }
}

struct ShieldFilmReelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        path.move(to: CGPoint(x: cx, y: h * 0.06))
        path.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.28),
            control1: CGPoint(x: cx - w * 0.22, y: h * 0.04),
            control2: CGPoint(x: w * 0.08, y: h * 0.14)
        )
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.58))
        path.addCurve(
            to: CGPoint(x: cx, y: h * 0.94),
            control1: CGPoint(x: w * 0.14, y: h * 0.78),
            control2: CGPoint(x: cx - w * 0.18, y: h * 0.9)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.58),
            control1: CGPoint(x: cx + w * 0.18, y: h * 0.9),
            control2: CGPoint(x: w * 0.86, y: h * 0.78)
        )
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.28))
        path.addCurve(
            to: CGPoint(x: cx, y: h * 0.06),
            control1: CGPoint(x: w * 0.92, y: h * 0.14),
            control2: CGPoint(x: cx + w * 0.22, y: h * 0.04)
        )
        path.closeSubpath()

        let reel = CGRect(x: w * 0.3, y: h * 0.34, width: w * 0.4, height: w * 0.4)
        path.addEllipse(in: reel)
        for i in 0..<4 {
            let angle = Double(i) * .pi / 2
            let hole = CGPoint(
                x: reel.midX + CGFloat(cos(angle)) * reel.width * 0.22,
                y: reel.midY + CGFloat(sin(angle)) * reel.height * 0.22
            )
            path.addEllipse(in: CGRect(x: hole.x - 5, y: hole.y - 5, width: 10, height: 10))
        }
        path.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.46, width: w * 0.12, height: h * 0.08), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: w * 0.8, y: h * 0.46, width: w * 0.12, height: h * 0.08), cornerSize: CGSize(width: 2, height: 2))

        return path
    }
}
