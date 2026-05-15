import Foundation

struct TiqTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var lane: Lane
    var tabId: UUID
    var isCompleted: Bool
    var completedAt: Date?
    let createdAt: Date
    var sortOrder: Int
}
