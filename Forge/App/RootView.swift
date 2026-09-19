import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            RoutineListView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
