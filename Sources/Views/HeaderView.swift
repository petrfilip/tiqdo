import SwiftUI

struct HeaderView: View {
    @Environment(TaskStore.self) private var store
    @Binding var showSettings: Bool
    @Binding var showHistory: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("Tiqdo")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)

            Text("\(store.activeTaskCount)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.primary.opacity(0.08)))

            Spacer()

            if store.hasCompletedInActiveTab {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.clearCompleted()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear completed tasks")
            }

            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("History")

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}
