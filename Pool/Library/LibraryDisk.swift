import Foundation
import OSLog

nonisolated enum LibraryDisk {
    static let log = Logger(subsystem: Identity.subsystem, category: "disk")

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static let trashDays = 30

    @concurrent
    static func write(_ save: Save, paths: LibraryPaths) async throws {
        let folder = paths.folder(for: save)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try encoder.encode(save)
        try data.write(to: folder.appending(path: "save.json", directoryHint: .notDirectory), options: .atomic)
    }

    @concurrent
    static func trash(_ save: Save, paths: LibraryPaths) async throws -> URL {
        let folder = paths.folder(for: save)
        let target = paths.trash.appending(path: save.id, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: folder, to: target)
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: target.path(percentEncoded: false))
        return target
    }

    @concurrent
    static func restore(_ save: Save, from trashed: URL, paths: LibraryPaths) async throws {
        let folder = paths.folder(for: save)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: trashed, to: folder)
    }

    @concurrent
    static func loadFolders(paths: LibraryPaths) async -> [Folder] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: paths.folders, includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        let decoder = makeDecoder()
        var byID: [String: (folder: Folder, canonical: Bool, url: URL)] = [:]
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url), let folder = try? decoder.decode(Folder.self, from: data) else { continue }
            let canonical = url.deletingPathExtension().lastPathComponent == folder.id
            if let existing = byID[folder.id] {
                let keep = canonical && !existing.canonical
                try? fm.removeItem(at: keep ? existing.url : url)
                if !keep { continue }
            }
            byID[folder.id] = (folder, canonical, url)
        }
        for (id, item) in byID where !item.canonical {
            let target = paths.folders.appending(path: "\(id).json")
            if (try? fm.moveItem(at: item.url, to: target)) == nil { continue }
        }
        return byID.values.map(\.folder).sorted { $0.position < $1.position }
    }

    @concurrent
    static func purgeTrash(paths: LibraryPaths, now: Date = Date(), days: Int = trashDays) async -> Int {
        let fm = FileManager.default
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let items = (try? fm.contentsOfDirectory(at: paths.trash, includingPropertiesForKeys: [.contentModificationDateKey],
                                                 options: [.skipsHiddenFiles])) ?? []
        var removed = 0
        for item in items {
            guard let date = try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  date < cutoff else { continue }
            if (try? fm.removeItem(at: item)) != nil { removed += 1 }
        }
        return removed
    }

    @concurrent
    static func write(_ folder: Folder, paths: LibraryPaths) async throws {
        try FileManager.default.createDirectory(at: paths.folders, withIntermediateDirectories: true)
        let data = try encoder.encode(folder)
        try data.write(to: paths.folders.appending(path: "\(folder.id).json"), options: .atomic)
    }

    @concurrent
    static func remove(_ folder: Folder, paths: LibraryPaths) async {
        try? FileManager.default.removeItem(at: paths.folders.appending(path: "\(folder.id).json"))
    }

    @concurrent
    static func migrate(from source: LibraryPaths, to destination: LibraryPaths) async -> Int {
        let fm = FileManager.default
        let srcRoot = source.root.standardizedFileURL
        let dstRoot = destination.root.standardizedFileURL
        guard srcRoot != dstRoot, fm.fileExists(atPath: srcRoot.path(percentEncoded: false)) else { return 0 }

        do {
            try destination.ensureExists()
        } catch {
            log.error("Failed to create destination library at \(dstRoot.path(percentEncoded: false), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return 0
        }

        var movedSaves = 0

        if let months = try? fm.contentsOfDirectory(at: source.saves, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for month in months {
                let dstMonth = destination.saves.appending(path: month.lastPathComponent, directoryHint: .isDirectory)
                try? fm.createDirectory(at: dstMonth, withIntermediateDirectories: true)
                let items = (try? fm.contentsOfDirectory(at: month, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                for item in items {
                    let target = dstMonth.appending(path: item.lastPathComponent, directoryHint: .isDirectory)
                    if fm.fileExists(atPath: target.path(percentEncoded: false)) {
                        continue
                    } else if (try? fm.moveItem(at: item, to: target)) != nil {
                        movedSaves += 1
                    } else if (try? fm.copyItem(at: item, to: target)) != nil {
                        try? fm.removeItem(at: item)
                        movedSaves += 1
                    }
                }
                if ((try? fm.contentsOfDirectory(atPath: month.path(percentEncoded: false))) ?? []).isEmpty {
                    try? fm.removeItem(at: month)
                }
            }
        }

        for (srcDir, dstDir) in [(source.folders, destination.folders), (source.inbox, destination.inbox), (source.trash, destination.trash)] {
            guard let items = try? fm.contentsOfDirectory(at: srcDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items {
                let target = dstDir.appending(path: item.lastPathComponent)
                if fm.fileExists(atPath: target.path(percentEncoded: false)) {
                    continue
                } else if (try? fm.moveItem(at: item, to: target)) == nil {
                    if (try? fm.copyItem(at: item, to: target)) != nil {
                        try? fm.removeItem(at: item)
                    }
                }
            }
        }

        for dir in [source.saves, source.folders, source.trash] {
            let remaining = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            if remaining.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }

        return movedSaves
    }
}
