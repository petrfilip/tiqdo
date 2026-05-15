import Foundation

extension Date {
    var relativeString: String {
        relativeString(relativeTo: Date())
    }

    func relativeString(relativeTo referenceDate: Date) -> String {
        let seconds = max(0, Int(referenceDate.timeIntervalSince(self)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = seconds / 3600
        if hours < 24 { return "\(hours)h" }
        let days = seconds / 86400
        if days < 30 { return "\(days)d" }
        return "\(days / 30)mo"
    }
}
