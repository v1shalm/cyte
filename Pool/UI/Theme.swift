import AppKit
import SwiftUI

enum TextSize {
    static let caption: CGFloat = 11
    static let small: CGFloat = 12
    static let body: CGFloat = 13
    static let large: CGFloat = 14
}

enum TitleSize {
    static let heading: CGFloat = 20
    static let title: CGFloat = 26
    static let display: CGFloat = 34
}

enum Control {
    static let small: CGFloat = 28
    static let regular: CGFloat = 34
    static let large: CGFloat = 40
    static let row: CGFloat = 34
}

enum Radius {
    static let row: CGFloat = 12
    static let panel: CGFloat = 20
    static let sheet: CGFloat = 22
    static let field: CGFloat = 12
}

enum Theme {
    static let pill = Color(red: 0.16, green: 0.17, blue: 0.20)
    static let softCanvas = Color.white
    static let softFill = Color(red: 234 / 255, green: 235 / 255, blue: 239 / 255)
    static let softFillStrong = Color(red: 228 / 255, green: 229 / 255, blue: 234 / 255)
    static let softHover = Color(red: 240 / 255, green: 241 / 255, blue: 245 / 255)
    static let softTarget = Color(red: 223 / 255, green: 224 / 255, blue: 230 / 255)

    static let ink = Color(red: 0.066, green: 0.074, blue: 0.095)
    static let surface = Color.white
    static let inkHover = Color(red: 0.2, green: 0.21, blue: 0.24)
    static let secondary = Color(red: 0.34, green: 0.37, blue: 0.43)
    static let tertiary = Color(red: 0.42, green: 0.45, blue: 0.51)
    static let faint = Color(red: 0.60, green: 0.63, blue: 0.69)
    static let hairline = Color(red: 0.12, green: 0.12, blue: 0.26).opacity(0.085)
    static let fill = softFill
    static let fillStrong = softFillStrong
    static let sidebar = Color(red: 0.976, green: 0.976, blue: 0.984)

    static let canvas = Color.white
    static let note = Color.white
    static let panel = Color.white
    static let sideInk = ink
    static let sideTertiary = tertiary
    static let sideHover = softHover
    static let sideStroke = hairline


    static let tabPill = Color.white
    static let tabIdle = secondary
    static let tabPillShadow = 0.14


    static let scrim = Color.white.opacity(0.82)
    static let paletteBackdrop = softCanvas.opacity(0.55)
    static let dropDash = ink.opacity(0.18)
    static let detailBackdrop = softCanvas.opacity(0.97)


    static let tileRadius: CGFloat = 14
    static let gap: CGFloat = 20
    static let sideInset: CGFloat = 40
    static let topInset: CGFloat = 128

    static let open = Animation.spring(duration: 0.42, bounce: 0)
    static let reflow = Animation.spring(duration: 0.45, bounce: 0)
    static let settle = Animation.spring(duration: 0.3, bounce: 0)
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    static let hover = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.15)
    static let fade = Animation.easeOut(duration: 0.2)
    static let pop = Animation.spring(duration: 0.35, bounce: 0.15)
    static let enter = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    static let exit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    static let pressScale: CGFloat = 0.96

    static func serif(_ size: CGFloat, light: Bool = false) -> Font {
        let cut = size < 24 ? "TimelessSerif-Text" : "TimelessSerif-"
        return .custom(cut + (light ? "Light" : "Regular"), size: size)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light, .thin, .ultraLight: name = "TimelessSans-GroteskLight"
        case .medium: name = "TimelessSans-GroteskMedium"
        case .semibold: name = "TimelessSans-GroteskSemibold"
        case .bold, .heavy, .black: name = "TimelessSans-GroteskBold"
        default: name = "TimelessSans-GroteskRegular"
        }
        return .custom(name, size: size)
    }

    static func color(hex: String) -> Color {
        guard let rgb = Palette.rgb(hex) else { return fill }
        return Color(red: Double(rgb.x) / 255, green: Double(rgb.y) / 255, blue: Double(rgb.z) / 255)
    }
}

struct Lifted<S: InsettableShape>: ViewModifier {
    let shape: S
    var active = true
    var shadow: Double = 0.05

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(shape.strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(shadow), radius: shadow > 0 ? 4 : 0, y: shadow > 0 ? 1 : 0)
        } else {
            content
        }
    }
}

struct CardShadow: ViewModifier {
    var radius: CGFloat = Theme.tileRadius
    var hovering = false

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(hovering ? 0.05 : 0.03), radius: 1.5, y: 1)
                .shadow(color: .black.opacity(hovering ? 0.09 : 0.05), radius: hovering ? 22 : 14, y: hovering ? 11 : 6)
        }
    }
}

extension View {
    func cardShadow(radius: CGFloat = Theme.tileRadius, hovering: Bool = false) -> some View {
        modifier(CardShadow(radius: radius, hovering: hovering))
    }

    func poolPrimary(_ segment: Segment = .alone) -> some View { buttonStyle(PrimaryButtonStyle(segment: segment)) }

    func poolSecondary(_ segment: Segment = .alone, active: Bool = false) -> some View { buttonStyle(SecondaryButtonStyle(segment: segment, active: active)) }

    func floatingPanel(radius: CGFloat = Radius.panel) -> some View { modifier(FloatingPanel(radius: radius)) }

    func lifted<S: InsettableShape>(_ shape: S, active: Bool = true, shadow: Double = 0.05) -> some View {
        modifier(Lifted(shape: shape, active: active, shadow: shadow))
    }
}

struct PressStyle: ButtonStyle {
    var scale: CGFloat = Theme.pressScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var segment: Segment = .alone

    func makeBody(configuration: Configuration) -> some View {
        ButtonFace(configuration: configuration, segment: segment, prominent: true, active: false)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var segment: Segment = .alone
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        ButtonFace(configuration: configuration, segment: segment, prominent: false, active: active)
    }
}

private struct ButtonFace: View {
    let configuration: ButtonStyleConfiguration
    let segment: Segment
    let prominent: Bool
    let active: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    var body: some View {
        let shape = segment.shape(Control.regular / 2)
        configuration.label
            .font(Theme.ui(TextSize.body, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: Control.regular)
            .background(shape.fill(fill))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? Theme.pressScale : 1)
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(Theme.press, value: configuration.isPressed)
            .animation(Theme.hover, value: hovering)
            .animation(Theme.hover, value: active)
    }

    private var fill: Color {
        let lit = (hovering && enabled) || active
        if prominent { return lit ? Theme.inkHover : Theme.ink }
        return lit ? Theme.softFillStrong : Theme.softFill
    }
}

struct ChipStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        ChipFace(configuration: configuration, active: active)
    }
}

private struct ChipFace: View {
    let configuration: ButtonStyleConfiguration
    let active: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(Theme.ui(TextSize.small, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(active ? Color.white : Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: Control.small)
            .background(Capsule().fill(active ? Theme.ink : (hovering && enabled ? Theme.softFillStrong : Theme.softFill)))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? Theme.pressScale : 1)
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(Theme.press, value: configuration.isPressed)
            .animation(Theme.hover, value: hovering)
            .animation(Theme.hover, value: active)
    }
}

struct RowStyle: ButtonStyle {
    var selected = false
    var radius: CGFloat = Radius.row

    func makeBody(configuration: Configuration) -> some View {
        RowFace(configuration: configuration, selected: selected, radius: radius)
    }
}

private struct RowFace: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let radius: CGFloat
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(Theme.ui(TextSize.body, weight: selected ? .medium : .regular))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: Control.row, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(selected ? Theme.softFill : (hovering ? Theme.softHover : .clear)))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { hovering = $0 }
            .animation(Theme.hover, value: hovering)
    }
}

struct FloatingPanel: ViewModifier {
    var radius: CGFloat = Radius.panel

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.11), radius: 28, y: 12)
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.ui(TextSize.caption, weight: .medium))
            .foregroundStyle(Theme.tertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, .white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.4)
                }
                .clipped()
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.2 }
                }
            }
        }
    }
}

extension View {
    func shimmer(_ active: Bool) -> some View {
        modifier(ShimmerIf(active: active))
    }
}

private struct ShimmerIf: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.modifier(Shimmer()) } else { content }
    }
}

enum Segment {
    case alone, first, middle, last

    static func at(_ index: Int, of count: Int) -> Segment {
        if count <= 1 { return .alone }
        return index == 0 ? .first : (index == count - 1 ? .last : .middle)
    }

    func shape(_ outer: CGFloat, inner: CGFloat = 5) -> UnevenRoundedRectangle {
        let left = (self == .alone || self == .first) ? outer : inner
        let right = (self == .alone || self == .last) ? outer : inner
        return UnevenRoundedRectangle(topLeadingRadius: left, bottomLeadingRadius: left, bottomTrailingRadius: right, topTrailingRadius: right, style: .continuous)
    }
}
