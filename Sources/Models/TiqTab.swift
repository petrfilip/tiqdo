import Foundation

struct TiqTab: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sortOrder: Int
}
