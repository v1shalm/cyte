import Foundation

final class ScreenshotWatcher {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pool.watchScreenshots") }
        set { UserDefaults.standard.set(newValue, forKey: "pool.watchScreenshots") }
    }

    nonisolated static var folder: URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let expanded = (path as NSString).expandingTildeInPath
            return URL(filePath: expanded, directoryHint: .isDirectory)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop", directoryHint: .isDirectory)
    }

    private var watcher: FolderWatcher?
    private var seen: Set<String> = []
    private let started = Date()
    private let onScreenshot: @MainActor (URL) -> Void

    init(onScreenshot: @escaping @MainActor (URL) -> Void) {
        self.onScreenshot = onScreenshot
    }

    func start() {
        guard watcher == nil else { return }
        _ = try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path(percentEncoded: false))
        watcher = FolderWatcher(url: Self.folder, latency: 0.4) { [weak self] paths in
            self?.handle(paths)
        }
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    @concurrent
    static func recentImagesInBackground(limit: Int) async -> [URL] {
        recentImages(limit: limit)
    }

    nonisolated static func recentImages(limit: Int) -> [URL] {
        let folder = Self.folder
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                       options: [.skipsHiddenFiles]) else { return [] }
        return files
            .filter { ImageFiles.isImage($0) }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
            .prefix(limit)
            .map { $0 }
    }

    private func handle(_ paths: [String]) {
        for path in paths where !seen.contains(path) {
            let url = URL(filePath: path)
            let name = url.lastPathComponent.lowercased()
            guard ImageFiles.isImage(url), !name.hasPrefix("."),
                  name.hasPrefix("screenshot") || name.hasPrefix("screen shot") || name.hasPrefix("cleanshot"),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let created = attributes[.creationDate] as? Date, created > started else { continue }
            seen.insert(path)
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                onScreenshot(url)
            }
        }
    }
}
