import CryptoKit
import Foundation
import OSLog

nonisolated struct IndexEntry: Codable, Sendable, Equatable {
    var stamp: Double
    var save: Save
}

nonisolated struct ScanResult: Sendable {
    var saves: [Save]
    var entries: [String: IndexEntry]
    var decoded = 0
    var conflictsResolved = 0
    var duplicatesSetAside = 0
    var downloadsRequested = 0
}

nonisolated enum LibraryScan {
    static let log = Logger(subsystem: Identity.subsystem, category: "scan")
    static let mediaToFetch: Set<String> = ["mp4", "mov", "m4v", "gif"]

    private struct Folder: Sendable {
        let key: String
        let url: URL
        var jsons: [URL] = []
        var stamp: Double = 0
        var fetch: [URL] = []
    }

    private struct Decoded: Sendable {
        let key: String
        let url: URL
        let save: Save
        let stamp: Double
        let resolved: Bool
    }

    static func isSaveFile(_ name: String) -> Bool {
        guard name.hasPrefix("save"), name.hasSuffix(".json") else { return false }
        let middle = name.dropFirst(4).dropLast(5)
        if middle.isEmpty { return true }
        guard middle.first == " " else { return false }
        return middle.dropFirst().allSatisfy(\.isNumber) && middle.count > 1
    }

    @concurrent
    static func run(paths: LibraryPaths, previous: [String: IndexEntry], only: Set<String>? = nil) async -> ScanResult {
        let folders = collect(paths, only: only)
        var entries: [String: IndexEntry] = only == nil ? [:] : previous.filter { !only!.contains($0.key) }
        var pending: [Folder] = []
        var result = ScanResult(saves: [], entries: [:])

        for folder in folders {
            for url in folder.fetch {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                result.downloadsRequested += 1
            }
            guard !folder.jsons.isEmpty else { continue }
            if folder.jsons.count == 1, folder.jsons[0].lastPathComponent == "save.json",
               let cached = previous[folder.key], cached.stamp == folder.stamp {
                entries[folder.key] = cached
            } else {
                pending.append(folder)
            }
        }

        let decoded = await decode(pending)
        result.decoded = decoded.count
        for item in decoded {
            entries[item.key] = IndexEntry(stamp: item.stamp, save: item.save)
            if item.resolved { result.conflictsResolved += 1 }
        }

        let urls = Dictionary(uniqueKeysWithValues: folders.map { ($0.key, $0.url) })
        var winners: [String: String] = [:]
        for (key, entry) in entries {
            guard entries[key] != nil else { continue }
            guard let current = winners[entry.save.id], let other = entries[current] else {
                winners[entry.save.id] = key
                continue
            }
            let keep = prefer(key, entry, over: current, other) ? key : current
            let drop = keep == key ? current : key
            winners[entry.save.id] = keep
            if let folder = urls[drop], setAside(folder, id: entry.save.id, paths: paths) {
                result.duplicatesSetAside += 1
            }
            entries[drop] = nil
        }

        result.entries = entries
        result.saves = entries.values.map(\.save).sorted { $0.createdAt > $1.createdAt }
        if result.conflictsResolved + result.duplicatesSetAside > 0 {
            log.notice("Resolved \(result.conflictsResolved) conflicting save files and set aside \(result.duplicatesSetAside) duplicate saves")
        }
        return result
    }

    private static func prefer(_ key: String, _ entry: IndexEntry, over otherKey: String, _ other: IndexEntry) -> Bool {
        let named = key.hasSuffix("/" + entry.save.id)
        let otherNamed = otherKey.hasSuffix("/" + other.save.id)
        if named != otherNamed { return named }
        if entry.save.updatedAt != other.save.updatedAt { return entry.save.updatedAt > other.save.updatedAt }
        return key < otherKey
    }

    static func folderKeys(for changed: [String], in paths: LibraryPaths) -> Set<String>? {
        let base = paths.saves.standardizedFileURL.path(percentEncoded: false)
        var keys: Set<String> = []
        for path in changed {
            let standard = URL(filePath: path).standardizedFileURL.path(percentEncoded: false)
            guard standard.hasPrefix(base) else { continue }
            let parts = standard.dropFirst(base.count).split(separator: "/")
            guard parts.count >= 2 else { return nil }
            keys.insert(parts[0] + "/" + parts[1])
        }
        return keys
    }

    private static func collect(_ paths: LibraryPaths, only: Set<String>? = nil) -> [Folder] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .ubiquitousItemDownloadingStatusKey, .isDirectoryKey]
        let candidates: [(month: URL, item: URL)]
        if let only {
            candidates = only.compactMap { key in
                let parts = key.split(separator: "/")
                guard parts.count == 2 else { return nil }
                let month = paths.saves.appending(path: String(parts[0]), directoryHint: .isDirectory)
                return (month, month.appending(path: String(parts[1]), directoryHint: .isDirectory))
            }
        } else {
            let months = (try? fm.contentsOfDirectory(at: paths.saves, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            candidates = months.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.flatMap { month in
                ((try? fm.contentsOfDirectory(at: month, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []).map { (month, $0) }
            }
        }
        var folders: [Folder] = []
        folders.reserveCapacity(candidates.count)
        for (month, item) in candidates where (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            var folder = Folder(key: month.lastPathComponent + "/" + item.lastPathComponent, url: item)
            let files = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: keys, options: [])) ?? []
            for file in files {
                let name = file.lastPathComponent
                if name.hasPrefix(".") {
                    if name.hasSuffix(".icloud") {
                        let real = String(name.dropFirst().dropLast(7))
                        if isSaveFile(real) || real == "thumb.jpg" || mediaToFetch.contains((real as NSString).pathExtension.lowercased()) {
                            folder.fetch.append(item.appending(path: real))
                        }
                    }
                    continue
                }
                let values = try? file.resourceValues(forKeys: Set(keys))
                if isSaveFile(name) {
                    folder.jsons.append(file)
                    if name == "save.json" { folder.stamp = values?.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0 }
                } else if let status = values?.ubiquitousItemDownloadingStatus, status != .current,
                          name == "thumb.jpg" || mediaToFetch.contains(file.pathExtension.lowercased()) {
                    folder.fetch.append(file)
                }
            }
            folder.jsons.sort { $0.lastPathComponent.count < $1.lastPathComponent.count }
            folders.append(folder)
        }
        return folders
    }

    private static func decode(_ folders: [Folder]) async -> [Decoded] {
        guard !folders.isEmpty else { return [] }
        let lanes = min(8, folders.count)
        return await withTaskGroup(of: [Decoded].self) { group in
            for lane in 0..<lanes {
                let slice = stride(from: lane, to: folders.count, by: lanes).map { folders[$0] }
                group.addTask {
                    let decoder = LibraryDisk.makeDecoder()
                    return slice.compactMap { read($0, decoder: decoder) }
                }
            }
            var all: [Decoded] = []
            for await part in group { all += part }
            return all
        }
    }

    private static func read(_ folder: Folder, decoder: JSONDecoder) -> Decoded? {
        var versions: [(url: URL, data: Data, save: Save)] = []
        for url in folder.jsons {
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                versions.append((url, data, try decoder.decode(Save.self, from: data)))
            } catch {
                log.error("Skipped unreadable save at \(url.path(percentEncoded: false), privacy: .public)")
            }
        }
        guard let winner = versions.max(by: { $0.save.updatedAt < $1.save.updatedAt }) else { return nil }
        let main = folder.url.appending(path: "save.json")
        var resolved = false
        var stamp = folder.stamp
        if folder.jsons.count > 1 || winner.url != main {
            do {
                if winner.url != main { try winner.data.write(to: main, options: .atomic) }
                for version in versions where version.url != main { try? FileManager.default.removeItem(at: version.url) }
                var fresh = main
                fresh.removeAllCachedResourceValues()
                stamp = (try? fresh.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSinceReferenceDate) ?? 0
                resolved = true
            } catch {
                log.error("Could not resolve conflicting saves in \(folder.key, privacy: .public)")
                stamp = 0
            }
        }
        return Decoded(key: folder.key, url: folder.url, save: winner.save, stamp: stamp, resolved: resolved)
    }

    private static func setAside(_ folder: URL, id: String, paths: LibraryPaths) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: paths.trash, withIntermediateDirectories: true)
        var target = paths.trash.appending(path: "\(id)-duplicate", directoryHint: .isDirectory)
        var n = 2
        while fm.fileExists(atPath: target.path(percentEncoded: false)) {
            target = paths.trash.appending(path: "\(id)-duplicate-\(n)", directoryHint: .isDirectory)
            n += 1
        }
        do {
            try fm.moveItem(at: folder, to: target)
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: target.path(percentEncoded: false))
            return true
        } catch {
            log.error("Could not set aside duplicate save \(id, privacy: .public)")
            return false
        }
    }
}

nonisolated struct LibraryIndex: Sendable {
    let directory: URL

    static let shared = LibraryIndex(directory: URL.applicationSupportDirectory.appending(path: "Cyte/Index", directoryHint: .isDirectory))
    static let version = 1

    private struct Snapshot: Codable {
        var version: Int
        var root: String
        var entries: [String: IndexEntry]
    }

    func file(for root: URL) -> URL {
        let path = root.standardizedFileURL.path(percentEncoded: false)
        let digest = SHA256.hash(data: Data(path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(digest).plist")
    }

    @concurrent
    func read(root: URL) async -> [String: IndexEntry]? {
        guard let data = try? Data(contentsOf: file(for: root)),
              let snapshot = try? PropertyListDecoder().decode(Snapshot.self, from: data),
              snapshot.version == Self.version,
              snapshot.root == root.standardizedFileURL.path(percentEncoded: false) else { return nil }
        return snapshot.entries
    }

    @concurrent
    func write(root: URL, entries: [String: IndexEntry]) async {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let snapshot = Snapshot(version: Self.version, root: root.standardizedFileURL.path(percentEncoded: false), entries: entries)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoder.encode(snapshot).write(to: file(for: root), options: .atomic)
        } catch {
            LibraryScan.log.error("Could not write the library index: \(error.localizedDescription, privacy: .public)")
        }
    }
}
