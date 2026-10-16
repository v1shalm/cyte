import Foundation
import OSLog

nonisolated enum LibraryDisk {
    static let log = Logger(subsystem: "in.tistmedia.pool", category: "disk")

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
}
