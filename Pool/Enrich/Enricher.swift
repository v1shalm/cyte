import Foundation
import FoundationModels
import Observation
import OSLog

@Generable
nonisolated struct SaveInsight {
    @Guide(description: "A specific title of two to six words in sentence case, naming what the item shows")
    var title: String
    @Guide(description: "One plain sentence describing what this item is")
    var summary: String
    @Guide(description: "Three to six lowercase tags of one or two words each")
    var tags: [String]
}

@Observable
final class Enricher {
    private(set) var activeID: String?

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var queue: [String] = []
    @ObservationIgnored private var running = false
    @ObservationIgnored private var session: LanguageModelSession?
    private let log = Logger(subsystem: "in.tistmedia.pool", category: "enrich")

    init(store: LibraryStore) {
        self.store = store
    }

    var modelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func enrich(_ id: String) {
        if !queue.contains(id) { queue.append(id) }
        pump()
    }

    func enrichMissing() {
        for save in store.saves where save.enriched < Save.enrichVersion && !save.pending {
            enrich(save.id)
        }
    }

    func similar(to save: Save, limit: Int = 8) async -> [String] {
        let paths = store.paths
        let saves = store.saves.filter { $0.kind != .note }
        guard let target = try? Data(contentsOf: paths.folder(for: save).appending(path: "print.bin")) else { return [] }
        let candidates = await Self.loadPrints(saves.filter { $0.id != save.id }, paths: paths)
        return await VisionPass.nearest(to: target, among: candidates, limit: limit)
    }

    private func pump() {
        guard !running else { return }
        running = true
        Task {
            while !queue.isEmpty {
                let id = queue.removeFirst()
                activeID = id
                await run(id)
            }
            activeID = nil
            running = false
        }
    }

    private func run(_ id: String) async {
        guard let save = store.save(id: id), !save.pending else { return }
        let folder = store.folder(for: save)

        var vision = VisionResult()
        if let thumb = store.url(for: save, file: save.thumbnail) {
            vision = await VisionPass.analyze(thumb)
            if let data = vision.printData {
                try? await Self.write(data, to: folder.appending(path: "print.bin"))
            }
        }

        let insight = await describe(save, vision: vision)

        store.modify(id) { save in
            save.ocrText = vision.text
            save.labels = vision.labels
            save.palette = vision.palette
            if let insight {
                let title = insight.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if Self.needsTitle(save), !title.isEmpty { save.title = title }
                if save.summary == nil || save.kind != .link { save.summary = insight.summary }
                if save.tags.isEmpty {
                    save.tags = Array(insight.tags.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }.prefix(6))
                }
            }
            save.enriched = Save.enrichVersion
        }
    }

    private func describe(_ save: Save, vision: VisionResult) async -> SaveInsight? {
        guard modelAvailable else { return nil }
        var facts: [String] = ["Kind: \(save.kind.rawValue)"]
        if !save.title.isEmpty { facts.append("Current title: \(save.title)") }
        if let host = save.host { facts.append("Website: \(host)") }
        if let summary = save.summary { facts.append("Page description: \(summary.prefix(400))") }
        if let text = save.text { facts.append("Note text: \(text.prefix(800))") }
        if let ocr = vision.text { facts.append("Text visible in the image: \(ocr.prefix(600))") }
        if !vision.labels.isEmpty { facts.append("Objects detected: \(vision.labels.joined(separator: ", "))") }
        guard facts.count > 1 else { return nil }

        let session = LanguageModelSession(instructions: """
            You label items a designer saved for reference: images, screenshots, web links and short notes.
            Use only the facts given. Do not invent brands, people or places that the facts do not mention.
            Prefer concrete visual and subject words such as poster, packaging, typography, interior, landing page.
            """)
        do {
            let response = try await session.respond(to: facts.joined(separator: "\n"), generating: SaveInsight.self)
            return response.content
        } catch {
            log.notice("Model skipped \(save.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func needsTitle(_ save: Save) -> Bool {
        let title = save.title.trimmingCharacters(in: .whitespaces)
        if title.isEmpty { return true }
        if save.kind == .link { return title == save.host }
        let lower = title.lowercased()
        let generic = ["screenshot", "screen shot", "img_", "image", "untitled", "original", "cleanshot", "photo"]
        return generic.contains { lower.hasPrefix($0) } || title.allSatisfy { $0.isNumber || $0 == "-" || $0 == "_" }
    }

    @concurrent
    private static func write(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }

    @concurrent
    private static func loadPrints(_ saves: [Save], paths: LibraryPaths) async -> [(id: String, data: Data)] {
        saves.compactMap { save in
            guard let data = try? Data(contentsOf: paths.folder(for: save).appending(path: "print.bin")) else { return nil }
            return (save.id, data)
        }
    }
}
