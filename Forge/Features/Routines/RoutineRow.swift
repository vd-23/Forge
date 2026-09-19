import SwiftUI

struct RoutineRow: View {
    let routine: Routine
    var isArchived: Bool = false
    /// `nil` for an archived routine — it has to be restored before it can run.
    let onStart: (() -> Void)?

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

            if let onStart {
                Button("Start", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            } else {
                Text("Archived")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: .capsule)
            }
        }
        .opacity(isArchived ? 0.6 : 1)
    }
}
