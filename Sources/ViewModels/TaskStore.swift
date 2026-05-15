import Foundation
import Observation

@Observable
final class TaskStore {
    var tabs: [TiqTab]
    var tasks: [TiqTask]
    var activeTabId: UUID
    var showCompletedTasks: Bool
    var appearanceMode: AppearanceMode
    var editingTaskId: UUID?
    var relativeDateReference: Date
    var historyRecords: [HistoryRecord]
    var historyMaxRecords: Int

    @ObservationIgnored private let persistence: PersistenceManager
    @ObservationIgnored private var pendingSaveWorkItem: DispatchWorkItem?
    @ObservationIgnored private var maintenanceTimer: Timer?
    @ObservationIgnored private let saveDelay: TimeInterval = 0.25

    init() {
        let persistence = PersistenceManager()
        self.persistence = persistence
        let loadedTabs = Self.normalizedTabs(persistence.loadTabs())
        self.tabs = loadedTabs
        self.tasks = persistence.loadTasks()
        self.activeTabId = loadedTabs.first?.id ?? UUID()
        self.showCompletedTasks = UserDefaults.standard.object(forKey: "tiqdo.showCompleted") as? Bool ?? false
        let raw = UserDefaults.standard.string(forKey: "tiqdo.appearance") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
        self.historyRecords = persistence.loadHistory()
        self.historyMaxRecords = UserDefaults.standard.object(forKey: "tiqdo.historyMaxRecords") as? Int ?? 5000
        self.relativeDateReference = Date()
        cleanupOldCompleted()
        startMaintenanceTimer()
    }

    deinit {
        pendingSaveWorkItem?.cancel()
        maintenanceTimer?.invalidate()
    }

    // MARK: - Computed

    var activeTaskCount: Int {
        tasks.reduce(0) { count, task in
            count + (task.tabId == activeTabId ? 1 : 0)
        }
    }

    func tasksForLane(_ lane: Lane) -> [TiqTask] {
        tasks
            .filter { task in
                task.tabId == activeTabId
                    && task.lane == lane
                    && (showCompletedTasks || !task.isCompleted)
            }
            .sorted(by: displayOrder)
    }

    var progress: Double {
        var total = 0
        var completed = 0
        for task in tasks where task.tabId == activeTabId {
            total += 1
            if task.isCompleted { completed += 1 }
        }
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    func taskCount(for tabId: UUID) -> Int {
        tasks.reduce(0) { count, task in
            count + (task.tabId == tabId && !task.isCompleted ? 1 : 0)
        }
    }

    func incompleteCount(for lane: Lane) -> Int {
        tasks.reduce(0) { count, task in
            count + (task.tabId == activeTabId && task.lane == lane && !task.isCompleted ? 1 : 0)
        }
    }

    func relativeString(for date: Date) -> String {
        date.relativeString(relativeTo: relativeDateReference)
    }

    // MARK: - Task CRUD

    func addTask(title: String, lane: Lane) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let maxOrder = tasks
            .filter { $0.tabId == activeTabId && $0.lane == lane }
            .map(\.sortOrder).max() ?? -1
        let task = TiqTask(
            id: UUID(),
            title: trimmed,
            lane: lane,
            tabId: activeTabId,
            isCompleted: false,
            completedAt: nil,
            createdAt: Date(),
            sortOrder: maxOrder + 1
        )
        tasks.append(task)
        save()
    }

    func toggleComplete(_ taskId: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].isCompleted.toggle()
        tasks[idx].completedAt = tasks[idx].isCompleted ? Date() : nil
        if tasks[idx].isCompleted {
            recordHistory(tasks[idx])
        }
        save()
    }

    func updateTask(_ taskId: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = tasks.firstIndex(where: { $0.id == taskId })
        else { return }
        tasks[idx].title = trimmed
        save()
    }

    func deleteTask(_ taskId: UUID) {
        let before = tasks.count
        tasks.removeAll { $0.id == taskId }
        if tasks.count != before { save() }
    }

    func moveTask(id: UUID, toLane lane: Lane) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }),
              tasks[idx].lane != lane
        else { return }
        let tabId = tasks[idx].tabId
        tasks[idx].lane = lane
        let maxOrder = tasks
            .filter { $0.tabId == tabId && $0.lane == lane && $0.id != id }
            .map(\.sortOrder).max() ?? -1
        tasks[idx].sortOrder = maxOrder + 1
        save()
    }

    func moveTaskToPosition(id: UUID, toLane lane: Lane, atIndex index: Int) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let tabId = tasks[taskIdx].tabId
        tasks[taskIdx].lane = lane
        var laneTasks = tasks
            .filter { task in
                task.tabId == tabId
                    && task.lane == lane
                    && task.id != id
                    && (showCompletedTasks || !task.isCompleted)
            }
            .sorted(by: displayOrder)
        let clamped = min(max(index, 0), laneTasks.count)
        laneTasks.insert(tasks[taskIdx], at: clamped)
        applySortOrder(laneTasks)
        save()
    }

    func moveTaskUp(_ taskId: UUID, inLane lane: Lane) {
        var laneTasks = tasksForLane(lane).filter { !$0.isCompleted }
        guard let idx = laneTasks.firstIndex(where: { $0.id == taskId }), idx > 0 else { return }
        laneTasks.swapAt(idx, idx - 1)
        applySortOrder(laneTasks)
        save()
    }

    func moveTaskDown(_ taskId: UUID, inLane lane: Lane) {
        var laneTasks = tasksForLane(lane).filter { !$0.isCompleted }
        guard let idx = laneTasks.firstIndex(where: { $0.id == taskId }), idx < laneTasks.count - 1 else { return }
        laneTasks.swapAt(idx, idx + 1)
        applySortOrder(laneTasks)
        save()
    }

    // MARK: - Tab CRUD

    func addTab(name: String) {
        guard tabs.count < 4 else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let maxOrder = tabs.map(\.sortOrder).max() ?? -1
        let tab = TiqTab(id: UUID(), name: trimmed, sortOrder: maxOrder + 1)
        tabs.append(tab)
        activeTabId = tab.id
        save()
    }

    func renameTab(_ tabId: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = tabs.firstIndex(where: { $0.id == tabId })
        else { return }
        tabs[idx].name = trimmed
        save()
    }

    func deleteTab(_ tabId: UUID) {
        guard tabs.count > 1 else { return }
        tasks.removeAll { $0.tabId == tabId }
        tabs.removeAll { $0.id == tabId }
        historyRecords.removeAll { $0.tabId == tabId }
        if activeTabId == tabId {
            activeTabId = tabs.first?.id ?? UUID()
        }
        save()
        saveHistory()
    }

    func setShowCompleted(_ show: Bool) {
        showCompletedTasks = show
        UserDefaults.standard.set(show, forKey: "tiqdo.showCompleted")
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "tiqdo.appearance")
        NotificationCenter.default.post(name: .tiqDoAppearanceChanged, object: nil)
    }

    func cycleTab() {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == activeTabId }) {
            let next = (idx + 1) % tabs.count
            activeTabId = tabs[next].id
        }
    }

    func clearCompleted() {
        tasks.removeAll { $0.tabId == activeTabId && $0.isCompleted }
        save()
    }

    var hasCompletedInActiveTab: Bool {
        tasks.contains { $0.tabId == activeTabId && $0.isCompleted }
    }

    func setHistoryMaxRecords(_ max: Int) {
        historyMaxRecords = max
        UserDefaults.standard.set(max, forKey: "tiqdo.historyMaxRecords")
        trimHistory()
        saveHistory()
    }

    func clearAllData() {
        persistence.clearAll()
        let defaultTab = TiqTab(id: UUID(), name: "Personal", sortOrder: 0)
        tabs = [defaultTab]
        tasks = []
        historyRecords = []
        activeTabId = defaultTab.id
        editingTaskId = nil
        saveImmediately()
    }

    func flushPendingSave() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        persistence.saveAndWait(tabs: tabs, tasks: tasks)
    }

    // MARK: - Private

    private func save() {
        pendingSaveWorkItem?.cancel()
        let tabsSnapshot = tabs
        let tasksSnapshot = tasks
        let workItem = DispatchWorkItem { [persistence] in
            persistence.save(tabs: tabsSnapshot, tasks: tasksSnapshot)
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: workItem)
    }

    private func saveImmediately() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        persistence.saveAndWait(tabs: tabs, tasks: tasks)
    }

    private func cleanupOldCompleted() {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let before = tasks.count
        tasks.removeAll { $0.isCompleted && ($0.completedAt ?? .distantPast) < cutoff }
        if tasks.count != before { save() }
    }

    private func startMaintenanceTimer() {
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.runPeriodicMaintenance()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        maintenanceTimer = timer
    }

    private func runPeriodicMaintenance() {
        relativeDateReference = Date()
        cleanupOldCompleted()
    }

    private func recordHistory(_ task: TiqTask) {
        let record = HistoryRecord(
            id: UUID(),
            title: task.title,
            completedAt: task.completedAt ?? Date(),
            tabId: task.tabId
        )
        historyRecords.insert(record, at: 0)
        trimHistory()
        saveHistory()
    }

    private func trimHistory() {
        if historyRecords.count > historyMaxRecords {
            historyRecords = Array(historyRecords.prefix(historyMaxRecords))
        }
    }

    private func saveHistory() {
        persistence.saveHistory(historyRecords)
    }

    private func displayOrder(_ lhs: TiqTask, _ rhs: TiqTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt < rhs.createdAt
    }

    private func applySortOrder(_ orderedTasks: [TiqTask]) {
        var indicesById: [UUID: Int] = [:]
        for idx in tasks.indices {
            indicesById[tasks[idx].id] = idx
        }
        for (order, task) in orderedTasks.enumerated() {
            if let idx = indicesById[task.id] {
                tasks[idx].sortOrder = order
            }
        }
    }

    private static func normalizedTabs(_ loadedTabs: [TiqTab]) -> [TiqTab] {
        let sortedTabs = loadedTabs.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        if sortedTabs.isEmpty {
            return [TiqTab(id: UUID(), name: "Personal", sortOrder: 0)]
        }
        return sortedTabs
    }
}
