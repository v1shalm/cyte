import SwiftUI

struct PillSoftStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.white.opacity(configuration.isPressed ? 0.3 : 0.2)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct PillSolidStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.85 : 1)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct QuestionPill: View {
    let message: String
    let soft: String?
    let solid: String
    var onSoft: () -> Void = {}
    let onSolid: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        HStack(spacing: 16) {
            Text(message)
                .font(Theme.ui(14))
                .foregroundStyle(.white)
                .padding(.leading, 10)
            HStack(spacing: 6) {
                if let soft {
                    Button(soft, action: onSoft).buttonStyle(PillSoftStyle())
                }
                Button(solid, action: onSolid).buttonStyle(PillSolidStyle())
            }
        }
        .fixedSize()
        .padding(8)
        .background(Capsule().fill(Theme.pill))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .scaleEffect(shown || reduceMotion ? 1 : 0.82)
        .opacity(shown ? 1 : 0)
        .blur(radius: shown || reduceMotion ? 0 : 6)
        .onAppear { withAnimation(reduceMotion ? Theme.fade : .spring(duration: 0.5, bounce: 0.3)) { shown = true } }
    }
}
