import AppKit
import SwiftUI

struct PaletteItem: Identifiable {
    enum Kind { case save(Save), folder(Folder), action }
    let id: String
    let kind: Kind
    let title: String
    let detail: String?
    let symbol: String
    var why: String? = nil
    let run: () -> Void
}

@Observable
final class PaletteState {
    struct Section { let title: String; let items: [PaletteItem] }

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            selection = 0
            related = []
        }
    }
    var selection = 0
    var related: [Save] = []
    let voice = VoiceInput()

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let floating: Bool
    @ObservationIgnored private let close: () -> Void

    init(model: AppModel, floating: Bool, close: @escaping () -> Void) {
        self.model = model
        self.floating = floating
        self.close = close
    }

    var sections: [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var sections: [Section] = []
        let saves = trimmed.isEmpty ? Array(model.store.saves.prefix(6)) : Array(model.searchSaves(trimmed).prefix(8))
        if !saves.isEmpty {
            sections.append(Section(title: trimmed.isEmpty ? L.Palette.recent : L.Palette.saves, items: saves.map(item)))
        }
        let shown = Set(saves.map(\.id))
        let meaning = trimmed.isEmpty ? [] : related.filter { !shown.contains($0.id) }
        if !meaning.isEmpty {
            sections.append(Section(title: L.Search.related, items: meaning.map(item)))
        }
        let folders = model.store.folders.filter { trimmed.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmed) }
        if !folders.isEmpty {
            sections.append(Section(title: L.Folders.title, items: folders.prefix(5).map { folder in
                PaletteItem(id: "f-\(folder.id)", kind: .folder(folder), title: folder.name,
                            detail: L.Sidebar.count(model.store.count(in: folder)), symbol: "folder") { [self] in
                    model.folderID = folder.id
                    reveal()
                }
            }))
        }
        var actions: [PaletteItem] = []
        if let url = Ingestor.webURL(in: trimmed) {
            actions.append(PaletteItem(id: "a-link", kind: .action, title: L.Palette.saveLink, detail: url.host(), symbol: "plus") { [self] in
                model.ingestor.ingest(link: url, source: "palette")
                close()
            })
        } else if !trimmed.isEmpty {
            actions.append(PaletteItem(id: "a-note", kind: .action, title: L.Palette.noteFrom(trimmed), detail: nil, symbol: "square.and.pencil") { [self] in
                model.ingestor.addNote(trimmed)
                close()
            })
            actions.append(PaletteItem(id: "a-grid", kind: .action, title: L.Palette.showInGrid, detail: "⌘↵", symbol: "square.grid.2x2") { [self] in
                showInGrid()
            })
        }
        actions.append(PaletteItem(id: "a-voice", kind: .action, title: L.Voice.speakNote, detail: nil, symbol: "mic") { [self] in
            model.voiceNoteShown = true
            reveal()
        })
        actions.append(PaletteItem(id: "a-paste", kind: .action, title: L.Add.paste, detail: nil, symbol: "doc.on.clipboard") { [self] in
            model.ingestor.pasteFromClipboard()
            close()
        })
        actions.append(PaletteItem(id: "a-folder", kind: .action, title: L.Folders.new, detail: nil, symbol: "folder.badge.plus") { [self] in
            model.newFolder()
            reveal()
        })
        sections.append(Section(title: L.Palette.actions, items: actions))
        return sections
    }

    var items: [PaletteItem] { sections.flatMap(\.items) }

    func move(_ delta: Int) {
        selection = min(max(selection + delta, 0), max(items.count - 1, 0))
    }

    func run() {
        let items = items
        guard items.indices.contains(selection) else { return }
        if voice.isListening { voice.stop() }
        items[selection].run()
    }

    func showInGrid() {
        model.query = query
        reveal()
    }

    func escape() {
        if voice.isListening { voice.cancel() } else { close() }
    }

    func toggleVoice() {
        if voice.isListening {
            voice.stop()
        } else {
            Task { await voice.start(stopAfterSilence: true) }
        }
    }

    func loadRelated() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        let found = Array(await model.relatedSaves(trimmed).prefix(5))
        guard !Task.isCancelled, !found.isEmpty else { return }
        let before = items
        let kept = before.indices.contains(selection) ? before[selection].id : nil
        related = found
        if let kept, let index = items.firstIndex(where: { $0.id == kept }) {
            selection = index
        }
    }

    private func item(_ save: Save) -> PaletteItem {
        let why = save.note.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
        return PaletteItem(id: "s-\(save.id)", kind: .save(save), title: save.displayTitle,
                           detail: save.host ?? save.tags.prefix(3).joined(separator: " · "),
                           symbol: save.kind == .link ? "link" : (save.kind == .note ? "text.alignleft" : "photo"),
                           why: why?.isEmpty == false ? why : nil) { [self] in
            model.selectedID = save.id
            reveal()
        }
    }

    private func reveal() {
        close()
        if floating { model.showMainWindow() }
    }
}

struct CommandPalette: View {
    @State private var state: PaletteState
    @FocusState private var focused: Bool

    init(floating: Bool = false, close: @escaping () -> Void) {
        _state = State(initialValue: PaletteState(model: AppModel.shared, floating: floating, close: close))
    }

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Icon("magnifyingglass", size: IconSize.md)
                    .foregroundStyle(Theme.secondary)
                TextField(L.Palette.placeholder, text: $state.query)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(20))
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .onSubmit { state.run() }
                MicButton(listening: state.voice.isListening, level: state.voice.level) { state.toggleVoice() }
                    .scaleEffect(1.25)
            }
            .padding(.horizontal, 22)
            .frame(height: 64)

            Rectangle().fill(Theme.hairline).frame(height: 1)
            PaletteList(state: state)
            PaletteHints(searching: !state.query.isEmpty)
        }
        .frame(width: 640)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
        .borderBeam(strength: 0.45 + state.voice.level * 0.55, active: state.voice.isListening, cornerRadius: Radius.sheet, duration: 1.8)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.11), radius: 28, y: 12)
        .onAppear { focused = true }
        .paletteKeys(state)
        .onDisappear { state.voice.cancel() }
    }
}

struct PaletteList: View {
    let state: PaletteState
    var maxHeight: CGFloat = 420
    @State private var origin = NSEvent.mouseLocation
    @State private var armed = false

    var body: some View {
        let sections = state.sections
        let items = sections.flatMap(\.items)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.title) { section in
                        SectionLabel(section.title)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        ForEach(section.items) { item in
                            let index = items.firstIndex { $0.id == item.id } ?? 0
                            PaletteRow(item: item, selected: index == state.selection)
                                .id(item.id)
                                .onTapGesture {
                                    state.selection = index
                                    state.run()
                                }
                                .onHover { inside in
                                    guard inside, pointerMoved() else { return }
                                    state.selection = index
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .scrollIndicators(.never)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                    .allowsHitTesting(false)
            }
            .onChange(of: state.selection) { _, value in
                guard items.indices.contains(value) else { return }
                proxy.scrollTo(items[value].id)
            }
        }
        .task(id: state.query) { await state.loadRelated() }
    }

    private func pointerMoved() -> Bool {
        guard !armed else { return true }
        let now = NSEvent.mouseLocation
        armed = hypot(now.x - origin.x, now.y - origin.y) > 3
        return armed
    }
}

struct PaletteHints: View {
    let searching: Bool

    var body: some View {
        HStack(spacing: 18) {
            hint("↵", L.Palette.open)
            hint("↑↓", L.Palette.move)
            if searching { hint("⌘↵", L.Palette.showInGrid) }
            Spacer()
            hint("esc", L.Palette.close)
        }
        .padding(.horizontal, 22)
        .frame(height: 38)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(Theme.ui(11, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.softFill))
            Text(label)
                .font(Theme.ui(TextSize.caption))
                .foregroundStyle(Theme.tertiary)
        }
    }
}

extension View {
    func paletteKeys(_ state: PaletteState) -> some View {
        self
            .onChange(of: state.voice.transcript) { _, text in if state.voice.isListening { state.query = text } }
            .onKeyPress(.downArrow) {
                state.move(1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                state.move(-1)
                return .handled
            }
            .onKeyPress(.escape) {
                state.escape()
                return .handled
            }
            .onKeyPress(.return, phases: .down) { press in
                guard press.modifiers.contains(.command), !state.query.isEmpty else { return .ignored }
                state.showInGrid()
                return .handled
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
                if let why = item.why {
                    Text(why)
                        .font(Theme.serif(TextSize.body))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                } else if let detail = item.detail, !detail.isEmpty {
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
                .fill(selected ? Theme.softFill : .clear)
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
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.softFill))
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
