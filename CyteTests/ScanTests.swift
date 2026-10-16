import Foundation
import Testing
@testable import Cyte

struct ScanTests {
    private let fm = FileManager.default

    private func library() throws -> LibraryPaths {
        let root = fm.temporaryDirectory.appending(path: "cyte-scan-\(UUID().uuidString)/Cyte", directoryHint: .isDirectory)
        let paths = LibraryPaths(root: root)
        try paths.ensureExists()
        return paths
    }

    private func save(_ title: String, updated: Date = Date()) -> Save {
        var save = Save(kind: .note, text: title)
        save.title = title
        save.updatedAt = updated
        return save
    }

    private func encode(_ save: Save) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(save)
    }

    @Test(arguments: [("save.json", true), ("save 2.json", true), ("save 12.json", true), ("saved.json", false), ("save .json", false), ("save 2a.json", false)])
    func `recognises save files and iCloud conflict copies`(name: String, expected: Bool) {
        #expect(LibraryScan.isSaveFile(name) == expected)
    }

    @Test func `reads every save in the library`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        for title in ["one", "two", "three"] { try await LibraryDisk.write(save(title), paths: paths) }
        let result = await LibraryScan.run(paths: paths, previous: [:])
        #expect(Set(result.saves.map(\.title)) == ["one", "two", "three"])
        #expect(result.decoded == 3)
    }

    @Test func `reuses the index for saves that did not change`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        try await LibraryDisk.write(save("on disk"), paths: paths)
        let first = await LibraryScan.run(paths: paths, previous: [:])
        var cached = first.entries
        let key = try #require(cached.keys.first)
        cached[key]?.save.title = "from index"

        let second = await LibraryScan.run(paths: paths, previous: cached)
        #expect(second.decoded == 0)
        #expect(second.saves.first?.title == "from index")
    }

    @Test func `re-reads a save whose file changed`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        var item = save("before")
        try await LibraryDisk.write(item, paths: paths)
        let first = await LibraryScan.run(paths: paths, previous: [:])
        item.title = "after"
        let file = paths.folder(for: item).appending(path: "save.json")
        try encode(item).write(to: file)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: file.path(percentEncoded: false))

        let second = await LibraryScan.run(paths: paths, previous: first.entries)
        #expect(second.decoded == 1)
        #expect(second.saves.first?.title == "after")
    }

    @Test func `keeps the newer copy when iCloud leaves a conflict file`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let old = save("older", updated: Date(timeIntervalSince1970: 1_000))
        var new = old
        new.title = "newer"
        new.updatedAt = Date(timeIntervalSince1970: 2_000)
        try await LibraryDisk.write(old, paths: paths)
        let folder = paths.folder(for: old)
        try encode(new).write(to: folder.appending(path: "save 2.json"))

        let result = await LibraryScan.run(paths: paths, previous: [:])

        #expect(result.saves.map(\.title) == ["newer"])
        #expect(result.conflictsResolved == 1)
        #expect(!fm.fileExists(atPath: folder.appending(path: "save 2.json").path(percentEncoded: false)))
        let main = try LibraryDisk.makeDecoder().decode(Save.self, from: Data(contentsOf: folder.appending(path: "save.json")))
        #expect(main.title == "newer")
    }

    @Test func `sets a duplicated save folder aside in the trash`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let item = save("original")
        try await LibraryDisk.write(item, paths: paths)
        let folder = paths.folder(for: item)
        let copy = folder.deletingLastPathComponent().appending(path: "\(item.id) 2", directoryHint: .isDirectory)
        try fm.copyItem(at: folder, to: copy)

        let result = await LibraryScan.run(paths: paths, previous: [:])

        #expect(result.saves.count == 1)
        #expect(result.duplicatesSetAside == 1)
        #expect(fm.fileExists(atPath: folder.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: copy.path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: paths.trash.appending(path: "\(item.id)-duplicate").path(percentEncoded: false)))
    }

    @Test func `skips a save file it cannot read`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        try await LibraryDisk.write(save("good"), paths: paths)
        let broken = paths.saves.appending(path: "2026-10/broken", directoryHint: .isDirectory)
        try fm.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: broken.appending(path: "save.json"))
        let result = await LibraryScan.run(paths: paths, previous: [:])
        #expect(result.saves.map(\.title) == ["good"])
        #expect(fm.fileExists(atPath: broken.appending(path: "save.json").path(percentEncoded: false)))
    }

    @Test func `empties trash items older than thirty days`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let old = paths.trash.appending(path: "old", directoryHint: .isDirectory)
        let recent = paths.trash.appending(path: "recent", directoryHint: .isDirectory)
        try fm.createDirectory(at: old, withIntermediateDirectories: true)
        try fm.createDirectory(at: recent, withIntermediateDirectories: true)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-31 * 86_400)], ofItemAtPath: old.path(percentEncoded: false))

        #expect(await LibraryDisk.purgeTrash(paths: paths) == 1)
        #expect(!fm.fileExists(atPath: old.path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: recent.path(percentEncoded: false)))
    }

    @Test func `merges duplicated folder files into one folder`() async throws {
        let paths = try library()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let folder = Folder(name: "Type", position: 1)
        try await LibraryDisk.write(folder, paths: paths)
        let canonical = paths.folders.appending(path: "\(folder.id).json")
        try fm.copyItem(at: canonical, to: paths.folders.appending(path: "\(folder.id) 2.json"))

        let folders = await LibraryDisk.loadFolders(paths: paths)
        #expect(folders.map(\.id) == [folder.id])
        let left = try fm.contentsOfDirectory(atPath: paths.folders.path(percentEncoded: false))
        #expect(left == ["\(folder.id).json"])
    }

    @Test func `the index round-trips and ignores another library`() async throws {
        let paths = try library()
        let index = LibraryIndex(directory: paths.root.deletingLastPathComponent().appending(path: "Index", directoryHint: .isDirectory))
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let entries = ["2026-10/a": IndexEntry(stamp: 42, save: save("cached"))]
        await index.write(root: paths.root, entries: entries)
        #expect(await index.read(root: paths.root) == entries)
        #expect(await index.read(root: paths.root.appending(path: "other")) == nil)
    }
}

struct ScanBenchmark {
    @Test(.timeLimit(.minutes(2)))
    func `ten thousand saves load fast from the index`() async throws {
        let fm = FileManager.default
        let paths = LibraryPaths(root: fm.temporaryDirectory.appending(path: "cyte-bench-\(UUID().uuidString)/Cyte", directoryHint: .isDirectory))
        try paths.ensureExists()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for n in 0..<10_000 {
            var item = Save(kind: .image, title: "Reference \(n)", aspect: 1.2)
            item.tags = ["poster", "type"]
            item.summary = String(repeating: "A poster with bold type. ", count: 4)
            let folder = paths.folder(for: item)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(item).write(to: folder.appending(path: "save.json"))
        }
        let clock = ContinuousClock()
        var cold = ScanResult(saves: [], entries: [:])
        let coldTime = await clock.measure { cold = await LibraryScan.run(paths: paths, previous: [:]) }
        var warm = ScanResult(saves: [], entries: [:])
        let warmTime = await clock.measure { warm = await LibraryScan.run(paths: paths, previous: cold.entries) }
        let index = LibraryIndex(directory: paths.root.deletingLastPathComponent().appending(path: "Index", directoryHint: .isDirectory))
        await index.write(root: paths.root, entries: cold.entries)
        var cached: [String: IndexEntry]?
        let indexTime = await clock.measure { cached = await index.read(root: paths.root) }
        print("bench: cold scan \(coldTime), warm scan \(warmTime), index read \(indexTime)")
        #expect(cold.saves.count == 10_000)
        #expect(warm.decoded == 0)
        #expect(cached?.count == 10_000)
        #expect(warmTime < coldTime)
    }
}

struct TargetedScanTests {
    @Test func `maps changed paths to save folders`() {
        let paths = LibraryPaths(root: URL(filePath: "/Users/me/Cyte", directoryHint: .isDirectory))
        let keys = LibraryScan.folderKeys(for: [
            "/Users/me/Cyte/Saves/2026-10/abc/save.json",
            "/Users/me/Cyte/Saves/2026-10/abc/thumb.jpg",
            "/Users/me/Cyte/Saves/2026-09/def",
            "/Users/me/Cyte/Inbox/new.png",
        ], in: paths)
        #expect(keys == ["2026-10/abc", "2026-09/def"])
        #expect(LibraryScan.folderKeys(for: ["/Users/me/Cyte/Saves/2026-10"], in: paths) == nil)
    }

    @Test func `a targeted scan rereads only the named folders`() async throws {
        let fm = FileManager.default
        let paths = LibraryPaths(root: fm.temporaryDirectory.appending(path: "cyte-target-\(UUID().uuidString)/Cyte", directoryHint: .isDirectory))
        try paths.ensureExists()
        defer { try? fm.removeItem(at: paths.root.deletingLastPathComponent()) }
        var a = Save(kind: .note, text: "a")
        a.title = "a"
        var b = Save(kind: .note, text: "b")
        b.title = "b"
        try await LibraryDisk.write(a, paths: paths)
        try await LibraryDisk.write(b, paths: paths)
        let first = await LibraryScan.run(paths: paths, previous: [:])
        let keyB = try #require(first.entries.first { $0.value.save.id == b.id }?.key)
        try fm.removeItem(at: paths.folder(for: b))

        let second = await LibraryScan.run(paths: paths, previous: first.entries, only: [keyB])
        #expect(second.saves.map(\.id) == [a.id])
        #expect(second.decoded == 0)
    }
}
