import AppKit
import SwiftUI

struct WhyCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prompt: WhyPrompt

    @FocusState private var focused: Bool
    @State private var bloomed = false
    @State private var badgeWidth: CGFloat = 120
    @State private var restingPointer: CGPoint?

    static let size = CGSize(width: 440, height: 84)
    static let pillHeight: CGFloat = 48

    private var asking: Bool { prompt.stage == .asking }
    private var badgeLabel: String { prompt.stage == .noted ? L.Why.noted : (prompt.ask?.message ?? L.Toast.saved) }

    var body: some View {
        @Bindable var prompt = prompt
        ZStack {
            switch prompt.stage {
            case .saved, .noted:
                badge(badgeLabel)
                    .id(prompt.stage)
                    .transition(swap)
            case .asking:
                card(text: $prompt.text)
                    .transition(swap)
            }
        }
        .frame(width: asking ? Self.size.width : badgeWidth, height: asking ? Self.size.height : Self.pillHeight)
        .background {
            badge(badgeLabel)
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { badgeWidth = $0 }
        }
        .background(shape.fill(Theme.pill))
        .overlay(shape.strokeBorder(.white.opacity(0.08)))
        .clipShape(shape)
        .shadow(color: .black.opacity(asking ? 0.24 : 0.18), radius: asking ? 30 : 18, y: asking ? 14 : 8)
        .environment(\.colorScheme, .dark)
        .scaleEffect(bloomed || reduceMotion ? 1 : 0.9)
        .opacity(bloomed ? 1 : 0)
        .blur(radius: bloomed || reduceMotion ? 0 : 6)
        .animation(reduceMotion ? Theme.fade : Theme.open, value: prompt.stage)
        .animation(reduceMotion ? nil : Theme.settle, value: badgeWidth)
        .onAppear {
            restingPointer = NSEvent.mouseLocation
            withAnimation(reduceMotion ? Theme.fade : Theme.pop) { bloomed = true }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if let start = restingPointer {
                    let now = NSEvent.mouseLocation
                    guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
                    restingPointer = nil
                }
                if !prompt.hovering { prompt.hovering = true }
            case .ended:
                restingPointer = nil
                prompt.hovering = false
            }
        }
        .onChange(of: prompt.stage) { _, stage in
            if stage == .asking, prompt.ask?.takesFocus == true { focused = true }
            if stage != .asking { focused = false }
        }
        .onChange(of: focused) { _, value in prompt.focused = value }
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: asking ? Radius.sheet : Self.pillHeight / 2, style: .continuous)
    }

    private var swap: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: SwapEffect(on: false), identity: SwapEffect(on: true)).animation(Theme.open.delay(0.06)),
            removal: .modifier(active: SwapEffect(on: false), identity: SwapEffect(on: true)).animation(.easeOut(duration: 0.12))
        )
    }

    private func badge(_ label: String) -> some View {
        HStack(spacing: 8) {
            Icon("checkmark", size: IconSize.sm)
                .foregroundStyle(.white)
            Text(label)
                .font(Theme.ui(TextSize.large))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .frame(height: Self.pillHeight)
    }

    private func card(text: Binding<String>) -> some View {
        HStack(spacing: 14) {
            WhyThumbs(ids: prompt.ask?.saveIDs ?? [])
            VStack(alignment: .leading, spacing: 3) {
                Text(context)
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                field(text: text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                micButton
                keepButton
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay(alignment: .bottom) { TimerLine(prompt: prompt).padding(.horizontal, Radius.sheet).padding(.bottom, 7) }
    }

    @ViewBuilder private func field(text: Binding<String>) -> some View {
        if prompt.voice.isListening {
            Text(prompt.voice.transcript.isEmpty ? L.Why.listening : prompt.voice.transcript)
                .font(Theme.ui(15))
                .foregroundStyle(.white.opacity(prompt.voice.transcript.isEmpty ? 0.5 : 1))
                .lineLimit(1)
                .truncationMode(.head)
                .contentTransition(.opacity)
                .animation(Theme.fade, value: prompt.voice.transcript)
        } else {
            TextField("", text: text, prompt: Text(L.Why.question(prompt.count)).foregroundStyle(.white.opacity(0.5)))
                .textFieldStyle(.plain)
                .font(Theme.ui(15))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focused)
                .onSubmit { prompt.submit() }
                .onKeyPress(.escape) {
                    prompt.dismiss()
                    return .handled
                }
                .accessibilityLabel(L.Why.question(prompt.count))
        }
    }

    private var context: String {
        guard let ask = prompt.ask else { return "" }
        if ask.saveIDs.count == 1, let save = model.store.save(id: ask.saveIDs[0]), let host = save.host {
            return L.Why.savedFrom(ask.message, host)
        }
        return ask.saveIDs.count > 1 ? L.Toast.savedMany(ask.saveIDs.count) : ask.message
    }

    private var micButton: some View {
        let listening = prompt.voice.isListening
        return Button { prompt.toggleVoice() } label: {
            Icon(listening ? "waveform" : "mic", size: IconSize.md)
                .foregroundStyle(.white)
                .opacity(listening ? 0.55 + prompt.voice.level * 0.45 : 0.85)
                .frame(width: Control.small + 4, height: Control.small + 4)
                .background(Circle().fill(.white.opacity(listening ? 0.22 : 0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .animation(Theme.hover, value: listening)
        .help(listening ? L.Why.stopListening : L.Why.speak)
        .accessibilityLabel(listening ? L.Why.stopListening : L.Why.speak)
    }

    private var keepButton: some View {
        let ready = prompt.hasText || prompt.voice.isListening
        return Button { prompt.submit() } label: {
            Icon("return", size: IconSize.md)
                .foregroundStyle(ready ? Theme.ink : .white.opacity(0.45))
                .frame(width: Control.small + 4, height: Control.small + 4)
                .background(Circle().fill(ready ? .white : .white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .animation(Theme.hover, value: ready)
        .help(ready ? L.Why.keep : L.Why.skip)
        .accessibilityLabel(ready ? L.Why.keep : L.Why.skip)
    }
}

private struct SwapEffect: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.96)
            .blur(radius: on ? 0 : 4)
    }
}

private struct TimerLine: View {
    let prompt: WhyPrompt

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: prompt.runningSince == nil)) { context in
            let left = prompt.remaining(at: context.date)
            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(prompt.isPaused ? 0.12 : 0.24))
                    .frame(width: proxy.size.width * left)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 2)
        .animation(Theme.hover, value: prompt.isPaused)
        .accessibilityHidden(true)
    }
}

private struct WhyThumbs: View {
    @Environment(AppModel.self) private var model
    let ids: [String]

    var body: some View {
        let shown = Array(ids.prefix(3))
        ZStack {
            ForEach(Array(shown.enumerated()), id: \.element) { index, id in
                let lift = shown.count - 1 - index
                face(model.store.save(id: id))
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.14)))
                    .rotationEffect(.degrees(shown.count == 1 ? 0 : Double(lift) * -7))
                    .offset(x: CGFloat(lift) * -3, y: CGFloat(lift) * -1)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .frame(width: 48, height: 48)
        .animation(Theme.settle, value: ids)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func face(_ save: Save?) -> some View {
        if let save, let thumb = model.store.url(for: save, file: save.thumbnail) {
            Thumb(url: thumb, maxPixel: 128, tint: save.tint)
        } else if let save, save.kind == .link {
            ZStack {
                Color.white.opacity(0.1)
                if let favicon = model.store.url(for: save, file: save.favicon) {
                    Favicon(url: favicon)
                } else {
                    Icon("link", size: IconSize.md).foregroundStyle(.white.opacity(0.7))
                }
            }
            .shimmer(save.pending)
        } else {
            Color.white.opacity(0.1)
        }
    }
}

final class WhyPanel {
    static let shared = WhyPanel()

    private var panel: PalettePanel?
    private var hideTask: Task<Void, Never>?
    private static let size = CGSize(width: 560, height: 220)

    func show(_ prompt: WhyPrompt) {
        hideTask?.cancel()
        let panel = panel ?? make()
        self.panel = panel
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(NSRect(x: visible.midX - Self.size.width / 2, y: visible.minY,
                                  width: Self.size.width, height: Self.size.height), display: false)
        }
        let host = NSHostingView(rootView: WhyPanelHost(prompt: prompt).environment(AppModel.shared))
        host.sizingOptions = []
        panel.contentView = host
        if prompt.ask?.takesFocus == true {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled, let self, AppModel.shared.why.ask == nil else { return }
            panel?.orderOut(nil)
            panel?.contentView = nil
        }
    }

    private func make() -> PalettePanel {
        let panel = PalettePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onResign = { AppModel.shared.why.focused = false }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            MainActor.assumeIsolated { AppModel.shared.why.focused = false }
        }
        return panel
    }
}

private struct WhyPanelHost: View {
    let prompt: WhyPrompt

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let ask = prompt.ask {
                WhyCard(prompt: prompt)
                    .id(ask.id)
                    .transition(WhyCard.exit)
            }
        }
        .padding(.bottom, ToastHost.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.35, bounce: 0), value: prompt.ask?.id)
        .preferredColorScheme(.light)
    }
}

extension WhyCard {
    static var exit: AnyTransition {
        .asymmetric(insertion: .identity, removal: .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: 12)))
    }
}
