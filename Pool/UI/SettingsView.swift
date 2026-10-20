import AppKit
import ServiceManagement
import SwiftUI

enum SettingsTab: Hashable {
    case general, library, shortcuts
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: SettingsTab = .general
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var sounds = SoundEngine.shared.enabled
    @State private var screenshots = ScreenshotWatcher.enabled
    @State private var autoUpdates = Updater.shared.checksAutomatically
    @State private var libraryPath = LibraryLocation.current.path(percentEncoded: false)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                Text(L.Settings.title)
                    .font(Theme.serif(TitleSize.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                GooeyTabs(items: [
                    (L.Settings.general, SettingsTab.general),
                    (L.Settings.library, SettingsTab.library),
                    (L.Settings.shortcuts, SettingsTab.shortcuts),
                ], selection: $tab)
                .fixedSize()
            }
            .frame(height: Control.regular)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch tab {
                    case .general: general
                    case .library: library
                    case .shortcuts: shortcuts
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.softHover)
        }
        .frame(width: 600, height: 520)
        .background(Theme.surface.ignoresSafeArea())
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .preferredColorScheme(.light)
    }

    @ViewBuilder private var general: some View {
        group {
            row(L.Settings.login, L.Settings.loginBody) {
                SoftToggle(isOn: $launchAtLogin)
                    .accessibilityLabel(L.Settings.login)
                    .onChange(of: launchAtLogin) { _, on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            separator
            row(L.Settings.sounds, L.Settings.soundsBody) {
                SoftToggle(isOn: $sounds)
                    .accessibilityLabel(L.Settings.sounds)
                    .onChange(of: sounds) { _, on in SoundEngine.shared.enabled = on }
            }
            separator
            row(L.Settings.screenshots, L.Settings.screenshotsBody) {
                SoftToggle(isOn: $screenshots)
                    .accessibilityLabel(L.Settings.screenshots)
                    .onChange(of: screenshots) { _, on in
                        if on { model.startScreenshots() } else { ScreenshotWatcher.enabled = false }
                    }
            }
            if Updater.shared.isAvailable {
                separator
                row(L.Settings.updates, L.Settings.updatesBody) {
                    SoftToggle(isOn: $autoUpdates)
                        .accessibilityLabel(L.Settings.updates)
                        .onChange(of: autoUpdates) { _, on in Updater.shared.checksAutomatically = on }
                }
            }
        }

        if model.enricher.modelState != .ready {
            group(L.Settings.intelligence) { intelligence }
        }

        if !Diagnostics.shared.reports.isEmpty {
            group(L.Settings.reports) { reportsRow }
        }

        Text(L.Settings.version(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
            .font(Theme.ui(TextSize.small))
            .foregroundStyle(Theme.secondary)
            .padding(.leading, 4)
    }

    @ViewBuilder private var library: some View {
        group(footer: L.Settings.libraryBody) {
            row(L.Settings.storage, nil) {
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
            }
            separator
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.Settings.folder)
                        .font(Theme.ui(TextSize.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(tildePath)
                        .font(Theme.ui(TextSize.small))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(tildePath)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            actionBar {
                Button(L.Settings.show) { NSWorkspace.shared.activateFileViewerSelecting([LibraryLocation.current]) }.poolSecondary(.first)
                Button(L.Settings.change, action: chooseLibrary).poolSecondary(.last)
            }
        }
    }

    @ViewBuilder private var shortcuts: some View {
        group {
            ForEach(Array(Self.shortcuts.enumerated()), id: \.offset) { index, item in
                if index > 0 { separator }
                HStack {
                    Text(item.0).font(Theme.ui(TextSize.body)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(item.1)
                        .font(Theme.ui(TextSize.small, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.softFill))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var separator: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, 16)
    }

    private func actionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Theme.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    @ViewBuilder private var reportsRow: some View {
        row(L.Settings.reportsTitle(Diagnostics.shared.reports.count), L.Settings.reportsBody) { EmptyView() }
        actionBar {
            Button(L.Settings.reportsDelete) { Diagnostics.shared.clear() }.poolSecondary(.first)
            if Diagnostics.supportEmail.isEmpty {
                Button(L.Settings.reportsShow) { Diagnostics.shared.reveal() }.poolSecondary(.last)
            } else {
                Button(L.Settings.reportsSend) { Diagnostics.shared.send() }.poolPrimary(.last)
            }
        }
    }

    @ViewBuilder private var intelligence: some View {
        let state = model.enricher.modelState
        row(state == .off ? L.Settings.aiOffTitle : state == .downloading ? L.Settings.aiDownloadingTitle : L.Settings.aiUnsupportedTitle,
            state == .off ? L.Settings.aiOffBody : state == .downloading ? L.Settings.aiDownloadingBody : L.Settings.aiUnsupportedBody) { EmptyView() }
        if state == .off {
            actionBar {
                Button(L.Settings.aiOffAction) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") { NSWorkspace.shared.open(url) }
                }
                .poolSecondary()
            }
        }
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
            }
        }
        .buttonStyle(ChipStyle(active: selected))
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func group<Content: View>(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                    Text(title)
                    .font(Theme.ui(TextSize.caption, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0, content: content)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
            if let footer {
                Text(footer)
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func row<Trailing: View>(_ title: String, _ detail: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.ui(TextSize.body, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(Theme.ui(TextSize.small))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
    }
}

struct SoftToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { withAnimation(.spring(duration: 0.28, bounce: 0.2)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.ink : Theme.softTarget).frame(width: 42, height: 26)
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
