import AppKit
import Carbon.HIToolbox
import Foundation
import Observation

enum SortOrder: String, CaseIterable { case newest, oldest, shuffle }

@Observable
final class AppModel {
    static let shared = AppModel()

    let store: LibraryStore
    let enricher: Enricher
    let feedback: Feedback
    let ingestor: Ingestor
    let xImport: XImporter

    var query = "" { didSet { if query != oldValue { refresh() } } }
    var kind: SaveKind? { didSet { if kind != oldValue { refresh() } } }
    var folderID: String? {
        didSet {
            guard folderID != oldValue else { return }
            if folderID != nil, bookmarksOnly { bookmarksOnly = false }
            refresh()
        }
    }
    var activeTags: Set<String> = [] {
        didSet { if activeTags != oldValue { refresh() } }
    }
    var tagIndex: (mine: [(tag: String, count: Int)], found: [(tag: String, count: Int)]) {
        var mine: [String: Int] = [:]
        var found: [String: Int] = [:]
        for save in store.saves {
            for tag in save.tags { mine[tag.lowercased(), default: 0] += 1 }
            for label in save.labels where !save.tags.contains(label) { found[label.lowercased(), default: 0] += 1 }
        }
        let order: ((tag: String, count: Int), (tag: String, count: Int)) -> Bool = { $0.count != $1.count ? $0.count > $1.count : $0.tag < $1.tag }
        return (
            mine.map { (tag: $0.key, count: $0.value) }.sorted(by: order),
            found.map { (tag: $0.key, count: $0.value) }.sorted(by: order).prefix(14).map { $0 }
        )
    }
    func toggleTag(_ tag: String) {
        if activeTags.contains(tag) { activeTags.remove(tag) } else { activeTags.insert(tag) }
    }
    func tag(_ ids: [String], with tag: String, on: Bool) {
        let clean = tag.lowercased().trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !clean.isEmpty else { return }
        for id in ids {
            store.modify(id) { save in
                if on { if !save.tags.contains(clean) { save.tags.append(clean) } } else { save.tags.removeAll { $0 == clean } }
            }
        }
        refresh()
    }
    private(set) var tagRow: [(tag: String, count: Int)] = []
    var bookmarksOnly = false {
        didSet {
            guard bookmarksOnly != oldValue else { return }
            if bookmarksOnly, folderID != nil { folderID = nil }
            refresh()
        }
    }
    var editingFolderID: String?
    var sidebarShown: Bool = UserDefaults.standard.object(forKey: "pool.sidebar") as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarShown, forKey: "pool.sidebar") }
    }
    static let sidebarWidth: CGFloat = 244
    static let saveType = "in.tistmedia.pool.save"
    private(set) var results: [Save] = []
    private(set) var related: [Save] = []

    var selectedID: String?
    var genie: GenieRequest?
    @ObservationIgnored var tileFrames: () -> [String: CGRect] = { [:] }
    @ObservationIgnored var hoveredID: String?
    var composingNote = false
    var paletteShown = false
    var addMenuOpen = false
    var linkEntryShown = false
    var addingFocus: Bool { addMenuOpen || linkEntryShown }
    var voiceNoteShown = false
    let voiceSearch = VoiceInput()
    var sort: SortOrder = .newest { didSet { if sort != oldValue { if sort == .shuffle { shuffleSeed = .random(in: 1...999_999) }; refresh() } } }
    @ObservationIgnored private var shuffleSeed = 1
    var addShown = false
    var dropTargeted = false

    var columnWidth: Double = UserDefaults.standard.object(forKey: "pool.columnWidth") as? Double ?? 248 {
        didSet { UserDefaults.standard.set(columnWidth, forKey: "pool.columnWidth") }
    }

    @ObservationIgnored private let search = SearchEngine()
    @ObservationIgnored private var screenshots: ScreenshotWatcher?
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var paletteKey: HotKey?
    @ObservationIgnored private var started = false

    private init() {
        let store = LibraryStore()
        let feedback = Feedback()
        let enricher = Enricher(store: store)
        self.store = store
        self.feedback = feedback
        self.enricher = enricher
        self.ingestor = Ingestor(store: store, enricher: enricher, feedback: feedback)
        self.xImport = XImporter(store: store, ingestor: ingestor)
    }

    func start() async {
        guard !started else { return }
        started = true
        store.onInboxChange = { [weak self] in self?.ingestor.processInbox() }
        await store.open()
        refresh()
        enricher.enrichMissing()
        ingestor.processInbox()
        if ScreenshotWatcher.enabled { startScreenshots() }
        hotKey = HotKey(keyCode: kVK_ANSI_P, modifiers: optionKey | cmdKey) { [weak self] in
            self?.quickSave()
        }
        paletteKey = HotKey(keyCode: kVK_Space, modifiers: optionKey | controlKey) { [weak self] in
            guard let self else { return }
            FloatingPalette.shared.toggle(model: self)
        }
    }

    func reopenLibrary(at root: URL) async {
        LibraryLocation.current = root
        await store.open(root: root)
        refresh()
        enricher.enrichMissing()
    }

    func refresh() {
        if let folderID, store.folder(id: folderID) == nil { self.folderID = nil }
        var base = folderID.map { id in store.saves.filter { $0.folders.contains(id) } } ?? store.saves
        if bookmarksOnly {
            base = base.filter { $0.source == "x" }
        } else if folderID == nil {
            base = base.filter { $0.source != "x" }
        }
        if !activeTags.isEmpty {
            base = base.filter { save in
                let own = Set((save.tags + save.labels).map { $0.lowercased() })
                return activeTags.allSatisfy { own.contains($0) }
            }
        }
        let index = tagIndex
        var row = Array(index.mine.prefix(10)) + Array(index.found.prefix(8))
        for tag in activeTags where !row.contains(where: { $0.tag == tag }) { row.insert((tag: tag, count: 0), at: 0) }
        tagRow = row
        let result = search.run(query, kind: kind, in: base)
        results = ordered(result.matches)
        related = result.related
    }

    private func ordered(_ saves: [Save]) -> [Save] {
        switch sort {
        case .newest: return saves
        case .oldest: return saves.reversed()
        case .shuffle:
            let seed = shuffleSeed
            return saves.sorted { lhs, rhs in
                var a = Hasher(); a.combine(lhs.id); a.combine(seed)
                var b = Hasher(); b.combine(rhs.id); b.combine(seed)
                return a.finalize() < b.finalize()
            }
        }
    }

    func searchSaves(_ query: String) -> [Save] {
        let result = search.run(query, kind: nil, in: store.saves)
        return result.matches + result.related
    }

    func saveID(forFile url: URL) -> String? {
        let savesPath = store.paths.saves.standardizedFileURL.path(percentEncoded: false)
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard path.hasPrefix(savesPath) else { return nil }
        let id = url.deletingLastPathComponent().lastPathComponent
        return store.save(id: id) == nil ? nil : id
    }

    func showMainWindow() {
        NSApp.activate()
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func toggleVoiceSearch() {
        if voiceSearch.isListening {
            voiceSearch.stop()
            return
        }
        Task {
            await voiceSearch.start(stopAfterSilence: true)
        }
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var orderedIDs: [String] { results.map(\.id) + related.map(\.id) }

    func select(offset: Int) {
        let ids = orderedIDs
        guard let current = selectedID, let index = ids.firstIndex(of: current) else { return }
        let next = index + offset
        guard ids.indices.contains(next) else { return }
        selectedID = ids[next]
    }

    func delete(_ save: Save) {
        if selectedID == save.id { selectedID = nil }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let frame = tileFrames()[save.id]
        if let frame, !reduceMotion { genie = GenieRequest(save: save, frame: frame) }
        Task {
            guard let trashed = await store.delete(save) else { return }
            SoundEngine.shared.play(.delete)
            refresh()
            if frame != nil, !reduceMotion { try? await Task.sleep(for: .milliseconds(520)) }
            feedback.toast(L.Toast.deleted, actionTitle: L.Toast.undo) {
                Task {
                    await self.store.restore(trashed)
                    self.refresh()
                    self.feedback.dismissToast()
                }
            }
        }
    }

    func newFolder(adding ids: [String] = []) {
        let folder = store.createFolder(named: L.Folders.untitled)
        if !ids.isEmpty { store.add(ids, to: folder) }
        sidebarShown = true
        editingFolderID = folder.id
    }

    func file(_ ids: [String], into folder: Folder) {
        store.add(ids, to: folder)
        SoundEngine.shared.play(.drop, volume: 0.7)
        feedback.toast(L.Folders.added(folder.name))
        refresh()
    }

    var contentLeading: CGFloat { sidebarShown ? Self.sidebarWidth + 10 : 0 }

    func startScreenshots() {
        ScreenshotWatcher.enabled = true
        if screenshots == nil {
            screenshots = ScreenshotWatcher { [weak self] url in
                guard let self else { return }
                self.ingestor.ingest(fileURLs: [url], source: "screenshot", quiet: true)
                self.feedback.saved(message: L.Toast.screenshot)
            }
        }
        screenshots?.start()
    }

    func quickSave() {
        if let url = BrowserTab.frontURL() {
            ingestor.ingest(link: url, source: "browser")
        } else {
            ingestor.pasteFromClipboard()
        }
    }

    func handle(url: URL) {
        guard url.scheme == "pool", let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = components.queryItems ?? []
        if let raw = items.first(where: { $0.name == "url" })?.value, let link = Ingestor.webURL(in: raw) {
            ingestor.ingest(link: link, title: items.first(where: { $0.name == "title" })?.value, source: "browser")
        } else if let text = items.first(where: { $0.name == "text" })?.value {
            ingestor.addNote(text)
        }
    }

    static let bookmarklet = "javascript:location.href='pool://save?url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)"
}
