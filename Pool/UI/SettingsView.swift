import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var sounds = SoundEngine.shared.enabled
    @State private var screenshots = ScreenshotWatcher.enabled
    @State private var autoUpdates = Updater.shared.checksAutomatically
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
                        HStack(spacing: 6) {
                            storagePill(L.Settings.iCloudDrive, backend: .iCloud, enabled: LibraryLocation.iCloudDefault != nil) {
                                guard let target = LibraryLocation.iCloudDefault else { return }
                                switchTo(target)
                            }
                            storagePill(L.Settings.googleDrive, backend: .googleDrive, enabled: true) {
                                if let target = LibraryLocation.googleDriveDefault {
                                    switchTo(target)
                                } else {
                                    chooseLibrary()
                                }
                            }
                            storagePill(L.Settings.localFolder, backend: .local, enabled: true) {
                                switchTo(LibraryLocation.homeDefault)
                            }
                            if activeBackend == .custom {
                                storagePill(L.Settings.customFolder, backend: .custom, enabled: true) {
                                    chooseLibrary()
                                }
                            }
                        }
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
                    if Updater.shared.isAvailable {
                        Divider().padding(.leading, 16)
                        row(L.Settings.updates, L.Settings.updatesBody, isOn: $autoUpdates) { Updater.shared.checksAutomatically = $0 }
                    }
                }

                if model.enricher.modelState != .ready {
                    group(L.Settings.intelligence) { intelligence }
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

                if !Diagnostics.shared.reports.isEmpty {
                    group(L.Settings.reports) { reportsRow }
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

    private var reportsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L.Settings.reportsTitle(Diagnostics.shared.reports.count))
                    .font(Theme.ui(13.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(L.Settings.reportsBody)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 2) {
                if Diagnostics.supportEmail.isEmpty {
                    Button(L.Settings.reportsShow) { Diagnostics.shared.reveal() }.poolSecondary(.first)
                } else {
                    Button(L.Settings.reportsSend) { Diagnostics.shared.send() }.poolSecondary(.first)
                }
                Button(L.Settings.reportsDelete) { Diagnostics.shared.clear() }.poolSecondary(.last)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder private var intelligence: some View {
        let state = model.enricher.modelState
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state == .off ? L.Settings.aiOffTitle : state == .downloading ? L.Settings.aiDownloadingTitle : L.Settings.aiUnsupportedTitle)
                    .font(Theme.ui(13.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(state == .off ? L.Settings.aiOffBody : state == .downloading ? L.Settings.aiDownloadingBody : L.Settings.aiUnsupportedBody)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state == .off {
                Button(L.Settings.aiOffAction) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") { NSWorkspace.shared.open(url) }
                }
                .poolSecondary(.alone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
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

    private var activeBackend: LibraryBackend {
        LibraryLocation.backend(for: URL(filePath: libraryPath, directoryHint: .isDirectory))
    }

    private func switchTo(_ target: URL) {
        let resolved = LibraryLocation.resolveRoot(for: target)
        let current = LibraryLocation.current
        guard resolved.standardizedFileURL != current.standardizedFileURL else { return }
        let count = model.store.saves.count
        if count > 0 {
            let from = LibraryLocation.placeName(for: current)
            let to = LibraryLocation.placeName(for: resolved)
            let alert = NSAlert()
            alert.messageText = L.Settings.moveTitle(to)
            var body = L.Settings.moveBody(count, from: from, to: to)
            if LibraryLocation.backend(for: current) == .iCloud { body += " " + L.Settings.moveLeavesICloud }
            alert.informativeText = body
            alert.addButton(withTitle: L.Settings.moveConfirm(count))
            alert.addButton(withTitle: L.Settings.cancel)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        libraryPath = resolved.path(percentEncoded: false)
        Task { await model.reopenLibrary(at: resolved, moving: true) }
    }

    private func chooseLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L.Settings.change
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switchTo(url)
    }

    private func storagePill(_ title: String, backend: LibraryBackend, enabled: Bool, action: @escaping () -> Void) -> some View {
        let selected = activeBackend == backend
        return Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Icon("checkmark", size: IconSize.xs)
                }
                Text(title)
                    .font(Theme.ui(12, weight: selected ? .medium : .regular))
            }
            .foregroundStyle(selected ? .white : Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(selected ? Theme.ink : .white))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
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
