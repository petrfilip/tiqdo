import SwiftUI

struct PopoverView: View {
    @Environment(TaskStore.self) private var store
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
            } else if showHistory {
                HistoryView(isPresented: $showHistory)
            } else {
                HeaderView(showSettings: $showSettings, showHistory: $showHistory)
                TabBarView()
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Lane.allCases, id: \.self) { lane in
                            LaneView(lane: lane)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                FooterView()
            }
        }
        .frame(minWidth: 280, maxWidth: 500, minHeight: 320, maxHeight: 800)
        .background(background)
        .preferredColorScheme(store.appearanceMode.colorScheme)
    }

    private var background: Color {
        if store.appearanceMode == .dark {
            return Theme.customDark
        }
        return Color(nsColor: .windowBackgroundColor)
    }
}
