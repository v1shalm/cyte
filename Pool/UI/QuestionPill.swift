import SwiftUI

struct PillSoftStyle: ButtonStyle {
    var segment: Segment = .first

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(segment.shape(16).fill(.white.opacity(configuration.isPressed ? 0.3 : 0.2)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(segment.shape(16))
    }
}

struct PillSolidStyle: ButtonStyle {
    var segment: Segment = .alone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(segment.shape(16).fill(.white.opacity(configuration.isPressed ? 0.85 : 1)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.press, value: configuration.isPressed)
            .contentShape(segment.shape(16))
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
            HStack(spacing: 2) {
                if let soft {
                    Button(soft, action: onSoft).buttonStyle(PillSoftStyle(segment: .first))
                }
                Button(solid, action: onSolid).buttonStyle(PillSolidStyle(segment: soft == nil ? .alone : .last))
            }
        }
        .fixedSize()
        .padding(8)
        .background(Capsule().fill(Theme.pill))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .scaleEffect(shown || reduceMotion ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .blur(radius: shown || reduceMotion ? 0 : 4)
        .onAppear { withAnimation(reduceMotion ? Theme.fade : Theme.pop) { shown = true } }
    }
}
