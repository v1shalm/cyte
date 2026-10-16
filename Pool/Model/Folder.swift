import Foundation

nonisolated struct Folder: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var createdAt: Date
    var position: Double

    init(name: String, position: Double) {
        self.id = Save.makeID()
        self.name = name
        self.createdAt = Date()
        self.position = position
    }
}
