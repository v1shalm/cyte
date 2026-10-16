import Foundation

nonisolated struct SmartRule: Codable, Hashable, Sendable {
    var tags: [String] = []
    var kind: SaveKind?
    var host: String?
    var days: Int?
    var color: String?

    var isEmpty: Bool { tags.isEmpty && kind == nil && host == nil && days == nil && color == nil }

    func matches(_ save: Save) -> Bool {
        if let kind, save.kind != kind { return false }
        if let host, (save.host ?? save.source ?? "") != host { return false }
        if let days, save.createdAt < Date().addingTimeInterval(-Double(days) * 86_400) { return false }
        if !tags.isEmpty {
            let own = Set((save.tags + save.labels).map { $0.lowercased() })
            if !tags.allSatisfy({ own.contains($0) }) { return false }
        }
        if let color, let hex = SearchQuery.colorNames[color], let rgb = Palette.rgb(hex), !SearchEngine.colorMatch(save, rgb) { return false }
        return true
    }
}

nonisolated struct Folder: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var createdAt: Date
    var position: Double
    var rule: SmartRule?

    init(name: String, position: Double) {
        self.id = Save.makeID()
        self.name = name
        self.createdAt = Date()
        self.position = position
    }
}
