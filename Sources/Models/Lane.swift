import Foundation

enum Lane: String, Codable, CaseIterable {
    case now
    case nxt
    case ltr

    var displayName: String {
        rawValue.uppercased()
    }

    var placeholder: String {
        "add to \(rawValue)..."
    }
}
