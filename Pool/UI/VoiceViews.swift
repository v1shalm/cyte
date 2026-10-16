import SwiftUI

struct VoiceOrb: View {
    var level: Double
    var active: Bool
    var size: CGFloat = 120
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !active || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let base = size * 0.26
                let swell = 1 + level * 0.55
                context.addFilter(.alphaThreshold(min: 0.5, color: Theme.ink))
                context.addFilter(.blur(radius: size * 0.06))
                context.drawLayer { layer in
                    let core = base * swell
                    layer.fill(Circle().path(in: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)),
                               with: .color(.black))
                    for index in 0..<5 {
                        let phase = Double(index) * 1.2566
                        let speed = 0.7 + Double(index) * 0.18
                        let reach = base * (0.55 + level * 0.9) * (0.7 + 0.3 * sin(time * 1.3 + phase))
                        let angle = time * speed + phase
                        let radius = base * (0.42 + 0.18 * sin(time * 2.1 + phase))
                        let point = CGPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach)
                        layer.fill(Circle().path(in: CGRect(x: point.x - radius, y: point.y - radius,
                                                            width: radius * 2, height: radius * 2)),
                                   with: .color(.black))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VoiceNoteOverlay: View {
    @Environment(AppModel.self) private var model
    @State private var voice = VoiceInput()
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.canvas.opacity(0.94)
                .ignoresSafeArea()
                .onTapGesture(perform: discard)

            VStack(spacing: 30) {
                VoiceOrb(level: voice.level, active: voice.isListening, size: 150)
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)

                Group {
                    if voice.transcript.isEmpty {
                        Text(message)
                            .font(Theme.serif(30, light: true))
                            .foregroundStyle(Theme.tertiary)
                    } else {
                        Text(voice.transcript)
                            .font(Theme.serif(30, light: true))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.interpolate)
                            .animation(.easeOut(duration: 0.2), value: voice.transcript)
                    }
                }
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: 640)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(L.Voice.discard, action: discard)
                        .poolSecondary()
                        .keyboardShortcut(.cancelAction)
                    Button(L.Voice.save, action: save)
                        .poolPrimary()
                        .keyboardShortcut(.defaultAction)
                        .disabled(voice.transcript.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .opacity(shown ? 1 : 0)
            }
            .padding(40)
        }
        .task {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { shown = true }
            await voice.start()
        }
        .onDisappear { voice.cancel() }
    }

    private var message: String {
        switch voice.phase {
        case .denied: L.Voice.denied
        case .failed: L.Voice.failed
        default: L.Voice.listening
        }
    }

    private func save() {
        let text = voice.stop()
        model.ingestor.addNote(text)
        model.voiceNoteShown = false
    }

    private func discard() {
        voice.cancel()
        model.voiceNoteShown = false
    }
}

struct MicButton: View {
    let listening: Bool
    let level: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if listening {
                    Circle()
                        .fill(Theme.ink.opacity(0.1))
                        .scaleEffect(1 + level * 0.8)
                        .animation(.spring(duration: 0.18, bounce: 0), value: level)
                }
                Image(systemName: listening ? "waveform" : "mic")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(listening ? Theme.ink : Theme.tertiary)
                    .symbolEffect(.variableColor.iterative, isActive: listening)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .help(listening ? L.Voice.stop : L.Voice.search)
    }
}
