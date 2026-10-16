import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var sounds = SoundEngine.shared.enabled
    @State private var screenshots = ScreenshotWatcher.enabled
    @State private var libraryPath = LibraryLocation.current.path(percentEncoded: false)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(L.Settings.title)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)

                group(L.Settings.library) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.Settings.libraryBody)
                            .font(Theme.ui(12.5))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(tildePath)
                            .font(Theme.ui(12.5, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white))
                        HStack(spacing: 2) {
                            Button(L.Settings.change, action: chooseLibrary).poolSecondary(.first)
                            Button(L.Settings.show) { NSWorkspace.shared.activateFileViewerSelecting([LibraryLocation.current]) }.poolSecondary(.last)
                        }
                    }
                    .padding(16)
                }

                group(L.Settings.general) {
                    row(L.Settings.login, L.Settings.loginBody, isOn: $launchAtLogin) { on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                    Divider().padding(.leading, 16)
                    row(L.Settings.sounds, L.Settings.soundsBody, isOn: $sounds) { SoundEngine.shared.enabled = $0 }
                    Divider().padding(.leading, 16)
                    row(L.Settings.screenshots, L.Settings.screenshotsBody, isOn: $screenshots) { on in
                        if on { model.startScreenshots() } else { ScreenshotWatcher.enabled = false }
                    }
                }

                group(L.Settings.x) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.xImport.connected ? L.Settings.xConnected : L.Settings.xOff)
                                .font(Theme.ui(13.5, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            if model.xImport.importedCount > 0 {
                                Text(L.Viewing.saves(model.xImport.importedCount))
                                    .font(Theme.ui(12)).foregroundStyle(Theme.tertiary)
                            }
                        }
                        if model.xImport.connected {
                            HStack(spacing: 2) {
                                Button(L.X.syncNow) { model.xImport.open() }.poolSecondary(.first)
                                Button(L.X.disconnect) { model.xImport.disconnect() }.poolSecondary(.last)
                            }
                        } else {
                            Button(L.X.connect) { model.xImport.open() }.poolPrimary()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }

                group(L.Settings.shortcuts) {
                    ForEach(Array(Self.shortcuts.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider().padding(.leading, 16) }
                        HStack {
                            Text(item.0).font(Theme.ui(13.5)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(item.1)
                                .font(Theme.ui(12, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                    }
                }

                Text("Cyte \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(32)
        }
        .scrollIndicators(.never)
        .frame(width: 560, height: 680)
        .background(Color.white)
        .preferredColorScheme(.light)
    }

    private static let shortcuts: [(String, String)] = [
        ("Save from browser", "⌥⌘P"),
        ("Open search anywhere", "⌃⌥Space"),
        ("Search", "⌘K"),
        ("Select all", "⌘A"),
        ("Tag the focused save", "T"),
        ("Add to folder", "F"),
        ("Select the focused save", "X"),
        ("Open the focused save", "Space"),
    ]

    private var tildePath: String {
        libraryPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func chooseLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L.Settings.change
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let root = url.lastPathComponent == "Pool" ? url : url.appending(path: "Pool", directoryHint: .isDirectory)
        libraryPath = root.path(percentEncoded: false)
        Task { await model.reopenLibrary(at: root) }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.ui(11, weight: .medium))
                .foregroundStyle(Theme.tertiary)
                .padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.softFill))
        }
    }

    private func row(_ title: String, _ detail: String, isOn: Binding<Bool>, change: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.ui(13.5, weight: .medium)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.ui(12)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            SoftToggle(isOn: isOn)
                .onChange(of: isOn.wrappedValue) { _, value in change(value) }
        }
        .padding(16)
    }
}

struct SoftToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { withAnimation(.spring(duration: 0.28, bounce: 0.2)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.ink : Color.black.opacity(0.14)).frame(width: 42, height: 26)
                Circle().fill(.white).frame(width: 20, height: 20).padding(3)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
