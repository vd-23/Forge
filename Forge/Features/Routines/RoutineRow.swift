import SwiftUI

struct RoutineRow: View {
    let routine: Routine
    let onStart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text("^[\(routine.orderedItems.count) exercise](inflect: true)")
                    Text("·")
                    RelativeDateText(date: routine.lastPerformedAt)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
    }
}
