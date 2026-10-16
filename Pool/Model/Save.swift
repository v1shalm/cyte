import Foundation

nonisolated enum SaveKind: String, Codable, Sendable, CaseIterable {
    case image, link, note
}

nonisolated struct Save: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var kind: SaveKind
    var createdAt: Date
    var updatedAt: Date

    var title: String
    var url: URL?
    var text: String?
    var source: String?

    var original: String?
    var thumbnail: String?
    var favicon: String?

    var aspect: Double

    var tags: [String]
    var note: String

    var summary: String?
    var ocrText: String?
    var labels: [String]
    var palette: [String]
    var enriched: Int

    var pending: Bool

    var folderIDs: [String]?

    var folders: [String] {
        get { folderIDs ?? [] }
        set { folderIDs = newValue.isEmpty ? nil : newValue }
    }

    static let enrichVersion = 1

    init(id: String = Save.makeID(), kind: SaveKind, title: String = "", url: URL? = nil,
         text: String? = nil, source: String? = nil, aspect: Double = 0) {
        let now = Date()
        self.id = id
        self.kind = kind
        self.createdAt = now
        self.updatedAt = now
        self.title = title
        self.url = url
        self.text = text
        self.source = source
        self.aspect = aspect
        self.tags = []
        self.note = ""
        self.labels = []
        self.palette = []
        self.enriched = 0
        self.pending = false
    }

    static func makeID(date: Date = Date()) -> String {
        let ms = UInt64(date.timeIntervalSince1970 * 1000)
        let rand = UInt32.random(in: 0...UInt32.max)
        return String(ms, radix: 36).leftPadded(to: 9) + "-" + String(rand, radix: 36).leftPadded(to: 7)
    }

    var host: String? {
        guard let host = url?.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let host { return host }
        if let text, !text.isEmpty { return String(text.prefix(80)) }
        return kind == .image ? "Image" : "Untitled"
    }

    var haystack: String {
        var parts = [title, note, summary ?? "", ocrText ?? "", text ?? "", host ?? "", source ?? ""]
        parts += tags
        parts += labels
        return parts.joined(separator: " ").lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
    }
}

private extension String {
    nonisolated func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
