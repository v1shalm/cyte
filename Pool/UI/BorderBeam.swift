import SwiftUI

struct BorderBeam: ViewModifier {
    enum Size { case md, sm, line, pulseInner, pulseOutside }
    enum Palette {
        case accent, sun, sea, ink, silver, pearl

        var colors: [Color] {
            switch self {
            case .accent:
                switch ThemeStore.shared.kind {
                case .vishal: Palette.sun.colors
                case .cyan: Palette.sea.colors
                case .white: Palette.ink.colors
                }
            case .sea: [Color(red: 0.6, green: 0.97, blue: 1), Color(red: 0, green: 232 / 255, blue: 246 / 255), Color(red: 0, green: 0.62, blue: 0.95)]
            case .sun: [Color(red: 0.99, green: 0.96, blue: 0.62), Color(red: 249 / 255, green: 237 / 255, blue: 51 / 255), Color(red: 0.92, green: 0.78, blue: 0)]
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
        case .md: railed ? 2.5 : 1.6
        case .sm: railed ? 2 : 1
        case .line: 1.4
        case .pulseInner, .pulseOutside: 1.2
        }
    }

    private var railed: Bool { palette == .accent && Theme.bold }

    @ViewBuilder private func beam(progress: Double) -> some View {
        switch size {
        case .md, .sm:
            if railed {
                if ThemeStore.shared.kind == .cyan {
                    ShaderGlow(time: progress * duration, cornerRadius: cornerRadius, compact: size == .sm)
                } else {
                    SiriGlow(time: progress * duration, cornerRadius: cornerRadius, compact: size == .sm, strength: strength)
                }
            } else {
                let gradient = comet(angle: progress * 360)
                ZStack {
                    shape.strokeBorder(gradient, lineWidth: lineWidth)
                    shape.strokeBorder(gradient, lineWidth: lineWidth * 3)
                        .blur(radius: size == .md ? 7 : 4)
                        .opacity(strength)
                }
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

struct SiriGlow: View {
    let time: Double
    let cornerRadius: CGFloat
    let compact: Bool
    let strength: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let flow = AngularGradient(stops: stops, center: .center, angle: .degrees(time * 40))
        let breath = 1 + 0.15 * sin(time * 2.1)
        let scale: CGFloat = compact ? 0.55 : 1
        ZStack {
            shape.strokeBorder(flow, lineWidth: 12 * scale * breath)
                .blur(radius: 9 * scale)
            shape.strokeBorder(flow, lineWidth: 7 * scale * breath)
                .blur(radius: 4 * scale)
            shape.strokeBorder(Theme.yellow, lineWidth: 5 * scale)
                .blur(radius: 1.5 * scale)
            shape.strokeBorder(Theme.yellow, lineWidth: 3 * scale * breath)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }

    private var stops: [Gradient.Stop] {
        let count = 5
        var result: [Gradient.Stop] = [.init(color: Theme.yellow.opacity(0.35), location: 0)]
        for index in 0..<count {
            let slot = (Double(index) + 0.5) / Double(count)
            let drift = 0.3 / Double(count) * sin(time * (0.9 + Double(index) * 0.23) + Double(index) * 1.9)
            result.append(.init(color: index.isMultiple(of: 2) ? Theme.yellow : Theme.yellow.opacity(0.35), location: slot + drift))
        }
        result.append(.init(color: Theme.yellow.opacity(0.35), location: 1))
        return result
    }
}

struct ShaderGlow: View {
    let time: Double
    let cornerRadius: CGFloat
    let compact: Bool

    private static let clear = Color(red: 0, green: 232 / 255, blue: 246 / 255).opacity(0)
    private static let core = Color(red: 0, green: 232 / 255, blue: 246 / 255)
    private static let deep = Color(red: 0, green: 0.7, blue: 0.98)
    private static let mist = Color(red: 0.55, green: 0.96, blue: 1)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let t = Float(time)
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + 0.22 * sin(t * 0.9), 0], [1, 0],
            [0, 0.5 + 0.25 * sin(t * 1.1 + 1)], [0.5 + 0.3 * sin(t * 0.7 + 2), 0.5 + 0.3 * cos(t * 0.8)], [1, 0.5 + 0.25 * cos(t * 1.2)],
            [0, 1], [0.5 + 0.22 * cos(t * 0.95 + 0.5), 1], [1, 1],
        ]
        let phase = Int(time * 0.6) % 4
        let palette: [Color] = [Self.core, Self.clear, Self.deep, Self.mist]
        let colors: [Color] = (0..<9).map { index in
            index == 4 ? Self.clear : palette[(index + phase) % palette.count]
        }
        MeshGradient(width: 3, height: 3, points: points, colors: colors, smoothsColors: true)
            .animation(.easeInOut(duration: 1.6), value: phase)
            .mask {
                ZStack {
                    shape.strokeBorder(.white, lineWidth: compact ? 8 : 22)
                        .blur(radius: compact ? 5 : 14)
                    shape.strokeBorder(.white, lineWidth: compact ? 2 : 3)
                }
            }
            .clipShape(shape)
            .allowsHitTesting(false)
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
