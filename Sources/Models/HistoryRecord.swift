import Foundation

struct HistoryRecord: Identifiable, Codable {
    let id: UUID
    let title: String
    let completedAt: Date
    let tabId: UUID
}
