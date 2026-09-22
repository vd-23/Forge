import SwiftUI

struct RootView: View {
    @Environment(WorkoutController.self) private var controller
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    private enum Tab: Hashable { case progress, exercises, workout, history, settings }

    @State private var selectedTab: Tab = .progress
    @State private var workoutPath: [RoutineDestination] = []
    @State private var staleSession: WorkoutSession?
    @State private var showStalePrompt = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.progress)
            ExerciseLibraryView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }
                .tag(Tab.exercises)
            RoutineListView(path: $workoutPath)
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.workout)
            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(ForgeColor.accentFill)
        .onChange(of: selectedTab) { _, _ in Haptics.dock() }
        .tabViewBottomAccessory(isEnabled: controller.restTimer.endsAt != nil) {
            RestTimerBar(timer: controller.restTimer, onTap: openActiveWorkout)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            // The countdown only ticks while the bar is on screen; catch an
            // expiry that happened in the background before the bar reappears.
            controller.restTimer.expireIfNeeded()
            handleShortcut()
            ForgeShortcuts.updateAppShortcutParameters()
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

    /// A Shortcut asked for a workout. Start it, or land on the one already
    /// running — either way the user ends up on the logging screen.
    private func handleShortcut() {
        guard let routineID = ShortcutLauncher.takePending() else { return }
        switch ShortcutLauncher.start(routineID: routineID, controller: controller, context: context) {
        case .started, .resumedExisting:
            openActiveWorkout()
        case .notFound:
            Haptics.warning()
            selectedTab = .workout
        }
    }

    /// Jumps to the Workout tab and pushes the running session, so tapping the
    /// floating rest timer from anywhere lands back on the set you're resting
    /// between rather than just showing the countdown.
    private func openActiveWorkout() {
        guard let session = controller.activeSession else { return }
        Haptics.tap()
        selectedTab = .workout
        workoutPath = [.activeWorkout(session)]
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    return RootView()
        .modelContainer(container)
        .environment(WorkoutController(context: container.mainContext))
}
