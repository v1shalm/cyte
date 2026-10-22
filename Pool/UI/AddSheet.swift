import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddSheet: View {
    @Environment(AppModel.self) private var model

    enum Stage: Equatable { case entry, saving, saved(String) }

    static let width: CGFloat = 440
    private static let inner: CGFloat = Radius.panel - 8

    @State private var stage: Stage = .entry
    @State private var text = ""
    @State private var invalid = false
    @State private var why = ""
    @State private var folderID: String?
    @State private var finished = false
    @State private var voice = VoiceInput()
    @FocusState private var linkFocused: Bool
    @FocusState private var whyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch stage {
            case .entry, .saving:
                entry
            case .saved(let id):
                saved(id)
            }
        }
        .padding(8)
        .frame(width: Self.width)
        .floatingPanel(radius: Radius.panel)
        .animation(Theme.settle, value: stage)
        .onDisappear(perform: finish)
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Icon("link", size: IconSize.md)
                    .foregroundStyle(Theme.secondary)
                TextField(L.Add.linkPlaceholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(TextSize.large))
                    .foregroundStyle(Theme.ink)
                    .focused($linkFocused)
                    .onSubmit(saveLink)
                    .disabled(stage == .saving)
                if stage == .saving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: Control.small, height: Control.small)
                        .help(L.Add.saving)
                } else {
                    Button(action: saveLink) {
                        Icon("return", size: IconSize.xs)
                            .foregroundStyle(link == nil ? Theme.secondary : .white)
                            .frame(width: Control.small, height: Control.small)
                            .background(Circle().fill(link == nil ? Theme.softFill : Theme.ink))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(L.Add.link)
                    .animation(Theme.hover, value: link == nil)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: Control.large)
            .background(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).strokeBorder(linkFocused ? Theme.ink.opacity(0.18) : Theme.hairline))
            if invalid {
                Text(L.Add.linkInvalid)
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
            Spacer().frame(height: 6)
            AddRow(symbol: "photo.on.rectangle", title: L.Add.images) {
                close()
                chooseFiles()
            }
            AddRow(symbol: "text.alignleft", title: L.Add.note) {
                close()
                model.composingNote = true
            }
            AddRow(symbol: "mic", title: L.Voice.speakNote) {
                close()
                model.voiceNoteShown = true
            }
            AddRow(symbol: "doc.on.clipboard", title: L.Add.paste) {
                close()
                model.ingestor.pasteFromClipboard()
            }
            Text(L.Add.hint)
                .font(Theme.ui(TextSize.small))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .onAppear {
            if let clip = NSPasteboard.general.string(forType: .string), Self.parse(clip) != nil { text = clip }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            linkFocused = true
        }
        .onChange(of: text) { _, _ in invalid = false }
    }

    private func saved(_ id: String) -> some View {
        let save = model.store.save(id: id)
        let folders = model.store.folders.filter { $0.rule == nil }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SavePreview(save: save)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
                VStack(alignment: .leading, spacing: 3) {
                    Text(save?.displayTitle ?? "")
                        .font(Theme.serif(TextSize.large + 3))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    if let host = save?.host {
                        Text(host)
                            .font(Theme.ui(TextSize.small))
                            .foregroundStyle(Theme.tertiary)
                            .lineLimit(1)
                    }
                }
                .shimmer(save?.pending == true)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Icon("checkmark", size: IconSize.xs)
                    Text(L.Toast.saved)
                }
                .font(Theme.ui(TextSize.small, weight: .medium))
                .foregroundStyle(Theme.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).fill(Theme.softHover))

            HStack(spacing: 8) {
                TextField("", text: $why, prompt: Text(L.Why.question(1)).foregroundStyle(Theme.tertiary))
                    .textFieldStyle(.plain)
                    .font(Theme.ui(TextSize.large))
                    .foregroundStyle(Theme.ink)
                    .focused($whyFocused)
                    .onSubmit(done)
                    .accessibilityLabel(L.Why.question(1))
                Button(action: toggleVoice) {
                    HStack(spacing: 6) {
                        Icon(voice.isListening ? "waveform" : "mic", size: IconSize.sm)
                            .opacity(voice.isListening ? 0.55 + voice.level * 0.45 : 1)
                        Text(voice.isListening ? L.Why.stopListening : L.Why.speak)
                    }
                    .font(Theme.ui(TextSize.small, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: Control.small)
                    .background(Capsule().fill(Theme.softFill))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: Control.large)
            .background(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).strokeBorder(whyFocused ? Theme.ink.opacity(0.18) : Theme.hairline))
            .padding(.top, 8)

            if !folders.isEmpty {
                Text(L.Add.folder)
                    .font(Theme.ui(TextSize.small, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(folders) { folder in
                        FolderChip(name: folder.name, selected: folderID == folder.id) {
                            folderID = folderID == folder.id ? nil : folder.id
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack {
                Spacer()
                Button(primaryTitle, action: done)
                    .poolPrimary()
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.top, 14)
        }
        .onChange(of: voice.transcript) { _, said in if voice.isListening { why = said } }
    }

    private var link: URL? { Self.parse(text) }

    private var primaryTitle: String {
        folderID.flatMap { model.store.folder(id: $0) }.map { L.Add.into($0.name) } ?? L.Add.done
    }

    private func saveLink() {
        guard let url = link else {
            withAnimation(Theme.fade) { invalid = true }
            return
        }
        stage = .saving
        Task {
            guard let save = await model.ingestor.save(link: url, source: "add") else {
                close()
                return
            }
            folderID = model.store.save(id: save.id)?.folders.first { model.store.folder(id: $0)?.rule == nil }
            stage = .saved(save.id)
            try? await Task.sleep(for: .milliseconds(60))
            whyFocused = true
        }
    }

    private func toggleVoice() {
        if voice.isListening {
            let said = voice.stop()
            if !said.isEmpty { why = said }
            return
        }
        Task {
            await voice.start(stopAfterSilence: true) {
                let said = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !said.isEmpty { why = said }
            }
        }
    }

    private func done() {
        finish()
        close()
    }

    private func close() {
        model.addMenuOpen = false
    }

    private func finish() {
        guard !finished, case .saved(let id) = stage else { return }
        finished = true
        if voice.isListening {
            let said = voice.stop()
            if !said.isEmpty { why = said }
        }
        let reason = why.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reason.isEmpty {
            model.store.modify(id) { save in
                save.note = save.note.isEmpty ? reason : save.note + "\n" + reason
            }
            SoundEngine.shared.play(.chime, volume: 0.45)
        }
        let current = model.store.save(id: id)?.folders ?? []
        for existing in current where existing != folderID {
            if let folder = model.store.folder(id: existing), folder.rule == nil { model.store.remove(id, from: folder) }
        }
        if let folderID, !current.contains(folderID), let folder = model.store.folder(id: folderID) {
            model.store.add([id], to: folder)
            model.feedback.toast(L.Folders.added(folder.name))
        }
        model.refresh()
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .movie, .video, .gif]
        guard panel.runModal() == .OK else { return }
        model.ingestor.ingest(fileURLs: panel.urls)
    }

    static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = Ingestor.webURL(in: trimmed) { return url }
        guard !trimmed.contains("://"), trimmed.contains("."), !trimmed.hasPrefix(".") else { return nil }
        return Ingestor.webURL(in: "https://" + trimmed)
    }
}

private struct AddRow: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(symbol, size: IconSize.md)
                    .foregroundStyle(Theme.secondary)
                Text(title)
                    .font(Theme.ui(TextSize.large))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: Control.large)
            .background(RoundedRectangle(cornerRadius: Radius.panel - 8, style: .continuous).fill(hovering ? Theme.softHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .accessibilityLabel(title)
    }
}

private struct FolderChip: View {
    let name: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon("folder", size: IconSize.xs, fill: selected ? 1 : 0)
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(Theme.ui(TextSize.small, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .frame(maxWidth: 200)
            .frame(height: Control.small)
            .background {
                if selected {
                    Capsule()
                        .fill(Theme.tabPill)
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                        .shadow(color: .black.opacity(Theme.tabPillShadow), radius: 3, y: 1)
                } else {
                    Capsule().fill(hovering ? Theme.softFillStrong : Theme.softFill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(Theme.press, value: selected)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SavePreview: View {
    @Environment(AppModel.self) private var model
    let save: Save?

    var body: some View {
        if let save, let thumb = model.store.url(for: save, file: save.thumbnail) {
            Thumb(url: thumb, maxPixel: 128, tint: save.tint)
        } else {
            ZStack {
                Theme.surface
                if let save, let favicon = model.store.url(for: save, file: save.favicon) {
                    Favicon(url: favicon)
                } else {
                    Icon("link", size: IconSize.md).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}
