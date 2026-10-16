import AppKit
import SwiftUI

enum Theme {
    static let pill = Color(red: 0.16, green: 0.17, blue: 0.20)
    static let softCanvas = Color.white
    static let softFill = Color(red: 235 / 255, green: 234 / 255, blue: 239 / 255)
    static let softFillStrong = Color(red: 229 / 255, green: 228 / 255, blue: 234 / 255)
    static let softHover = Color(red: 239 / 255, green: 238 / 255, blue: 243 / 255)
    static let softTarget = Color(red: 224 / 255, green: 223 / 255, blue: 230 / 255)

    static let ink = Color(red: 0.066, green: 0.074, blue: 0.095)
    static let surface = Color.white
    static let secondary = Color(red: 0.42, green: 0.45, blue: 0.51)
    static let tertiary = Color(red: 0.60, green: 0.63, blue: 0.69)
    static let hairline = Color(red: 0.12, green: 0.12, blue: 0.26).opacity(0.085)
    static let fill = softFill
    static let fillStrong = softFillStrong
    static let sidebar = Color(red: 0.976, green: 0.976, blue: 0.984)

    static let canvas = Color.white
    static let note = Color.white
    static let panel = Color.white
    static let sideInk = ink
    static let sideSecondary = secondary
    static let sideTertiary = tertiary
    static let sideHover = softHover
    static let sideTarget = softTarget
    static let sideStroke = hairline

    static let control = Color.white
    static let controlHover = softFill
    static let controlText = ink
    static let controlMuted = tertiary
    static let controlChip = softFillStrong
    static let controlShadow = 0.07

    static let tabPill = Color.white
    static let tabIdle = secondary
    static let tabPillShadow = 0.14

    static let rowSelection = softFill
    static let folderSelection = Color.white
    static let folderSelectionShadow = 0.1

    static let paletteBackdrop = softCanvas.opacity(0.55)
    static let sheetBackdrop = Color.white.opacity(0.55)
    static let dropDash = ink.opacity(0.14)
    static let detailBackdrop = softCanvas.opacity(0.97)

    static let action = Color.white
    static let chip = softFill
    static let actionIcon = ink
    static let secondaryFill = fill
    static let secondaryStroke = hairline
    static let field = fill
    static func fieldTile(hovering: Bool) -> Color { hovering ? fillStrong : fill }

    static let tileRadius: CGFloat = 14
    static let gap: CGFloat = 20
    static let sideInset: CGFloat = 40
    static let topInset: CGFloat = 132

    static let open = Animation.spring(duration: 0.42, bounce: 0)
    static let reflow = Animation.spring(duration: 0.45, bounce: 0)
    static let settle = Animation.spring(duration: 0.3, bounce: 0)
    static let press = Animation.easeOut(duration: 0.12)
    static let hover = Animation.easeOut(duration: 0.18)
    static let fade = Animation.easeOut(duration: 0.2)

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

    func poolSecondary(_ segment: Segment = .alone) -> some View { buttonStyle(SecondaryButtonStyle(segment: segment)) }

    func lifted<S: InsettableShape>(_ shape: S, active: Bool = true, shadow: Double = 0.05) -> some View {
        modifier(Lifted(shape: shape, active: active, shadow: shadow))
    }
}

struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var segment: Segment = .alone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(segment.shape(18).fill(Theme.ink))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(segment.shape(18))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var segment: Segment = .alone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(segment.shape(18).fill(Theme.secondaryFill))
            .overlay(segment.shape(18).strokeBorder(Theme.secondaryStroke))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(segment.shape(18))
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
