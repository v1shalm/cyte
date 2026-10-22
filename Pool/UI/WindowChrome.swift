import AppKit
import SwiftUI

enum Chrome {
    static let barHeight: CGFloat = 52
    static let lightsLeading: CGFloat = 22
    static let lightsSpacing: CGFloat = 20
    static let fade: CGFloat = 16
    static let headerBottom: CGFloat = barHeight + Control.regular
    static let panelTop: CGFloat = headerBottom + 8
    static let hintHeight: CGFloat = 22
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
