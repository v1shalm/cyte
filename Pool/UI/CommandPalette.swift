import AppKit
import SwiftUI

struct PaletteItem: Identifiable {
    enum Kind { case save(Save), folder(Folder), action }
    let id: String
    let kind: Kind
    let title: String
    let detail: String?
    let symbol: String
    let run: () -> Void
}

struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    static let maxHeight: CGFloat = 524

    var floating = false
    let close: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @State private var voice = VoiceInput()
    @FocusState private var focused: Bool

    var body: some View {
        let sections = makeSections()
        let items = sections.flatMap(\.items)
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Icon("magnifyingglass", size: IconSize.md)
                    .foregroundStyle(Theme.tertiary)
                TextField(L.Palette.placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(20))
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .onSubmit { run(items) }
                MicButton(listening: voice.isListening, level: voice.level) { toggleVoice() }
                    .scaleEffect(1.25)
            }
            .padding(.horizontal, 22)
            .frame(height: 64)

            if !items.isEmpty {
                Rectangle().fill(Theme.hairline).frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sections, id: \.title) { section in
                                Text(section.title)
                                    .font(Theme.ui(11, weight: .medium))
                                    .foregroundStyle(Theme.tertiary)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)
                                ForEach(section.items) { item in
                                    let index = items.firstIndex { $0.id == item.id } ?? 0
                                    PaletteRow(item: item, selected: index == selection)
                                        .id(item.id)
                                        .onTapGesture {
                                            selection = index
                                            run(items)
                                        }
                                        .onHover { inside in if inside { selection = index } }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 420)
                    .scrollIndicators(.never)
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                            .frame(height: 28)
                            .allowsHitTesting(false)
                    }
                    .onChange(of: selection) { _, value in
                        guard items.indices.contains(value) else { return }
                        proxy.scrollTo(items[value].id)
                    }
                }
            }

            HStack(spacing: 18) {
                hint("↵", L.Palette.open)
                hint("↑↓", L.Palette.move)
                if !query.isEmpty { hint("⌘↵", L.Palette.showInGrid) }
                Spacer()
                hint("esc", L.Palette.close)
            }
            .padding(.horizontal, 22)
            .frame(height: 38)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
        .frame(width: 640)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
        .borderBeam(strength: 0.45 + voice.level * 0.55, active: voice.isListening, cornerRadius: 22, duration: 1.8)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 40, y: 20)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in selection = 0 }
        .onChange(of: voice.transcript) { _, text in if voice.isListening { query = text } }
        .onKeyPress(.downArrow) {
            selection = min(selection + 1, max(items.count - 1, 0))
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0)
            return .handled
        }
        .onKeyPress(.escape) {
            if voice.isListening { voice.cancel() } else { close() }
            return .handled
        }
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers.contains(.command), !query.isEmpty else { return .ignored }
            showInGrid()
            return .handled
        }
        .onDisappear { voice.cancel() }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(Theme.ui(11, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.chip))
                .lifted(RoundedRectangle(cornerRadius: 5, style: .continuous), shadow: 0)
            Text(label)
                .font(Theme.ui(11.5))
                .foregroundStyle(Theme.tertiary)
        }
    }

    private struct Section { let title: String; let items: [PaletteItem] }

    private func makeSections() -> [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var sections: [Section] = []
        let saves = trimmed.isEmpty ? Array(model.store.saves.prefix(6)) : Array(model.searchSaves(trimmed).prefix(8))
        if !saves.isEmpty {
            sections.append(Section(title: trimmed.isEmpty ? L.Palette.recent : L.Palette.saves, items: saves.map { save in
                PaletteItem(id: "s-\(save.id)", kind: .save(save), title: save.displayTitle,
                            detail: save.host ?? save.tags.prefix(3).joined(separator: " · "),
                            symbol: save.kind == .link ? "link" : (save.kind == .note ? "text.alignleft" : "photo")) {
                    open(save)
                }
            }))
        }
        let folders = model.store.folders.filter { trimmed.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmed) }
        if !folders.isEmpty {
            sections.append(Section(title: L.Folders.title, items: folders.prefix(5).map { folder in
                PaletteItem(id: "f-\(folder.id)", kind: .folder(folder), title: folder.name,
                            detail: L.Sidebar.count(model.store.count(in: folder)), symbol: "folder") {
                    model.folderID = folder.id
                    reveal()
                }
            }))
        }
        var actions: [PaletteItem] = []
        if let url = Ingestor.webURL(in: trimmed) {
            actions.append(PaletteItem(id: "a-link", kind: .action, title: L.Palette.saveLink, detail: url.host(), symbol: "plus") {
                model.ingestor.ingest(link: url, source: "palette")
                close()
            })
        } else if !trimmed.isEmpty {
            actions.append(PaletteItem(id: "a-note", kind: .action, title: L.Palette.noteFrom(trimmed), detail: nil, symbol: "square.and.pencil") {
                model.ingestor.addNote(trimmed)
                close()
            })
            actions.append(PaletteItem(id: "a-grid", kind: .action, title: L.Palette.showInGrid, detail: "⌘↵", symbol: "square.grid.2x2") {
                showInGrid()
            })
        }
        actions.append(PaletteItem(id: "a-voice", kind: .action, title: L.Voice.speakNote, detail: nil, symbol: "mic") {
            model.voiceNoteShown = true
            reveal()
        })
        actions.append(PaletteItem(id: "a-paste", kind: .action, title: L.Add.paste, detail: nil, symbol: "doc.on.clipboard") {
            model.ingestor.pasteFromClipboard()
            close()
        })
        actions.append(PaletteItem(id: "a-x", kind: .action, title: L.X.importAction, detail: model.xImport.connected ? nil : L.X.connect, symbol: "bookmark") {
            close()
            if floating { model.showMainWindow() }
            model.xImport.open()
        })
        actions.append(PaletteItem(id: "a-folder", kind: .action, title: L.Folders.new, detail: nil, symbol: "folder.badge.plus") {
            model.newFolder()
            reveal()
        })
        sections.append(Section(title: L.Palette.actions, items: actions))
        return sections
    }

    private func run(_ items: [PaletteItem]) {
        guard items.indices.contains(selection) else { return }
        if voice.isListening { voice.stop() }
        items[selection].run()
    }

    private func open(_ save: Save) {
        model.selectedID = save.id
        reveal()
    }

    private func showInGrid() {
        model.query = query
        reveal()
    }

    private func reveal() {
        close()
        if floating { model.showMainWindow() }
    }

    private func toggleVoice() {
        if voice.isListening {
            voice.stop()
        } else {
            Task { await voice.start(stopAfterSilence: true) }
        }
    }
}

private struct PaletteRow: View {
    @Environment(AppModel.self) private var model
    let item: PaletteItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.ui(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if selected {
                Icon("return", size: IconSize.xs)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Theme.rowSelection : .clear)
                .lifted(RoundedRectangle(cornerRadius: 14, style: .continuous), active: selected, shadow: 0.06)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder private var leading: some View {
        if case .save(let save) = item.kind, let thumb = model.store.url(for: save, file: save.thumbnail) {
            Thumb(url: thumb, maxPixel: 120)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairline))
        } else {
            Icon(item.symbol, size: IconSize.md)
                .foregroundStyle(Theme.secondary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
                .lifted(RoundedRectangle(cornerRadius: 6, style: .continuous), shadow: 0)
        }
    }
}


final class FloatingPalette {
    static let shared = FloatingPalette()
    private var panel: PalettePanel?

    func toggle(model: AppModel) {
        if let panel, panel.isVisible { hide(); return }
        let panel = self.panel ?? make(model: model)
        self.panel = panel
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let size = NSSize(width: 760, height: 600)
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height - screen.frame.height * 0.16,
                              width: size.width, height: size.height), display: true)
        panel.contentView = NSHostingView(rootView: PaletteHost { [weak self] in self?.hide() }.environment(model))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    private func make(model: AppModel) -> PalettePanel {
        let panel = PalettePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onResign = { [weak self] in self?.hide() }
        return panel
    }
}

final class PalettePanel: NSPanel {
    var onResign: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func resignKey() {
        super.resignKey()
        onResign?()
    }
}

private struct PaletteHost: View {
    let close: () -> Void

    var body: some View {
        VStack {
            CommandPalette(floating: true, close: close)
                .padding(40)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.light)
    }
}
