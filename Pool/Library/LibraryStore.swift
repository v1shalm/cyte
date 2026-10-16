import Foundation
import Observation
import OSLog

@Observable
final class LibraryStore {
    private(set) var saves: [Save] = []
    private(set) var folders: [Folder] = []
    private(set) var isLoaded = false
    private(set) var paths: LibraryPaths

    private(set) var freshIDs: Set<String> = []

    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var recentWrites: [String: Date] = [:]
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var entries: [String: IndexEntry] = [:]
    @ObservationIgnored private var pendingKeys: Set<String>? = []
    @ObservationIgnored private var pendingFolders = false
    @ObservationIgnored private let index: LibraryIndex
    @ObservationIgnored var onInboxChange: (() -> Void)?

    private let log = Logger(subsystem: Identity.subsystem, category: "library")

    init(root: URL = LibraryLocation.current, index: LibraryIndex = .shared) {
        paths = LibraryPaths(root: root)
        self.index = index
    }

    func open(root: URL? = nil) async {
        if let root { paths = LibraryPaths(root: root) }
        pendingKeys = []
        pendingFolders = false
        do { try paths.ensureExists() } catch {
            log.error("Could not create library folders: \(error.localizedDescription, privacy: .public)")
        }
        let paths = paths
        entries = [:]
        if let cached = await index.read(root: paths.root) {
            entries = cached
            saves = cached.values.map(\.save).sorted { $0.createdAt > $1.createdAt }
            isLoaded = true
        }
        folders = await LibraryDisk.loadFolders(paths: paths)
        await rescan(markFresh: !entries.isEmpty)
        isLoaded = true
        startWatching()
        Task { _ = await LibraryDisk.purgeTrash(paths: paths) }
    }

    private func rescan(markFresh: Bool = true, only: Set<String>? = nil) async {
        let paths = paths
        let before = entries.count
        let result = await LibraryScan.run(paths: paths, previous: entries, only: only)
        guard paths.root == self.paths.root else { return }
        entries = result.entries
        merge(result.saves, markFresh: markFresh)
        if result.decoded > 0 || result.duplicatesSetAside > 0 || result.entries.count != before {
            await index.write(root: paths.root, entries: result.entries)
        }
    }

    @discardableResult
    func moveAndOpen(to newRoot: URL) async -> Int {
        let oldPaths = paths
        let targetPaths = LibraryPaths(root: newRoot)
        guard oldPaths.root.standardizedFileURL != targetPaths.root.standardizedFileURL else {
            await open(root: newRoot)
            return 0
        }
        watcher?.stop()
        watcher = nil
        reloadTask?.cancel()
        let moved = await LibraryDisk.migrate(from: oldPaths, to: targetPaths)
        await open(root: newRoot)
        return moved
    }


    func save(id: String) -> Save? { saves.first { $0.id == id } }

    func url(for save: Save, file: String?) -> URL? { paths.file(file, of: save) }

    func folder(for save: Save) -> URL { paths.folder(for: save) }


    func clearFresh(_ id: String) { freshIDs.remove(id) }

    func insert(_ save: Save, fresh: Bool = true) {
        saves.insert(save, at: 0)
        if fresh { freshIDs.insert(save.id) }
        persist(save)
    }

    func update(_ save: Save) {
        var save = save
        save.updatedAt = Date()
        if let index = saves.firstIndex(where: { $0.id == save.id }) {
            saves[index] = save
        }
        persist(save)
    }

    func modify(_ id: String, _ change: (inout Save) -> Void) {
        guard var save = save(id: id) else { return }
        change(&save)
        update(save)
    }

    struct Trashed { let save: Save; let location: URL; let index: Int }

    func delete(_ save: Save) async -> Trashed? {
        guard let index = saves.firstIndex(where: { $0.id == save.id }) else { return nil }
        saves.remove(at: index)
        markWritten(save.id)
        do {
            let location = try await LibraryDisk.trash(save, paths: paths)
            return Trashed(save: save, location: location, index: index)
        } catch {
            log.error("Trash failed: \(error.localizedDescription, privacy: .public)")
            saves.insert(save, at: min(index, saves.count))
            return nil
        }
    }

    func restore(_ trashed: Trashed) async {
        markWritten(trashed.save.id)
        do {
            try await LibraryDisk.restore(trashed.save, from: trashed.location, paths: paths)
            saves.insert(trashed.save, at: min(trashed.index, saves.count))
        } catch {
            log.error("Restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func folder(id: String) -> Folder? { folders.first { $0.id == id } }

    func members(of folder: Folder) -> [Save] {
        if let rule = folder.rule { return saves.filter { $0.source != "x" && rule.matches($0) } }
        return saves.filter { $0.folders.contains(folder.id) }
    }

    func count(in folder: Folder) -> Int {
        if let rule = folder.rule { return saves.reduce(0) { $0 + ($1.source != "x" && rule.matches($1) ? 1 : 0) } }
        return saves.reduce(0) { $0 + ($1.folders.contains(folder.id) ? 1 : 0) }
    }

    @discardableResult
    func createFolder(named name: String, rule: SmartRule? = nil) -> Folder {
        var folder = Folder(name: name, position: (folders.map(\.position).max() ?? 0) + 1)
        folder.rule = rule
        folders.append(folder)
        persist(folder)
        return folder
    }

    func rename(_ folder: Folder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = trimmed
        persist(folders[index])
    }

    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        for save in saves where save.folders.contains(folder.id) {
            modify(save.id) { $0.folders.removeAll { $0 == folder.id } }
        }
        let paths = paths
        Task { await LibraryDisk.remove(folder, paths: paths) }
    }

    func add(_ ids: [String], to folder: Folder) {
        for id in ids {
            modify(id) { save in
                if !save.folders.contains(folder.id) { save.folders.append(folder.id) }
            }
        }
    }

    func remove(_ id: String, from folder: Folder) {
        modify(id) { $0.folders.removeAll { $0 == folder.id } }
    }

    private func persist(_ folder: Folder) {
        markWritten(folder.id)
        let paths = paths
        Task { try? await LibraryDisk.write(folder, paths: paths) }
    }

    private func persist(_ save: Save) {
        markWritten(save.id)
        let paths = paths
        Task {
            do { try await LibraryDisk.write(save, paths: paths) } catch {
                log.error("Write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func markWritten(_ id: String) { recentWrites[id] = Date() }


    private func startWatching() {
        watcher?.stop()
        watcher = FolderWatcher(url: paths.root) { [weak self] changed in
            self?.handle(changed: changed)
        }
    }

    private func handle(changed: [String]) {
        let inboxPath = paths.inbox.path(percentEncoded: false)
        if changed.contains(where: { $0.hasPrefix(inboxPath) }) { onInboxChange?() }

        let savesPath = paths.saves.path(percentEncoded: false)
        let now = Date()
        recentWrites = recentWrites.filter { now.timeIntervalSince($0.value) < 3 }
        let foldersPath = paths.folders.path(percentEncoded: false)
        let external = changed.contains { path in
            if path.hasPrefix(foldersPath) { return !recentWrites.keys.contains { path.contains($0) } }
            guard path.hasPrefix(savesPath) else { return false }
            return !recentWrites.keys.contains { path.contains("/\($0)") }
        }
        guard external else { return }
        let touched = LibraryScan.folderKeys(for: changed.filter { $0.hasPrefix(savesPath) }, in: paths)
        if let touched, let pending = pendingKeys { pendingKeys = pending.union(touched) } else { pendingKeys = nil }
        if changed.contains(where: { $0.hasPrefix(foldersPath) }) { pendingFolders = true }
        reloadTask?.cancel()
        reloadTask = Task { [paths] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if pendingFolders {
                pendingFolders = false
                self.folders = await LibraryDisk.loadFolders(paths: paths)
            }
            let only = pendingKeys
            pendingKeys = []
            if only?.isEmpty != true { await rescan(only: only) }
        }
    }

    private func merge(_ disk: [Save], markFresh: Bool = true) {
        let diskIDs = Set(disk.map(\.id))
        let known = Set(saves.map(\.id))
        let localOnly = saves.filter { !diskIDs.contains($0.id) && recentWrites[$0.id] != nil }
        if markFresh { freshIDs.formUnion(disk.lazy.map(\.id).filter { !known.contains($0) }) }
        let next = (disk + localOnly).sorted { $0.createdAt > $1.createdAt }
        if next != saves { saves = next }
    }
}
