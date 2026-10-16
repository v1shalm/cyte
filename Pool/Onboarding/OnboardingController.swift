import AppKit
import SpriteKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OnboardingController {
    static let shared = OnboardingController()

    static var completed: Bool {
        get { UserDefaults.standard.bool(forKey: "pool.onboarded") }
        set { UserDefaults.standard.set(newValue, forKey: "pool.onboarded") }
    }

    private var panel: OverlayPanel?
    private var hidden: [NSWindow] = []

    func present(model: AppModel) {
        guard panel == nil, let screen = NSScreen.main else { return }

        hidden = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }
        hidden.forEach { $0.orderOut(nil) }

        let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setFrame(screen.frame, display: true)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let scene = OnboardingScene(size: screen.frame.size, reduceMotion: reduceMotion)
        let root = OnboardingView(
            scene: scene,
            chooseFolder: { [weak self] in await self?.chooseFolder() },
            promptMode: { [weak self] asking in self?.panel?.level = asking ? .normal : .screenSaver },
            finish: { [weak self] in self?.finish() }
        )
        .environment(model)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func chooseFolder() async -> URL? {
        guard let panel else { return nil }
        let open = NSOpenPanel()
        open.canChooseDirectories = true
        open.canChooseFiles = false
        open.canCreateDirectories = true
        open.prompt = L.Onboarding.librarySecondary
        let response = await open.beginSheetModal(for: panel)
        return response == .OK ? open.url : nil
    }

    private func finish() {
        Self.completed = true
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        let windows = hidden.isEmpty ? NSApp.windows.filter { $0.canBecomeMain && !($0 is NSPanel) } : hidden
        hidden = []
        NSApp.activate()
        windows.forEach { window in
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
                window.animator().alphaValue = 1
            }
        }
    }
}
