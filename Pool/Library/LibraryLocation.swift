import Foundation

enum LibraryLocation {
    private static let key = "pool.libraryPath"

    static var iCloudDrive: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    static var iCloudDefault: URL? { iCloudDrive?.appending(path: "Pool", directoryHint: .isDirectory) }

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
