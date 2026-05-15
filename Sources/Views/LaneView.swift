import SwiftUI

struct LaneView: View {
    @Environment(TaskStore.self) private var store
    let lane: Lane
    @State private var dropTargetIndex: Int?

    var body: some View {
        let tasks = store.tasksForLane(lane)

        VStack(alignment: .leading, spacing: 2) {
            laneHeader

            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRowView(task: task, lane: lane)
                    .overlay(alignment: .top) {
                        if dropTargetIndex == index {
                            dropLine.offset(y: -4)
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let idString = items.first,
                              let draggedId = UUID(uuidString: idString),
                              draggedId != task.id
                        else {
                            withAnimation(.easeInOut(duration: 0.15)) { dropTargetIndex = nil }
                            return false
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            dropTargetIndex = nil
                            store.moveTaskToPosition(id: draggedId, toLane: lane, atIndex: index)
                        }
                        return true
                    } isTargeted: { targeted in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if targeted {
                                dropTargetIndex = index
                            } else if dropTargetIndex == index {
                                dropTargetIndex = nil
                            }
                        }
                    }
            }

            QuickAddView(lane: lane)
                .overlay(alignment: .top) {
                    if dropTargetIndex == tasks.count {
                        dropLine.offset(y: -4)
                    }
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let idString = items.first,
                          let draggedId = UUID(uuidString: idString)
                    else {
                        withAnimation(.easeInOut(duration: 0.15)) { dropTargetIndex = nil }
                        return false
                    }
                    let count = tasks.count
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dropTargetIndex = nil
                        store.moveTaskToPosition(id: draggedId, toLane: lane, atIndex: count)
                    }
                    return true
                } isTargeted: { targeted in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        let count = tasks.count
                        if targeted {
                            dropTargetIndex = count
                        } else if dropTargetIndex == count {
                            dropTargetIndex = nil
                        }
                    }
                }
        }
        .animation(.easeInOut(duration: 0.25), value: tasks.map(\.id))
        .padding(6)
    }

    private var dropLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(lane.badgeColor)
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(lane.badgeColor)
                .frame(height: 2)
        }
        .padding(.horizontal, 4)
        .transition(.identity)
    }

    private var laneHeader: some View {
        HStack(spacing: 6) {
            Text(lane.displayName)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(lane.badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(lane.badgeColor.opacity(0.15))
                )

            Text("\(store.incompleteCount(for: lane))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            VStack { Divider() }
        }
        .padding(.bottom, 2)
    }
}

extension Lane {
    var badgeColor: Color {
        switch self {
        case .now: return Color(red: 0.85, green: 0.7, blue: 0.3)
        case .nxt: return Color(red: 0.45, green: 0.45, blue: 0.85)
        case .ltr: return Color(red: 0.6, green: 0.4, blue: 0.75)
        }
    }
}
