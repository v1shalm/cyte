import AppKit
import SpriteKit
import SwiftUI

struct OnboardingView: View {
    enum Step { case welcome, library, done }

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let scene: OnboardingScene
    let chooseFolder: () async -> URL?
    let promptMode: (Bool) -> Void
    let finish: () -> Void

    @State private var step: Step = .welcome
    @State private var veilShown = false
    @State private var typeShown = false
    @State private var leaving = false
    @State private var busy = false
    @State private var soundOn = SoundEngine.shared.enabled
    @State private var libraryNote: String?
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                FrostedVeil()
                    .opacity(veilShown ? 1 : 0)
                    .ignoresSafeArea()

                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()

                typeBlock
                    .padding(.leading, max(72, proxy.size.width * 0.075))
                    .padding(.top, proxy.size.height * 0.15)
                    .allowsHitTesting(!leaving)

                HStack(spacing: 12) {
                    Text(L.Onboarding.skipHint)
                        .font(Theme.ui(12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    Button {
                        soundOn.toggle()
                        SoundEngine.shared.enabled = soundOn
                    } label: {
                        Icon(soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", size: IconSize.sm)
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.white.opacity(0.7)))
                    }
                    .buttonStyle(PressStyle(scale: 0.9))
                    .help(L.Onboarding.sound)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .opacity(typeShown && !leaving ? 1 : 0)
                .animation(Theme.fade, value: typeShown)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.escape) {
            leave()
            return .handled
        }
        .task { await start() }
    }

    private var typeBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Theme.serif(104, light: true))
                .tracking(-2.4)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Rise(shown: typeShown, delay: 0, reduce: reduceMotion))

            Text(subtitle)
                .font(Theme.ui(24))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(5)
                .frame(maxWidth: 620, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .modifier(Rise(shown: typeShown, delay: 0.08, reduce: reduceMotion))

            actions
                .padding(.top, 44)
                .disabled(busy)
                .modifier(Rise(shown: typeShown, delay: 0.16, reduce: reduceMotion))
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 22) {
            switch step {
            case .welcome:
                BigButton(title: L.Onboarding.welcomePrimary, busy: busy) { Task { await showScreenshots() } }
                TextLink(title: L.Onboarding.welcomeSecondary) { go(to: .library) }
            case .library:
                BigButton(title: L.Onboarding.libraryPrimary, busy: busy) { Task { await useICloud() } }
                TextLink(title: L.Onboarding.librarySecondary) { Task { await pickFolder() } }
            case .done:
                BigButton(title: L.Onboarding.doneButton, busy: false) { leave() }
            }
        }
    }

    private var title: String {
        switch step {
        case .welcome: L.Onboarding.welcomeTitle(Self.firstName)
        case .library: L.Onboarding.libraryTitle
        case .done: L.Onboarding.doneTitle
        }
    }

    private var subtitle: String {
        switch step {
        case .welcome: L.Onboarding.welcomeBody
        case .library: libraryNote ?? L.Onboarding.libraryBody
        case .done: L.Onboarding.doneBody
        }
    }

    private func start() async {
        focused = true
        withAnimation(.easeOut(duration: 0.6)) { veilShown = true }
        let wallpapers = await TileArt.load(Array(TileArt.wallpaperThumbnails.prefix(28)), maxPixel: 420)
        scene.rain(wallpapers, count: scene.tileCount(fill: 0.2))
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 900))
        typeShown = true
    }

    private func go(to next: Step) {
        guard next != step else { return }
        Task {
            typeShown = false
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 220))
            step = next
            if next == .done { SoundEngine.shared.play(.chime, volume: 0.8) }
            typeShown = true
        }
    }

    private func showScreenshots() async {
        busy = true
        defer { busy = false }
        promptMode(true)
        let urls = await ScreenshotWatcher.recentImagesInBackground(limit: 40)
        promptMode(false)
        focused = true
        model.startScreenshots()
        let images = await TileArt.load(urls, maxPixel: 560)
        if !images.isEmpty {
            scene.rain(images, count: min(scene.tileCount(fill: 0.26), max(images.count, 16)), interval: 0.05)
            try? await Task.sleep(for: .milliseconds(700))
        }
        go(to: .library)
    }

    private func useICloud() async {
        busy = true
        defer { busy = false }
        if let target = LibraryLocation.iCloudDefault {
            await model.reopenLibrary(at: target)
            go(to: .done)
        } else if libraryNote == nil {
            libraryNote = L.Onboarding.libraryNoICloud
        } else {
            await model.reopenLibrary(at: LibraryLocation.homeDefault)
            go(to: .done)
        }
    }

    private func pickFolder() async {
        busy = true
        defer { busy = false }
        guard let folder = await chooseFolder() else { return }
        await model.reopenLibrary(at: folder)
        go(to: .done)
    }

    private func leave() {
        guard !leaving else { return }
        leaving = true
        typeShown = false
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) { veilShown = false }
        scene.drain { finish() }
    }

    static var firstName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
    }
}

private struct Rise: ViewModifier {
    let shown: Bool
    let delay: Double
    let reduce: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || reduce ? 0 : 14)
            .offset(y: shown || reduce ? 0 : 28)
            .animation(shown ? .spring(duration: 0.8, bounce: 0.1).delay(delay) : .easeOut(duration: 0.18), value: shown)
    }
}

private struct BigButton: View {
    let title: String
    let busy: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(Theme.ui(17, weight: .medium))
                ZStack {
                    if busy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Icon("arrow.right", size: IconSize.md)
                            .offset(x: hovering ? 3 : 0)
                    }
                }
                .frame(width: 18)
            }
            .foregroundStyle(.white)
            .padding(.leading, 26)
            .padding(.trailing, 22)
            .frame(height: 56)
            .background(Capsule().fill(Theme.ink))
            .shadow(color: .black.opacity(hovering ? 0.28 : 0.18), radius: hovering ? 22 : 14, y: hovering ? 10 : 6)
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .keyboardShortcut(.defaultAction)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

private struct TextLink: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(16, weight: .medium))
                .foregroundStyle(hovering ? Theme.ink : Theme.secondary)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

private struct FrostedVeil: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let effect = NSVisualEffectView()
        effect.material = .fullScreenUI
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .aqua)
        effect.autoresizingMask = [.width, .height]
        container.addSubview(effect)
        let wash = NSView()
        wash.wantsLayer = true
        wash.layer?.backgroundColor = NSColor(white: 1, alpha: 0.42).cgColor
        wash.autoresizingMask = [.width, .height]
        container.addSubview(wash)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.subviews.forEach { $0.frame = nsView.bounds }
    }
}
