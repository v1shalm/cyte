import SwiftUI

struct BorderBeam: ViewModifier {
    enum Size { case md, sm, line, pulseInner, pulseOutside }
    enum Palette {
        case accent, ink, silver, pearl

        var colors: [Color] {
            switch self {
            case .accent: Palette.ink.colors
            case .ink: [Color(white: 0.55), Color(white: 0.22), Color(white: 0.04)]
            case .silver: [Color(white: 0.86), Color(red: 0.70, green: 0.72, blue: 0.75), Color(white: 0.42)]
            case .pearl: [Color(white: 1, opacity: 0.6), Color(red: 0.93, green: 0.95, blue: 0.98), .white]
            }
        }
    }

    var size: Size = .md
    var palette: Palette = .accent
    var strength: Double = 0.7
    var active = true
    var cornerRadius: CGFloat = 12
    var duration: Double = 2.6
    var laps: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    let progress = elapsed / duration
                    let fade = laps.map { limit in max(0, min(1, (limit - progress) * 2.5)) } ?? 1
                    beam(progress: progress)
                        .opacity(fade * (reduceMotion ? 0.6 : 1))
                }
                .allowsHitTesting(false)
                .onAppear { start = Date() }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: active)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    private var lineWidth: CGFloat {
        switch size {
        case .md: 1.6
        case .sm: 1
        case .line: 1.4
        case .pulseInner, .pulseOutside: 1.2
        }
    }

    @ViewBuilder private func beam(progress: Double) -> some View {
        switch size {
        case .md, .sm:
            let gradient = comet(angle: progress * 360)
            ZStack {
                shape.strokeBorder(gradient, lineWidth: lineWidth)
                shape.strokeBorder(gradient, lineWidth: lineWidth * 3)
                    .blur(radius: size == .md ? 7 : 4)
                    .opacity(strength)
            }
        case .line:
            GeometryReader { proxy in
                let travel = proxy.size.width * 1.4
                let x = (progress.truncatingRemainder(dividingBy: 1)) * travel - proxy.size.width * 0.2
                Capsule()
                    .fill(LinearGradient(colors: [.clear] + palette.colors + [.clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * 0.35, height: lineWidth)
                    .shadow(color: palette.colors[1].opacity(strength), radius: 6)
                    .offset(x: x - proxy.size.width * 0.175, y: proxy.size.height - lineWidth)
            }
            .clipShape(shape)
        case .pulseInner:
            let breath = 0.5 + 0.5 * sin(progress * .pi * 2)
            shape.strokeBorder(palette.colors[1], lineWidth: 6 + 6 * breath)
                .blur(radius: 10)
                .opacity(strength * (0.35 + 0.65 * breath))
                .clipShape(shape)
        case .pulseOutside:
            let breath = 0.5 + 0.5 * sin(progress * .pi * 2)
            shape.stroke(palette.colors[1], lineWidth: 2 + 4 * breath)
                .blur(radius: 8 + 6 * breath)
                .opacity(strength * (0.3 + 0.7 * breath))
        }
    }

    private func comet(angle: Double, colors custom: [Color]? = nil) -> AngularGradient {
        let colors = custom ?? palette.colors
        return AngularGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.62),
                .init(color: colors[0].opacity(0.5), location: 0.8),
                .init(color: colors[1], location: 0.93),
                .init(color: colors[2], location: 0.985),
                .init(color: .clear, location: 1),
            ],
            center: .center,
            angle: .degrees(angle)
        )
    }
}

extension View {
    func borderBeam(
        size: BorderBeam.Size = .md, palette: BorderBeam.Palette = .accent, strength: Double = 0.7,
        active: Bool = true, cornerRadius: CGFloat = 12, duration: Double = 2.6, laps: Double? = nil
    ) -> some View {
        modifier(BorderBeam(size: size, palette: palette, strength: strength, active: active,
                            cornerRadius: cornerRadius, duration: duration, laps: laps))
    }
}
