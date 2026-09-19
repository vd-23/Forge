import SwiftUI

// Placeholder — the heatmap, streaks, weekly stats and recent PRs land in
// Checkpoint C, once ForgeCore can compute them.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing here yet", systemImage: "square.grid.3x3")
            } description: {
                Text("Your heatmap, streaks and recent records will appear here.")
            }
            .navigationTitle("Home")
        }
    }
}
