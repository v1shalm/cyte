import AppKit
import SwiftUI

enum ThemeKind: String, CaseIterable, Identifiable {
    case vishal, cyan, white

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vishal: "Vishal"
        case .cyan: "Cyan"
        case .white: "White"
        }
    }

    var next: ThemeKind {
        let all = ThemeKind.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var kind: ThemeKind {
        didSet { UserDefaults.standard.set(kind.rawValue, forKey: "pool.theme") }
    }

    private init() {
        kind = ThemeKind(rawValue: UserDefaults.standard.string(forKey: "pool.theme") ?? "") ?? .white
    }

    func set(_ kind: ThemeKind) {
        withAnimation(.easeInOut(duration: 0.35)) { self.kind = kind }
    }
}

enum Theme {
    static var bold: Bool { ThemeStore.shared.kind != .white }
    static let yellow = Color(red: 249 / 255, green: 237 / 255, blue: 51 / 255)
    static let cyan = Color(red: 0, green: 232 / 255, blue: 246 / 255)
    static let navy = Color(red: 13 / 255, green: 10 / 255, blue: 44 / 255)

    static func accent(for kind: ThemeKind) -> Color {
        switch kind {
        case .vishal: yellow
        case .cyan: cyan
        case .white: softCanvas
        }
    }

    static func ink(for kind: ThemeKind) -> Color { kind == .cyan ? navy : Color(white: 0.07) }

    static var accent: Color { accent(for: ThemeStore.shared.kind) }

    static let pill = Color(white: 0.17)
    static let softCanvas = Color.white
    static let softFill = Color(red: 0.945, green: 0.945, blue: 0.937)
    static let softFillStrong = Color(red: 0.918, green: 0.918, blue: 0.910)
    static let softHover = Color(red: 0.930, green: 0.930, blue: 0.922)
    static let softTarget = Color(red: 0.902, green: 0.902, blue: 0.894)

    static let surface = Color.white
    static var ink: Color { ink(for: ThemeStore.shared.kind) }
    static let secondary = Color(white: 0.44)
    static let tertiary = Color(white: 0.62)
    static let hairline = Color.black.opacity(0.07)
    static var fill: Color { bold ? Color(red: 0.962, green: 0.962, blue: 0.955) : softFill }
    static var fillStrong: Color { bold ? Color(red: 0.93, green: 0.93, blue: 0.922) : softFillStrong }
    static let sidebar = Color(red: 0.984, green: 0.984, blue: 0.978)

    static var canvas: Color { accent }
    static let note = Color.white
    static var panel: Color { bold ? ink : .white }
    static var sideInk: Color { bold ? .white : ink }
    static var sideSecondary: Color { bold ? .white.opacity(0.62) : secondary }
    static var sideTertiary: Color { bold ? .white.opacity(0.4) : tertiary }
    static var sideHover: Color { bold ? .white.opacity(0.08) : softHover }
    static var sideTarget: Color { bold ? .white.opacity(0.14) : softTarget }
    static var sideStroke: Color { bold ? .white.opacity(0.06) : hairline }

    static var control: Color { bold ? ink : .white }
    static var controlHover: Color { bold ? ink.opacity(0.86) : softFill }
    static var controlText: Color { bold ? .white : ink }
    static var controlMuted: Color { bold ? .white.opacity(0.58) : tertiary }
    static var controlChip: Color { bold ? .white.opacity(0.12) : softFillStrong }
    static var controlShadow: Double { bold ? 0.1 : 0.07 }

    static var tabPill: Color { bold ? accent : .white }
    static var tabIdle: Color { bold ? .white.opacity(0.6) : secondary }
    static var tabPillShadow: Double { bold ? 0 : 0.14 }

    static var rowSelection: Color { bold ? accent.opacity(0.42) : softFill }
    static var folderSelection: Color { bold ? accent : .white }
    static var folderSelectionShadow: Double { bold ? 0 : 0.1 }

    static var paletteBackdrop: Color { bold ? accent.opacity(0.45) : softCanvas.opacity(0.55) }
    static var sheetBackdrop: Color { bold ? accent.opacity(0.45) : Color.white.opacity(0.55) }
    static var dropDash: Color { bold ? ink.opacity(0.3) : ink.opacity(0.14) }
    static var detailBackdrop: Color { bold ? accent.opacity(0.95) : softCanvas.opacity(0.97) }

    static var action: Color { bold ? ink : .white }
    static var chip: Color { bold ? ink.opacity(0.05) : softFill }
    static var actionIcon: Color { bold ? .white : ink }
    static var secondaryFill: Color { bold ? surface : fill }
    static var secondaryStroke: Color { bold ? ink.opacity(0.12) : hairline }
    static var field: Color { bold ? surface : fill }
    static func fieldTile(hovering: Bool) -> Color { bold ? surface.opacity(hovering ? 1 : 0.8) : (hovering ? fillStrong : fill) }

    static let tileRadius: CGFloat = 14
    static let gap: CGFloat = 20
    static let sideInset: CGFloat = 40
    static var topInset: CGFloat { 132 + (AppModel.shared.tagRow.isEmpty ? 0 : 52) }

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
        if active && !Theme.bold {
            content
                .overlay(shape.strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(shadow), radius: shadow > 0 ? 4 : 0, y: shadow > 0 ? 1 : 0)
        } else {
            content
        }
    }
}

extension View {
    func poolPrimary() -> some View { buttonStyle(PrimaryButtonStyle()) }

    func poolSecondary() -> some View { buttonStyle(SecondaryButtonStyle()) }

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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(Capsule().fill(Theme.ink))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(Capsule().fill(Theme.secondaryFill))
            .overlay(Capsule().strokeBorder(Theme.secondaryStroke))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(Capsule())
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
