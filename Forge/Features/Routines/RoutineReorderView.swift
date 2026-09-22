import SwiftUI
import SwiftData

/// Drag-to-reorder for the Workout tab grid. A plain `List` in edit mode,
/// because a grid can't host drag handles.
struct RoutineReorderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let routines: [Routine]

    var body: some View {
        List {
            ForEach(RoutineOrdering.ordered(routines)) { routine in
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name)
                        .font(.body)
                        .foregroundStyle(ForgeColor.ink)
                    Text("^[\(routine.orderedItems.count) exercise](inflect: true)")
                        .font(ForgeType.meta)
                        .foregroundStyle(ForgeColor.ink3)
                }
            }
            .onMove { source, destination in
                Haptics.selection()
                RoutineOrdering.move(routines, from: source, to: destination)
                try? context.save()
            }
            .listRowBackground(ForgeColor.surface)
        }
        .environment(\.editMode, .constant(.active))
        .forgeForm()
        .navigationTitle("Reorder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { Haptics.tap(); dismiss() }
            }
        }
    }
}
