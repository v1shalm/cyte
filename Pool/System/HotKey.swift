import AppKit
import Carbon.HIToolbox

final class HotKey {
    private static var nextID: UInt32 = 1
    private var reference: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void
    let id: UInt32

    init(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action
        self.id = Self.nextID
        Self.nextID += 1
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            let matched = MainActor.assumeIsolated { () -> Bool in
                guard pressed.id == hotKey.id else { return false }
                hotKey.action()
                return true
            }
            return matched ? noErr : OSStatus(eventNotHandledErr)
        }, 1, &spec, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x504F_4F4C), id: id)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &reference)
    }

    isolated deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

enum BrowserTab {
    private static let scripts: [String: String] = [
        "com.apple.Safari": "tell application \"Safari\" to return URL of front document",
        "com.google.Chrome": "tell application \"Google Chrome\" to return URL of active tab of front window",
        "company.thebrowser.Browser": "tell application \"Arc\" to return URL of active tab of front window",
        "company.thebrowser.dia": "tell application \"Dia\" to return URL of active tab of front window",
        "com.brave.Browser": "tell application \"Brave Browser\" to return URL of active tab of front window",
        "com.microsoft.edgemac": "tell application \"Microsoft Edge\" to return URL of active tab of front window",
    ]

    static func frontURL() -> URL? {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let source = scripts[bundleID] else { return nil }
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil, let string = result?.stringValue else { return nil }
        return Ingestor.webURL(in: string)
    }
}
