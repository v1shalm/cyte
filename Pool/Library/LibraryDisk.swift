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

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @concurrent
    static func loadAll(paths: LibraryPaths) async -> [Save] {
        let fm = FileManager.default
        guard let months = try? fm.contentsOfDirectory(at: paths.saves, includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles]) else { return [] }
        var result: [Save] = []
        result.reserveCapacity(1024)
        let decoder = decoder
        for month in months {
            guard let folders = try? fm.contentsOfDirectory(at: month, includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles]) else { continue }
            for folder in folders {
                let file = folder.appending(path: "save.json", directoryHint: .notDirectory)
                guard let data = try? Data(contentsOf: file) else { continue }
                do {
                    result.append(try decoder.decode(Save.self, from: data))
                } catch {
                    log.error("Skipped unreadable save at \(file.path(percentEncoded: false), privacy: .public)")
                }
            }
        }
        result.sort { $0.createdAt > $1.createdAt }
        return result
    }

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
        let files = (try? FileManager.default.contentsOfDirectory(at: paths.folders, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])) ?? []
        let decoder = decoder
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Folder.self, from: Data(contentsOf: $0)) }
            .sorted { $0.position < $1.position }
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
