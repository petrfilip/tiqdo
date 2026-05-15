import SwiftUI

struct HistoryView: View {
    @Environment(TaskStore.self) private var store
    @Binding var isPresented: Bool
    @State private var displayLimit = 100

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            let groups = dayGroups
            if groups.isEmpty {
                Spacer()
                Text("No completed tasks yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.records) { record in
                                    recordRow(record)
                                }
                            } header: {
                                sectionHeader(group.label)
                            }
                        }

                        if hasMoreRecords {
                            Color.clear
                                .frame(height: 1)
                                .onAppear { displayLimit += 100 }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("History")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.tertiary)
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        HStack {
            Text(record.title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(Self.timeFormatter.string(from: record.completedAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

    // MARK: - Data

    private var filteredRecords: [HistoryRecord] {
        store.historyRecords.filter { $0.tabId == store.activeTabId }
    }

    private var hasMoreRecords: Bool {
        filteredRecords.count > displayLimit
    }

    private var dayGroups: [DayGroup] {
        let limited = filteredRecords.prefix(displayLimit)
        let calendar = Calendar.current
        var grouped: [Date: [HistoryRecord]] = [:]

        for record in limited {
            let day = calendar.startOfDay(for: record.completedAt)
            grouped[day, default: []].append(record)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { day, records in
                DayGroup(
                    id: day,
                    label: Self.dayLabel(for: day),
                    records: records.sorted { $0.completedAt > $1.completedAt }
                )
            }
    }

    private static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return dateFormatter.string(from: date)
    }
}

private struct DayGroup: Identifiable {
    let id: Date
    let label: String
    let records: [HistoryRecord]
}
