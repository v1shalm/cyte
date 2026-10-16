import AppKit
import SwiftUI

enum Chrome {
    static let barHeight: CGFloat = 52
    static let lightsLeading: CGFloat = 22
    static let lightsSpacing: CGFloat = 20
    static let lightsWidth: CGFloat = lightsLeading + lightsSpacing * 2 + 14
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ nsView: ChromeView, context: Context) { nsView.layoutLights() }
}

final class ChromeView: NSView {
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        guard let window else { return }
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
        ]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.layoutLights() }
            })
        }
        DispatchQueue.main.async { [weak self] in self?.layoutLights() }
    }

    func layoutLights() {
        guard let window, !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let titlebar = close.superview, let container = titlebar.superview else { return }
        var frame = container.frame
        frame.size.height = Chrome.barHeight
        frame.origin.y = window.frame.height - Chrome.barHeight
        container.frame = frame
        titlebar.frame = container.bounds
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for (index, type) in buttons.enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            button.setFrameOrigin(NSPoint(
                x: Chrome.lightsLeading + CGFloat(index) * Chrome.lightsSpacing,
                y: (Chrome.barHeight - button.frame.height) / 2
            ))
        }
    }

    isolated deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

struct SidebarToggle: View {
    @Environment(AppModel.self) private var model
    var onPanel = false
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.42, bounce: 0.1)) { model.sidebarShown.toggle() }
        } label: {
            HugeIcon("sidebar.left", size: IconSize.sm)
                .foregroundStyle(onPanel ? (hovering ? Theme.sideInk : Theme.sideTertiary) : (hovering ? Theme.ink : Theme.tertiary))
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? (onPanel ? Theme.sideHover : .white) : .clear).shadow(color: .black.opacity(hovering ? 0.07 : 0), radius: 4, y: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .accessibilityLabel(model.sidebarShown ? L.Folders.hideSidebar : L.Folders.showSidebar)
    }
}
