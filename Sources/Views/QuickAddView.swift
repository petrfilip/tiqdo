import SwiftUI

struct QuickAddView: View {
    @Environment(TaskStore.self) private var store
    let lane: Lane
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField(lane.placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .focused($isFocused)
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.addTask(title: text, lane: lane)
                    }
                    text = ""
                }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}
