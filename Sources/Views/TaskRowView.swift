import SwiftUI

struct TaskRowView: View {
    @Environment(TaskStore.self) private var store
    let task: TiqTask
    let lane: Lane

    @State private var editText = ""
    @State private var isHovered = false
    @State private var clickPoint: NSPoint = .zero

    private var isEditing: Bool { store.editingTaskId == task.id }

    var body: some View {
        HStack(spacing: 8) {
            checkmark

            if isEditing {
                InlineTextField(text: $editText, clickScreenPoint: clickPoint, onCommit: {
                    commitEdit()
                }, onCancel: {
                    store.editingTaskId = nil
                })
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    editText = task.title
                }
            } else {
                Text(task.title)
                    .font(.system(size: 13))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .tertiary : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        clickPoint = NSEvent.mouseLocation
                        beginEdit()
                    }
            }

            if task.isCompleted, let completedAt = task.completedAt {
                Text(store.relativeString(for: completedAt))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(.primary.opacity(0.04)))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(.primary.opacity(isHovered ? 0.04 : 0))
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit") { beginEdit() }
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    store.toggleComplete(task.id)
                }
            }
            Divider()
            if task.lane != .now {
                Button("Move to NOW") { withAnimation { store.moveTask(id: task.id, toLane: .now) } }
            }
            if task.lane != .nxt {
                Button("Move to NXT") { withAnimation { store.moveTask(id: task.id, toLane: .nxt) } }
            }
            if task.lane != .ltr {
                Button("Move to LTR") { withAnimation { store.moveTask(id: task.id, toLane: .ltr) } }
            }
            Divider()
            Button("Move Up") { withAnimation { store.moveTaskUp(task.id, inLane: lane) } }
                .disabled(task.isCompleted)
            Button("Move Down") { withAnimation { store.moveTaskDown(task.id, inLane: lane) } }
                .disabled(task.isCompleted)
            Divider()
            Button("Delete", role: .destructive) { withAnimation { store.deleteTask(task.id) } }
        }
    }

    private func beginEdit() {
        editText = task.title
        store.editingTaskId = task.id
    }

    private func commitEdit() {
        guard isEditing else { return }
        store.updateTask(task.id, title: editText)
        store.editingTaskId = nil
    }

    private var checkmark: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                store.toggleComplete(task.id)
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        task.isCompleted ? Color.green.opacity(0.6) : .secondary.opacity(0.4),
                        lineWidth: 1.2
                    )
                    .frame(width: 14, height: 14)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(task.id.uuidString) {
            HStack(spacing: 6) {
                Circle()
                    .strokeBorder(.secondary.opacity(0.5), lineWidth: 1)
                    .frame(width: 12, height: 12)
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }
}
