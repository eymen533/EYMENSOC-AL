import SwiftUI

/// Crash-safe map — Canvas only (no MapKit, no WKWebView).
struct SoftMapView: View {
    var heading: Double
    var pulsePhase: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate + pulsePhase
            let drift = CGFloat(t.truncatingRemainder(dividingBy: 14) / 14)
            let pulse = 0.9 + 0.1 * sin(t * 2.0)

            Canvas { ctx, size in
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.90, green: 0.89, blue: 0.86))
                )

                let ox = drift * 28
                var streets = Path()
                for i in -2..<12 {
                    let x = CGFloat(i) * 44 - ox
                    streets.move(to: CGPoint(x: x, y: 0))
                    streets.addLine(to: CGPoint(x: x + size.height * 0.5, y: size.height))
                }
                for j in -2..<10 {
                    let y = CGFloat(j) * 40
                    streets.move(to: CGPoint(x: 0, y: y))
                    streets.addLine(to: CGPoint(x: size.width, y: y + 8))
                }
                ctx.stroke(streets, with: .color(.white.opacity(0.9)), lineWidth: 9)
                ctx.stroke(streets, with: .color(Color(red: 0.80, green: 0.79, blue: 0.76)), lineWidth: 0.8)

                let blocks: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (0.20, 0.22, 0.14, 0.10, 0.16),
                    (0.48, 0.18, 0.16, 0.12, 0.20),
                    (0.72, 0.30, 0.13, 0.10, 0.15),
                    (0.28, 0.52, 0.14, 0.11, 0.18),
                    (0.55, 0.55, 0.17, 0.13, 0.22),
                    (0.78, 0.62, 0.12, 0.09, 0.14),
                    (0.38, 0.78, 0.15, 0.10, 0.16),
                ]
                for b in blocks {
                    drawBuilding(
                        ctx: ctx,
                        x: size.width * b.0,
                        y: size.height * b.1 - drift * 8,
                        w: size.width * b.2,
                        d: size.width * b.3,
                        h: size.height * b.4
                    )
                }

                let ax = size.width * 0.42
                let ay = size.height * 0.70
                var arrow = Path()
                arrow.move(to: CGPoint(x: ax, y: ay - 15 * pulse))
                arrow.addLine(to: CGPoint(x: ax + 11, y: ay + 10))
                arrow.addLine(to: CGPoint(x: ax, y: ay + 4))
                arrow.addLine(to: CGPoint(x: ax - 11, y: ay + 10))
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(Color(red: 0.92, green: 0.18, blue: 0.18)))
                ctx.stroke(arrow, with: .color(.white.opacity(0.9)), lineWidth: 1)

                ctx.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width * 0.14, height: size.height)),
                    with: .linearGradient(
                        Gradient(colors: [Color.black.opacity(0.45), .clear]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width * 0.14, y: 0)
                    )
                )
            }
            .overlay {
                GeometryReader { g in
                    ForEach(Array(["ZEYNEP SK.", "ITIR 1. SK.", "MEVLANA SK."].enumerated()), id: \.offset) { i, name in
                        Text(name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.30))
                            .position(
                                x: g.size.width * (0.30 + CGFloat(i) * 0.22),
                                y: g.size.height * (0.30 + CGFloat(i) * 0.18)
                            )
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func drawBuilding(ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, d: CGFloat, h: CGFloat) {
        let top = Path { p in
            p.move(to: CGPoint(x: x, y: y - h))
            p.addLine(to: CGPoint(x: x + w, y: y - h - d * 0.35))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y - h + d * 0.15))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.closeSubpath()
        }
        let left = Path { p in
            p.move(to: CGPoint(x: x, y: y - h))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y + d * 0.5))
            p.addLine(to: CGPoint(x: x, y: y))
            p.closeSubpath()
        }
        let right = Path { p in
            p.move(to: CGPoint(x: x + d * 0.55, y: y - h + d * 0.5))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y - h + d * 0.15))
            p.addLine(to: CGPoint(x: x + w + d * 0.55, y: y + d * 0.15))
            p.addLine(to: CGPoint(x: x + d * 0.55, y: y + d * 0.5))
            p.closeSubpath()
        }
        ctx.fill(top, with: .color(Color(red: 0.78, green: 0.78, blue: 0.76)))
        ctx.fill(left, with: .color(Color(red: 0.70, green: 0.70, blue: 0.68)))
        ctx.fill(right, with: .color(Color(red: 0.62, green: 0.62, blue: 0.60)))
    }
}
