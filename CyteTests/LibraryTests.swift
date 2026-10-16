import Foundation
import Testing
@testable import Cyte

struct LibraryMoveTests {
    private let fm = FileManager.default

    private func makeRoot() throws -> URL {
        let root = fm.temporaryDirectory.appending(path: "cyte-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ text: String, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func `moves saves and keeps a source save whose name already exists`() async throws {
        let base = try makeRoot()
        defer { try? fm.removeItem(at: base) }
        let source = LibraryPaths(root: base.appending(path: "Old/Pool", directoryHint: .isDirectory))
        let destination = LibraryPaths(root: base.appending(path: "New/Cyte", directoryHint: .isDirectory))
        try source.ensureExists()
        try destination.ensureExists()
        let month = "2026-10"
        try write("a", to: source.saves.appending(path: "\(month)/a/save.json"))
        try write("b-source", to: source.saves.appending(path: "\(month)/b/save.json"))
        try write("b-destination", to: destination.saves.appending(path: "\(month)/b/save.json"))
        try write("folder", to: source.folders.appending(path: "f.json"))

        let moved = await LibraryDisk.migrate(from: source, to: destination)

        #expect(moved == 1)
        #expect(fm.fileExists(atPath: destination.saves.appending(path: "\(month)/a/save.json").path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: source.saves.appending(path: "\(month)/a").path(percentEncoded: false)))
        let keptSource = try String(contentsOf: source.saves.appending(path: "\(month)/b/save.json"), encoding: .utf8)
        let keptDestination = try String(contentsOf: destination.saves.appending(path: "\(month)/b/save.json"), encoding: .utf8)
        #expect(keptSource == "b-source")
        #expect(keptDestination == "b-destination")
        #expect(fm.fileExists(atPath: destination.folders.appending(path: "f.json").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: source.root.path(percentEncoded: false)))
    }

    @Test func `moving to the same folder does nothing`() async throws {
        let base = try makeRoot()
        defer { try? fm.removeItem(at: base) }
        let paths = LibraryPaths(root: base.appending(path: "Cyte", directoryHint: .isDirectory))
        try paths.ensureExists()
        try write("a", to: paths.saves.appending(path: "2026-10/a/save.json"))
        #expect(await LibraryDisk.migrate(from: paths, to: paths) == 0)
        #expect(fm.fileExists(atPath: paths.saves.appending(path: "2026-10/a/save.json").path(percentEncoded: false)))
    }
}

struct LibraryLocationTests {
    private let fm = FileManager.default

    @Test(arguments: ["Pool", "Cyte", "cyte"])
    func `a folder already named for the library is used as is`(name: String) {
        let url = URL(filePath: "/tmp/somewhere/\(name)", directoryHint: .isDirectory)
        #expect(LibraryLocation.resolveRoot(for: url) == url)
    }

    @Test func `any other folder gets a Cyte folder inside`() {
        let url = URL(filePath: "/tmp/cyte-empty-\(UUID().uuidString)", directoryHint: .isDirectory)
        #expect(LibraryLocation.resolveRoot(for: url).lastPathComponent == "Cyte")
    }

    @Test func `a folder that already holds a library is used as is`() throws {
        let url = fm.temporaryDirectory.appending(path: "cyte-lib-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: url.appending(path: "Saves"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: url) }
        #expect(LibraryLocation.resolveRoot(for: url) == url)
    }

    @Test func `places are named by where the folder lives`() {
        let home = fm.homeDirectoryForCurrentUser
        #expect(LibraryLocation.backend(for: home.appending(path: "Pool", directoryHint: .isDirectory)) == .local)
        #expect(LibraryLocation.backend(for: home.appending(path: "Cyte", directoryHint: .isDirectory)) == .local)
        #expect(LibraryLocation.backend(for: URL(filePath: "/Volumes/Work/Refs/Cyte", directoryHint: .isDirectory)) == .custom)
        #expect(LibraryLocation.placeName(for: URL(filePath: "/Volumes/Work/Refs/Cyte", directoryHint: .isDirectory)) == "Refs")
        if let iCloud = LibraryLocation.iCloudDrive {
            #expect(LibraryLocation.backend(for: iCloud.appending(path: "Pool", directoryHint: .isDirectory)) == .iCloud)
        }
    }
}

struct IdentityMigrationTests {
    private func scratch() -> (UserDefaults, String) {
        let name = "app.cyte.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func `copies old settings once and keeps newer values`() {
        let (defaults, domain) = scratch()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.setPersistentDomain(["pool.columnWidth": 300.0], forName: domain)
        let legacy: [String: Any] = [
            "pool.libraryPath": "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Pool/",
            "pool.columnWidth": 248.0,
            "pool.onboarded": true,
            "NSWindow Frame main": "0 0 100 100",
        ]

        Identity.migrateLegacyDefaults(into: defaults, domain: domain, from: legacy)
        let saved = defaults.persistentDomain(forName: domain) ?? [:]

        #expect(saved["pool.libraryPath"] as? String == "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Pool/")
        #expect(saved["pool.onboarded"] as? Bool == true)
        #expect(saved["pool.columnWidth"] as? Double == 300)
        #expect(saved["NSWindow Frame main"] == nil)
        #expect(saved["cyte.migrated"] as? Bool == true)

        Identity.migrateLegacyDefaults(into: defaults, domain: domain, from: ["pool.sound": false])
        #expect(defaults.persistentDomain(forName: domain)?["pool.sound"] == nil)
    }

    @Test func `does nothing without old settings`() {
        let (defaults, domain) = scratch()
        defer { defaults.removePersistentDomain(forName: domain) }
        Identity.migrateLegacyDefaults(into: defaults, domain: domain, from: nil)
        #expect(defaults.persistentDomain(forName: domain)?["cyte.migrated"] == nil)
    }
}

struct DiagnosticsTests {
    @Test func `stores each report once and lists the newest first`() throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appending(path: "cyte-diag-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: directory) }
        let suite = "app.cyte.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let diagnostics = Diagnostics(directory: directory, defaults: defaults)
        let first = Data(#"{"crash":1}"#.utf8)
        let second = Data(#"{"crash":2}"#.utf8)
        diagnostics.write([first])
        diagnostics.write([first, second])
        diagnostics.reload()
        #expect(diagnostics.reports.count == 2)
        diagnostics.clear()
        #expect(diagnostics.reports.isEmpty)
        diagnostics.write([first, second])
        diagnostics.reload()
        #expect(diagnostics.reports.isEmpty)
    }
}
