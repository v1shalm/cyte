import Foundation

enum LibraryBackend: String, CaseIterable, Identifiable {
    case iCloud
    case googleDrive
    case local
    case custom

    var id: String { rawValue }
}

enum LibraryLocation {
    private static let key = "pool.libraryPath"

    static var iCloudDrive: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    static var iCloudDefault: URL? { iCloudDrive?.appending(path: "Pool", directoryHint: .isDirectory) }

    static var googleDriveBase: URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let cloudStorage = home.appending(path: "Library/CloudStorage", directoryHint: .isDirectory)
        if let entries = try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            let candidates = entries
                .filter { $0.lastPathComponent.hasPrefix("GoogleDrive") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if let first = candidates.first {
                let myDrive = first.appending(path: "My Drive", directoryHint: .isDirectory)
                if fm.fileExists(atPath: myDrive.path(percentEncoded: false)) {
                    return myDrive
                }
                return first
            }
        }
        let legacy = home.appending(path: "Google Drive", directoryHint: .isDirectory)
        if fm.fileExists(atPath: legacy.path(percentEncoded: false)) {
            let myDrive = legacy.appending(path: "My Drive", directoryHint: .isDirectory)
            return fm.fileExists(atPath: myDrive.path(percentEncoded: false)) ? myDrive : legacy
        }
        return nil
    }

    static var googleDriveDefault: URL? {
        googleDriveBase?.appending(path: "Pool", directoryHint: .isDirectory)
    }

    static var homeDefault: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Pool", directoryHint: .isDirectory)
    }

    static var current: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: key) {
                return URL(filePath: path, directoryHint: .isDirectory)
            }
            return iCloudDefault ?? homeDefault
        }
        set { UserDefaults.standard.set(newValue.path(percentEncoded: false), forKey: key) }
    }

    static var isChosen: Bool { UserDefaults.standard.string(forKey: key) != nil }

    static func backend(for url: URL = current) -> LibraryBackend {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        if let iCloud = iCloudDefault?.standardizedFileURL.path(percentEncoded: false), path == iCloud {
            return .iCloud
        }
        if let gDrive = googleDriveDefault?.standardizedFileURL.path(percentEncoded: false), path == gDrive {
            return .googleDrive
        }
        if path.contains("/Library/CloudStorage/GoogleDrive") || path.contains("/Google Drive/") {
            return .googleDrive
        }
        if path == homeDefault.standardizedFileURL.path(percentEncoded: false) {
            return .local
        }
        return .custom
    }

    static func placeName(for url: URL) -> String {
        switch backend(for: url) {
        case .iCloud: L.Settings.iCloudDrive
        case .googleDrive: L.Settings.googleDrive
        case .local: L.Settings.localFolder
        case .custom: url.lastPathComponent == "Pool" ? url.deletingLastPathComponent().lastPathComponent : url.lastPathComponent
        }
    }

    static func resolveRoot(for chosenURL: URL) -> URL {
        let name = chosenURL.lastPathComponent.lowercased()
        if name == "pool" || name == "cyte" {
            return chosenURL
        }
        let fm = FileManager.default
        let hasSaves = fm.fileExists(atPath: chosenURL.appending(path: "Saves").path(percentEncoded: false))
        let hasFolders = fm.fileExists(atPath: chosenURL.appending(path: "Folders").path(percentEncoded: false))
        if hasSaves || hasFolders {
            return chosenURL
        }
        return chosenURL.appending(path: "Pool", directoryHint: .isDirectory)
    }
}

nonisolated struct LibraryPaths: Sendable {
    let root: URL

    var saves: URL { root.appending(path: "Saves", directoryHint: .isDirectory) }
    var inbox: URL { root.appending(path: "Inbox", directoryHint: .isDirectory) }
    var trash: URL { root.appending(path: "Trash", directoryHint: .isDirectory) }
    var folders: URL { root.appending(path: "Folders", directoryHint: .isDirectory) }

    func folder(for save: Save) -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.year, .month], from: save.createdAt)
        let month = String(format: "%04d-%02d", parts.year ?? 1970, parts.month ?? 1)
        return saves.appending(path: month, directoryHint: .isDirectory)
            .appending(path: save.id, directoryHint: .isDirectory)
    }

    func file(_ name: String?, of save: Save) -> URL? {
        guard let name else { return nil }
        return folder(for: save).appending(path: name, directoryHint: .notDirectory)
    }

    func ensureExists() throws {
        for url in [root, saves, inbox, trash, folders] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
