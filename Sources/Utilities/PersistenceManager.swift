import Foundation
import OSLog

final class PersistenceManager {
    private let defaults = UserDefaults.standard
    private let legacyTabsKey = "tiqdo.tabs"
    private let legacyTasksKey = "tiqdo.tasks"
    private let queue = DispatchQueue(label: "cz.fg.tiqdo.persistence", qos: .utility)
    private let logger = Logger(subsystem: "cz.fg.tiqdo", category: "Persistence")

    private let directoryURL: URL
    private let tabsURL: URL
    private let tasksURL: URL
    private let historyURL: URL

    init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directoryURL = baseURL.appendingPathComponent("Tiqdo", isDirectory: true)
        tabsURL = directoryURL.appendingPathComponent("tabs.json")
        tasksURL = directoryURL.appendingPathComponent("tasks.json")
        historyURL = directoryURL.appendingPathComponent("history.json")
        createDirectoryIfNeeded()
    }

    func loadTabs() -> [TiqTab] {
        load([TiqTab].self, from: tabsURL)
            ?? loadLegacy([TiqTab].self, key: legacyTabsKey, migrateTo: tabsURL)
            ?? [TiqTab(id: UUID(), name: "Personal", sortOrder: 0)]
    }

    func loadTasks() -> [TiqTask] {
        load([TiqTask].self, from: tasksURL)
            ?? loadLegacy([TiqTask].self, key: legacyTasksKey, migrateTo: tasksURL)
            ?? []
    }

    func loadHistory() -> [HistoryRecord] {
        load([HistoryRecord].self, from: historyURL) ?? []
    }

    func save(tabs: [TiqTab], tasks: [TiqTask]) {
        queue.async { [tabs, tasks, weak self] in
            guard let self else { return }
            write(tabs, to: tabsURL)
            write(tasks, to: tasksURL)
        }
    }

    func saveHistory(_ records: [HistoryRecord]) {
        queue.async { [records, weak self] in
            guard let self else { return }
            write(records, to: historyURL)
        }
    }

    func saveAndWait(tabs: [TiqTab], tasks: [TiqTask]) {
        queue.sync { [tabs, tasks, weak self] in
            guard let self else { return }
            write(tabs, to: tabsURL)
            write(tasks, to: tasksURL)
        }
    }

    func clearAll() {
        queue.sync { [weak self] in
            guard let self else { return }
            removeFile(at: tabsURL)
            removeFile(at: tasksURL)
            removeFile(at: historyURL)
            defaults.removeObject(forKey: legacyTabsKey)
            defaults.removeObject(forKey: legacyTasksKey)
        }
    }

    private func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create persistence directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Failed to load \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            quarantineCorruptFile(at: url)
            return nil
        }
    }

    private func loadLegacy<T: Codable>(_ type: T.Type, key: String, migrateTo url: URL) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let value = try JSONDecoder().decode(type, from: data)
            write(value, to: url)
            return value
        } catch {
            logger.error("Failed to decode legacy defaults \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func write<T: Encodable>(_ value: T, to optionalURL: URL?) {
        guard let url = optionalURL else { return }
        do {
            createDirectoryIfNeeded()
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.error("Failed to save \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Failed to remove \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func quarantineCorruptFile(at url: URL) {
        let formatter = ISO8601DateFormatter()
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")

        do {
            try FileManager.default.moveItem(at: url, to: backupURL)
        } catch {
            logger.error("Failed to quarantine \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
