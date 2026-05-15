import SwiftUI

struct TabBarView: View {
    @Environment(TaskStore.self) private var store
    @State private var renamingTabId: UUID?
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var tabToDelete: UUID?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(store.tabs) { tab in
                tabButton(for: tab)
            }

            if store.tabs.count < 4 {
                Button { store.addTab(name: "New") } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .alert("Delete Tab", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { tabToDelete = nil }
            Button("Delete", role: .destructive) {
                if let id = tabToDelete { store.deleteTab(id); tabToDelete = nil }
            }
        } message: {
            if let id = tabToDelete, let tab = store.tabs.first(where: { $0.id == id }) {
                Text("Delete \"\(tab.name)\" and all its tasks?")
            }
        }
    }

    @ViewBuilder
    private func tabButton(for tab: TiqTab) -> some View {
        let isActive = tab.id == store.activeTabId

        if renamingTabId == tab.id {
            TextField("", text: $renameText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { store.renameTab(tab.id, to: renameText); renamingTabId = nil }
                .onExitCommand { renamingTabId = nil }
        } else {
            Button { store.activeTabId = tab.id } label: {
                HStack(spacing: 3) {
                    Text(tab.name)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .primary : .secondary)
                    Text("\(store.taskCount(for: tab.id))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isActive ? .secondary : .tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? .primary.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename") { renameText = tab.name; renamingTabId = tab.id }
                if store.tabs.count > 1 {
                    Divider()
                    Button("Delete", role: .destructive) { tabToDelete = tab.id; showDeleteConfirm = true }
                }
            }
        }
    }
}
