import AppKit
import CryptoKit
import Foundation
import OSLog
import UniformTypeIdentifiers

final class Ingestor {
    private let store: LibraryStore
    private let enricher: Enricher
    private let feedback: Feedback
    private let log = Logger(subsystem: Identity.subsystem, category: "ingest")
    private var inboxBusy = false

    init(store: LibraryStore, enricher: Enricher, feedback: Feedback) {
        self.store = store
        self.enricher = enricher
        self.feedback = feedback
    }


    func ingest(providers: [NSItemProvider]) {
        Task {
            var count = 0
            for provider in providers {
                if await ingest(provider: provider) { count += 1 }
            }
            announce(count)
        }
    }

    func ingest(fileURLs: [URL], source: String? = nil, quiet: Bool = false, into folderID: String? = nil) {
        Task {
            var count = 0
            for url in fileURLs {
                guard let save = await ingestFile(url, source: source) else { continue }
                count += 1
                if let folderID { store.modify(save.id) { if !$0.folders.contains(folderID) { $0.folders.append(folderID) } } }
            }
            if !quiet { announce(count) }
        }
    }

    @discardableResult
    func pasteFromClipboard() -> Bool {
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            ingest(fileURLs: urls, source: "clipboard")
            return true
        }
        let gifType = NSPasteboard.PasteboardType(UTType.gif.identifier)
        if let data = board.data(forType: gifType) {
            Task { if await ingestImage(data: data, source: "clipboard") != nil { announce(1) } }
            return true
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType("public.jpeg")] {
            if let data = board.data(forType: type) {
                Task { if await ingestImage(data: data, source: "clipboard") != nil { announce(1) } }
                return true
            }
        }
        if let string = board.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            Task { if await ingest(text: string, source: "clipboard") { announce(1) } }
            return true
        }
        feedback.toast(L.Toast.nothingToPaste)
        return false
    }

    func ingest(link url: URL, title: String? = nil, source: String? = nil) {
        Task { if await ingestLink(url, title: title, source: source) != nil { announce(1) } }
    }

    func addNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !trimmed.contains(where: \.isWhitespace), let url = Self.webURL(in: trimmed) {
            ingest(link: url, source: "note")
            return
        }
        var save = Save(kind: .note, text: trimmed, source: "note")
        save.title = ""
        store.insert(save)
        feedback.saved()
        enricher.enrich(save.id)
    }


    func processInbox() {
        guard !inboxBusy else { return }
        inboxBusy = true
        Task {
            defer { inboxBusy = false }
            let inbox = store.paths.inbox
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { return }
            var count = 0
            for file in files {
                if file.pathExtension == "icloud" {
                    try? fm.startDownloadingUbiquitousItem(at: file)
                    continue
                }
                let ok: Bool
                switch file.pathExtension.lowercased() {
                case "txt", "url", "webloc", "text":
                    ok = await ingest(text: Self.readLinkFile(file) ?? "", source: "iphone")
                default:
                    ok = ImageFiles.isMedia(file) ? await ingestFile(file, source: "iphone") != nil : false
                }
                if ok { count += 1 }
                try? fm.removeItem(at: file)
            }
            announce(count)
        }
    }


    private func ingest(provider: NSItemProvider) async -> Bool {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let data = await provider.data(for: .fileURL),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return await ingestFile(url, source: nil) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier),
           let data = await provider.data(for: .movie) {
            return await ingestVideo(data: data, source: nil) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier),
           let data = await provider.data(for: .gif) {
            return await ingestImage(data: data, source: nil) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let data = await provider.data(for: .url),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return await ingestLink(url, title: provider.suggestedName, source: nil) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = await provider.data(for: .image) {
            return await ingestImage(data: data, source: nil) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let data = await provider.data(for: .plainText) {
            return await ingest(text: String(decoding: data, as: UTF8.self), source: nil)
        }
        return false
    }

    private func ingest(text: String, source: String?) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let url = Self.webURL(in: trimmed) {
            return await ingestLink(url, title: nil, source: source) != nil
        }
        let save = Save(kind: .note, text: trimmed, source: source ?? "note")
        store.insert(save)
        enricher.enrich(save.id)
        return true
    }

    private func ingestFile(_ url: URL, source: String?) async -> Save? {
        if ImageFiles.isVideo(url) {
            let save = Save(kind: .image, title: url.deletingPathExtension().lastPathComponent, source: source ?? "file")
            let folder = store.folder(for: save)
            guard let prepared = await Self.prepareVideo(copying: url, into: folder) else { return nil }
            if reportDuplicate(prepared, folder: folder) { return nil }
            return commit(save, prepared: prepared)
        }
        if ImageFiles.isImage(url) {
            let save = Save(kind: .image, title: url.deletingPathExtension().lastPathComponent, source: source ?? "file")
            let folder = store.folder(for: save)
            guard let prepared = await Self.prepareImage(copying: url, into: folder) else { return nil }
            if reportDuplicate(prepared, folder: folder) { return nil }
            return commit(save, prepared: prepared)
        }
        if ["webloc", "url"].contains(url.pathExtension.lowercased()),
           let text = Self.readLinkFile(url), let link = Self.webURL(in: text) {
            return await ingestLink(link, title: url.deletingPathExtension().lastPathComponent, source: source)
        }
        return nil
    }

    private func ingestImage(data: Data, source: String?, url: URL? = nil) async -> Save? {
        let save = Save(kind: .image, url: url, source: source ?? url?.host())
        let folder = store.folder(for: save)
        guard let prepared = await Self.prepareImage(data: data, into: folder) else { return nil }
        if reportDuplicate(prepared, folder: folder) { return nil }
        return commit(save, prepared: prepared)
    }

    private func ingestVideo(data: Data, source: String?, url: URL? = nil) async -> Save? {
        let save = Save(kind: .image, url: url, source: source ?? url?.host())
        let folder = store.folder(for: save)
        guard let prepared = await Self.prepareVideo(data: data, into: folder) else { return nil }
        if reportDuplicate(prepared, folder: folder) { return nil }
        return commit(save, prepared: prepared)
    }

    private func reportDuplicate(_ prepared: PreparedImage, folder: URL) -> Bool {
        guard let existing = store.saves.first(where: { $0.contentHash == prepared.hash }) else { return false }
        try? FileManager.default.removeItem(at: folder)
        feedback.toast(L.Toast.duplicateImage)
        feedback.focus(existing.id)
        return true
    }

    @discardableResult
    private func commit(_ save: Save, prepared: PreparedImage) -> Save {
        var save = save
        save.original = prepared.original
        save.thumbnail = prepared.thumbnail
        save.aspect = prepared.aspect
        save.contentHash = prepared.hash
        store.insert(save)
        enricher.enrich(save.id)
        return save
    }

    private func ingestLink(_ url: URL, title: String?, source: String?) async -> Save? {
        if let existing = store.saves.first(where: { $0.url == url && $0.kind == .link }) {
            feedback.toast(L.Toast.duplicate)
            feedback.focus(existing.id)
            return nil
        }
        if Self.looksLikeVideo(url), let data = await LinkPreview.downloadMedia(url) {
            return await ingestVideo(data: data, source: source, url: url)
        }
        if Self.looksLikeImage(url), let data = await LinkPreview.download(url) {
            return await ingestImage(data: data, source: source, url: url)
        }

        var save = Save(kind: .link, title: title ?? "", url: url, source: source)
        save.pending = true
        store.insert(save)
        let id = save.id
        let folder = store.folder(for: save)

        Task {
            let preview = await LinkPreview.fetch(url)
            let files = await Self.writePreviewFiles(preview, into: folder)
            store.modify(id) { save in
                if save.title.isEmpty || save.title == save.host { save.title = preview.title ?? save.title }
                if save.summary == nil, let description = preview.description, !description.isEmpty {
                    save.summary = String(description.prefix(280))
                }
                save.thumbnail = files.thumbnail
                save.favicon = files.favicon
                save.aspect = files.aspect
                save.pending = false
            }
            enricher.enrich(id)
        }
        return save
    }

    private func announce(_ count: Int) {
        guard count > 0 else { return }
        feedback.saved(count: count)
    }


    nonisolated struct PreparedImage: Sendable {
        let original: String
        let thumbnail: String
        var aspect: Double
        let hash: String
    }

    @concurrent
    private static func prepareImage(copying source: URL, into folder: URL) async -> PreparedImage? {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
            let original = "original.\(ext)"
            let dest = folder.appending(path: original)
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: source, to: dest)
            return finish(folder: folder, original: original)
        } catch {
            return nil
        }
    }

    @concurrent
    private static func prepareImage(data: Data, into folder: URL) async -> PreparedImage? {
        guard ImageFiles.info(data: data) != nil else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = "original.\(ImageFiles.fileExtension(for: data))"
            try data.write(to: folder.appending(path: original), options: .atomic)
            return finish(folder: folder, original: original)
        } catch {
            return nil
        }
    }

    @concurrent
    private static func prepareVideo(copying source: URL, into folder: URL) async -> PreparedImage? {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let ext = source.pathExtension.isEmpty ? "mp4" : source.pathExtension.lowercased()
            let original = "original.\(ext)"
            let dest = folder.appending(path: original)
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: source, to: dest)
            return await finishVideo(folder: folder, original: original)
        } catch {
            return nil
        }
    }

    @concurrent
    private static func prepareVideo(data: Data, into folder: URL) async -> PreparedImage? {
        let ext = ImageFiles.videoExtension(for: data) ?? "mp4"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = "original.\(ext)"
            try data.write(to: folder.appending(path: original), options: .atomic)
            return await finishVideo(folder: folder, original: original)
        } catch {
            return nil
        }
    }

    nonisolated private static func finish(folder: URL, original: String) -> PreparedImage? {
        let originalURL = folder.appending(path: original)
        guard let info = ImageFiles.info(at: originalURL),
              let thumb = ImageFiles.downsample(originalURL, maxPixel: 1400) else { return nil }
        ImageFiles.writeThumbnail(from: thumb, to: folder.appending(path: "thumb.jpg"))
        let hash = (try? Data(contentsOf: originalURL, options: .mappedIfSafe)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? UUID().uuidString
        return PreparedImage(original: original, thumbnail: "thumb.jpg", aspect: info.aspect, hash: hash)
    }

    private static func finishVideo(folder: URL, original: String) async -> PreparedImage? {
        let originalURL = folder.appending(path: original)
        guard let poster = await ImageFiles.extractVideoPoster(at: originalURL, maxPixel: 1400) else { return nil }
        ImageFiles.writeThumbnail(from: poster.image, to: folder.appending(path: "thumb.jpg"))
        let hash = (try? Data(contentsOf: originalURL, options: .mappedIfSafe)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? UUID().uuidString
        return PreparedImage(original: original, thumbnail: "thumb.jpg", aspect: poster.info.aspect, hash: hash)
    }

    nonisolated struct PreviewFiles: Sendable {
        var thumbnail: String?
        var favicon: String?
        var aspect: Double = 0
    }

    @concurrent
    private static func writePreviewFiles(_ preview: LinkPreviewResult, into folder: URL) async -> PreviewFiles {
        var files = PreviewFiles()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = preview.imageData, let image = ImageFiles.downsample(data: data, maxPixel: 1400),
           ImageFiles.writeThumbnail(from: image, to: folder.appending(path: "thumb.jpg")) {
            files.thumbnail = "thumb.jpg"
            files.aspect = Double(image.width) / Double(max(image.height, 1))
        }
        if let data = preview.iconData {
            try? data.write(to: folder.appending(path: "icon.png"), options: .atomic)
            files.favicon = "icon.png"
        }
        return files
    }


    nonisolated static func webURL(in text: String) -> URL? {
        let candidate = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        guard !candidate.contains(" "), let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil else { return nil }
        return url
    }

    nonisolated static func looksLikeImage(_ url: URL) -> Bool {
        ["jpg", "jpeg", "png", "gif", "webp", "heic", "avif", "tiff"].contains(url.pathExtension.lowercased())
    }

    nonisolated static func looksLikeVideo(_ url: URL) -> Bool {
        ImageFiles.videoExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated static func readLinkFile(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if url.pathExtension.lowercased() == "webloc",
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist["URL"] as? String
        }
        let text = String(decoding: data, as: UTF8.self)
        if url.pathExtension.lowercased() == "url",
           let line = text.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("URL=") }) {
            return String(line.dropFirst(4))
        }
        return text
    }
}

private extension NSItemProvider {
    func data(for type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, _ in continuation.resume(returning: data) }
        }
    }
}
