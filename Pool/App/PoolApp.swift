import AppKit
import SwiftUI

@main
struct PoolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window("Cyte", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1320, height: 860)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .commands { PoolCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image("MenuBarMark")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}

struct PoolCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L.Menu.newNote) { model.composingNote = true }
                .keyboardShortcut("n")
            Button(L.Voice.speakNote) { model.voiceNoteShown = true }
                .keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(L.Menu.saveClipboard) { model.ingestor.pasteFromClipboard() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
        }
        CommandGroup(after: .textEditing) {
            Button(L.Palette.title) { model.paletteShown = true }
                .keyboardShortcut("k")
            Button("Find") { model.paletteShown = true }
                .keyboardShortcut("f")
        }
        CommandGroup(after: .toolbar) {
            Button(model.sidebarShown ? L.Folders.hideSidebar : L.Folders.showSidebar) { model.sidebarShown.toggle() }
                .keyboardShortcut("s", modifiers: [.command, .control])
            Button(L.Folders.new) { model.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Larger tiles") { model.columnWidth = min(420, model.columnWidth + 40) }
                .keyboardShortcut("+")
            Button("Smaller tiles") { model.columnWidth = max(150, model.columnWidth - 40) }
                .keyboardShortcut("-")
            Divider()
        }
        CommandGroup(replacing: .help) {
            Button(L.Menu.replayOnboarding) { OnboardingController.shared.present(model: model) }
        }
    }
}

struct MenuBarContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var soundOn = SoundEngine.shared.enabled

    var body: some View {
        Button(L.Menu.saveClipboard) { model.ingestor.pasteFromClipboard() }
        Button(L.Menu.newNote) {
            openMain()
            model.composingNote = true
        }
        Divider()
        Button(L.Menu.open) { openMain() }
        Button(L.Menu.copyBookmarklet) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(AppModel.bookmarklet, forType: .string)
            model.feedback.toast(L.Toast.copied)
        }
        Toggle(L.Menu.sound, isOn: $soundOn)
            .onChange(of: soundOn) { _, value in SoundEngine.shared.enabled = value }
        Divider()
        Button(L.Menu.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Identity.isTesting else { return }
        let model = AppModel.shared
        Task { await model.start() }
        if !OnboardingController.completed {
            DispatchQueue.main.async {
                OnboardingController.shared.present(model: model)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { AppModel.shared.handle(url: $0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }
}
