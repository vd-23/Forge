import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Text("Workout")
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
            Text("History")
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
}
