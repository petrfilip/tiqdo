import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(TaskStore.self) private var store
    @Binding var isPresented: Bool
    @State private var showClearConfirm = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { isPresented = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 16, height: 16)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader("GENERAL")

                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 12))
                        .onChange(of: launchAtLogin) { _, v in toggleLogin(v) }

                    Toggle("Show completed tasks", isOn: Binding(
                        get: { store.showCompletedTasks },
                        set: { store.setShowCompleted($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.system(size: 12))

                    Divider()

                    sectionHeader("APPEARANCE")

                    Picker("Theme", selection: Binding(
                        get: { store.appearanceMode },
                        set: { store.setAppearance($0) }
                    )) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    sectionHeader("HISTORY")

                    HStack {
                        Text("Max records")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { store.historyMaxRecords },
                            set: { store.setHistoryMaxRecords($0) }
                        )) {
                            Text("1 000").tag(1000)
                            Text("2 000").tag(2000)
                            Text("5 000").tag(5000)
                            Text("10 000").tag(10000)
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    Divider()

                    sectionHeader("DATA")

                    Button("Clear all data") { showClearConfirm = true }
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .buttonStyle(.plain)
                        .alert("Clear All Data", isPresented: $showClearConfirm) {
                            Button("Cancel", role: .cancel) {}
                            Button("Clear", role: .destructive) { store.clearAllData() }
                        } message: {
                            Text("This will delete all tabs, tasks, and history.")
                        }

                    Divider()

                    sectionHeader("ABOUT")

                    Text("Tiqdo v1.0.0")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Shortcut: Ctrl+Q  ·  Switch tabs: Ctrl+Tab")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Link(destination: URL(string: "https://github.com/petrfilip/Tiqdo")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("GitHub")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.tertiary)
            .tracking(1.2)
    }

    private func toggleLogin(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
