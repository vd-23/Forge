import SwiftUI

struct RootView: View {
    @Environment(WorkoutController.self) private var controller

    @State private var staleSession: WorkoutSession?
    @State private var showStalePrompt = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            RoutineListView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
            ExerciseLibraryView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }
            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            // A recent active session is a workout in progress — leave it be.
            guard let active = controller.activeSession, StaleSessionCheck.isStale(active) else { return }
            staleSession = active
            showStalePrompt = true
        }
        .alert("Unfinished workout", isPresented: $showStalePrompt, presenting: staleSession) { session in
            Button("Finish it") { controller.finish(session) }
            Button("Discard", role: .destructive) { controller.discard(session) }
            Button("Leave it open", role: .cancel) {}
        } message: { session in
            Text("\"\(session.sourceRoutineName)\" has been running since \(session.startedAt.formatted(date: .abbreviated, time: .shortened)).")
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    return RootView()
        .modelContainer(container)
        .environment(WorkoutController(context: container.mainContext))
}
