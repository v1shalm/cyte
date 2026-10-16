import Foundation
import NaturalLanguage

nonisolated struct SearchQuery: Equatable, Sendable {
    var words: [String] = []
    var excluded: [String] = []
    var tags: [String] = []
    var kind: SaveKind?
    var host: String?
    var color: SIMD3<Float>?

    var isEmpty: Bool {
        words.isEmpty && excluded.isEmpty && tags.isEmpty && kind == nil && host == nil && color == nil
    }

    static let colorNames: [String: String] = [
        "red": "#D7263D", "orange": "#F46A1F", "yellow": "#F2C230", "green": "#3A9D5D", "teal": "#2A9D8F",
        "blue": "#2563EB", "navy": "#1E2A5A", "purple": "#7C3AED", "pink": "#EC6FA9", "brown": "#8B5A3C",
        "beige": "#D9C7A7", "black": "#111111", "white": "#F7F7F5", "gray": "#8E8E8E", "grey": "#8E8E8E",
    ]

    init() {}

    init(_ raw: String) {
        let tokens = raw.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).map(String.init)
        for token in tokens {
            if token.hasPrefix("-"), token.count > 1 {
                excluded.append(String(token.dropFirst()))
            } else if token.hasPrefix("#"), token.count == 7, let rgb = Palette.rgb(token) {
                color = rgb
            } else if token.hasPrefix("#"), token.count > 1 {
                tags.append(String(token.dropFirst()))
            } else if token.hasPrefix("type:") || token.hasPrefix("is:") {
                let value = token.split(separator: ":").last.map(String.init) ?? ""
                kind = SaveKind(rawValue: value.hasSuffix("s") ? String(value.dropLast()) : value)
            } else if token.hasPrefix("from:") || token.hasPrefix("site:") {
                host = String(token.split(separator: ":", maxSplits: 1).last ?? "")
            } else if token.hasPrefix("color:") || token.hasPrefix("colour:") {
                let value = String(token.split(separator: ":", maxSplits: 1).last ?? "")
                color = Palette.rgb(Self.colorNames[value] ?? value)
            } else if let hex = Self.colorNames[token], tokens.count <= 2 {
                color = Palette.rgb(hex)
                words.append(token)
            } else {
                words.append(token)
            }
        }
    }
}

nonisolated struct SearchResult: Sendable {
    var matches: [Save]
    var related: [Save]
}

@MainActor
final class SearchEngine {
    private var embeddingCache: [String: (stamp: Date, vector: [Double])] = [:]
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    func run(_ raw: String, kind: SaveKind?, in saves: [Save]) -> SearchResult {
        var query = SearchQuery(raw)
        if query.kind == nil { query.kind = kind }
        guard !query.isEmpty else { return SearchResult(matches: saves, related: []) }

        let colorOnly = query.color != nil
        var matches: [Save] = []
        for save in saves where Self.passesFilters(save, query) {
            let hay = save.haystack
            if !query.excluded.allSatisfy({ !hay.contains($0) }) { continue }
            if colorOnly {
                if Self.colorMatch(save, query.color!) || (!query.words.isEmpty && query.words.allSatisfy(hay.contains)) {
                    matches.append(save)
                }
                continue
            }
            if query.words.allSatisfy(hay.contains) { matches.append(save) }
        }

        var related: [Save] = []
        if !query.words.isEmpty, !colorOnly, matches.count < 12, let embedding {
            let sentence = query.words.joined(separator: " ")
            if let target = embedding.vector(for: sentence) {
                let matchedIDs = Set(matches.map(\.id))
                let scored = saves.lazy
                    .filter { !matchedIDs.contains($0.id) && Self.passesFilters($0, query) }
                    .compactMap { save -> (Save, Double)? in
                        guard let vector = self.vector(for: save, embedding: embedding) else { return nil }
                        return (save, Self.cosine(target, vector))
                    }
                related = scored.filter { $0.1 > 0.55 }.sorted { $0.1 > $1.1 }.prefix(24).map(\.0)
            }
        }
        return SearchResult(matches: matches, related: related)
    }

    private static func passesFilters(_ save: Save, _ query: SearchQuery) -> Bool {
        if let kind = query.kind, save.kind != kind { return false }
        if let host = query.host, !(save.host ?? save.source ?? "").contains(host) { return false }
        if !query.tags.isEmpty {
            let tags = Set((save.tags + save.labels).map { $0.lowercased() })
            if !query.tags.allSatisfy({ tag in tags.contains { $0.contains(tag) } }) { return false }
        }
        return true
    }

    private static func colorMatch(_ save: Save, _ color: SIMD3<Float>) -> Bool {
        save.palette.prefix(3).contains { hex in
            guard let rgb = Palette.rgb(hex) else { return false }
            let delta = rgb - color
            return (delta * delta).sum().squareRoot() < 70
        }
    }

    private func vector(for save: Save, embedding: NLEmbedding) -> [Double]? {
        if let cached = embeddingCache[save.id], cached.stamp == save.updatedAt { return cached.vector }
        let text = ([save.title, save.summary ?? ""] + save.tags + save.labels)
            .filter { !$0.isEmpty }.joined(separator: ". ")
        guard !text.isEmpty, let vector = embedding.vector(for: String(text.prefix(500))) else { return nil }
        embeddingCache[save.id] = (save.updatedAt, vector)
        return vector
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for index in a.indices {
            dot += a[index] * b[index]
            na += a[index] * a[index]
            nb += b[index] * b[index]
        }
        return na > 0 && nb > 0 ? dot / (na.squareRoot() * nb.squareRoot()) : 0
    }
}
