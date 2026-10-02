import SwiftUI
import SwiftData

/// The workout in progress: one card per exercise, a rest countdown, and the
/// finish flow. Navigating back leaves the session running — it is recovered by
/// `WorkoutController` and resumed from the routine list.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    let controller: WorkoutController

    @State private var addingExercise = false
    @State private var editingExercise: Exercise?
    @State private var notingExercise: WorkoutExercise?
    @State private var noteDraft = ""
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var pendingRemoval: WorkoutExercise?
    @State private var summary: WorkoutSummary?
    /// What the workout looked like at Finish, captured before pruning, and
    /// how it differs from the routine — drives the "update routine?" offer.
    @State private var routinePlan: [RoutineSync.PlannedExercise] = []
    @State private var routineDiff: RoutineSync.Diff?
    /// The exercise whose set table is open. `nil` means "whichever is next":
    /// the first with an unticked set, so finishing one advances to the next.
    @State private var expandedID: PersistentIdentifier?

    /// Bound rather than read once, so switching units in Settings re-renders
    /// every weight field on this screen immediately.
    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    private var exercises: [WorkoutExercise] { session.orderedExercises }

    private var resolvedExpandedID: PersistentIdentifier? {
        if let expandedID, exercises.contains(where: { $0.persistentModelID == expandedID }) {
            return expandedID
        }
        let next = exercises.first { $0.sets.isEmpty || $0.sets.contains { !$0.isComplete } } ?? exercises.last
        return next?.persistentModelID
    }

    /// A `List` rather than a scroll view so cards get native drag-to-reorder
    /// (press and hold, then drag) and swipe actions.
    var body: some View {
        List {
            progressHeader
                .workoutRow(top: 8, bottom: 4)
                .moveDisabled(true)

            ForEach(exercises, id: \.persistentModelID) { workoutExercise in
                let isExpanded = workoutExercise.persistentModelID == resolvedExpandedID
                WorkoutExerciseCard(
                    workoutExercise: workoutExercise,
                    sessionID: session.id,
                    controller: controller,
                    unit: unit,
                    isExpanded: isExpanded,
                    onToggleExpanded: {
                        withAnimation(.snappy) {
                            expandedID = isExpanded ? nil : workoutExercise.persistentModelID
                        }
                    },
                    onSetCompleted: startRest(after:set:),
                    onEditNote: { editNote(workoutExercise) }
                )
                .workoutRow(top: 6, bottom: 6)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        Haptics.heavy()
                        pendingRemoval = workoutExercise
                    }
                    .tint(.red)
                    Button("Edit", systemImage: "pencil") {
                        Haptics.tap()
                        editingExercise = workoutExercise.exercise
                    }
                    .tint(.gray)
                }
                .swipeActions(edge: .leading) {
                    Button("Note", systemImage: "note.text") { editNote(workoutExercise) }
                        .tint(ForgeColor.accentFill)
                }
            }
            .onMove { source, destination in
                Haptics.selection()
                controller.moveExercises(in: session, from: source, to: destination)
            }

            Button("Add exercise", systemImage: "plus") { Haptics.tap(); addingExercise = true }
                .buttonStyle(GhostButtonStyle())
                .disabled(!controller.canAddExercise(to: session))
                .workoutRow(top: 10, bottom: 16)
                .moveDisabled(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .numericKeyboardDoneButton()
        .forgeBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(session.sourceRoutineName)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle().fill(ForgeColor.accent).frame(width: 5, height: 5)
                        Text(session.startedAt, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ForgeColor.accentInk)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Add exercise", systemImage: "plus") { Haptics.tap(); addingExercise = true }
                    Button("Discard workout", role: .destructive) { Haptics.warning(); confirmDiscard = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                Button("Finish") { Haptics.tap(); confirmFinish = true }
                    .fontWeight(.semibold)
                    .tint(ForgeColor.accentInk)
            }
        }
        .sheet(isPresented: $addingExercise) {
            NavigationStack {
                ExercisePickerView(onPick: { controller.addExercise($0, to: session) })
            }
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack { ExerciseEditorView(exercise: exercise) }
        }
        .alert(
            notingExercise?.exercise?.name ?? "Note",
            isPresented: Binding(get: { notingExercise != nil }, set: { if !$0 { notingExercise = nil } })
        ) {
            TextField("e.g. EZ bar attachment", text: $noteDraft)
            Button("Save") {
                if let notingExercise { controller.setNote(noteDraft, for: notingExercise) }
                Haptics.success()
                notingExercise = nil
            }
            Button("Cancel", role: .cancel) { notingExercise = nil }
        } message: {
            Text(session.sourceRoutine == nil
                 ? "Shown on this exercise during the workout."
                 : "Saved to \(session.sourceRoutineName) and shown every time you do it.")
        }
        .sheet(item: $summary) { summary in
            WorkoutSummaryView(
                summary: summary,
                routineDiff: routineDiff,
                routineName: session.sourceRoutine?.name,
                onUpdateRoutine: routineDiff == nil ? nil : {
                    guard let routine = session.sourceRoutine else { return }
                    Haptics.success()
                    controller.updateRoutine(routine, toMatch: routinePlan)
                }
            ) {
                self.summary = nil
                dismiss()
            }
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.exercise?.name ?? "exercise")?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { workoutExercise in
            Button("Remove", role: .destructive) {
                Haptics.heavy()
                controller.removeExercise(workoutExercise)
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: { workoutExercise in
            let done = workoutExercise.sets.filter(\.isComplete).count
            Text(done > 0 ? "^[\(done) logged set](inflect: true) will be deleted with it." : "It'll be dropped from this workout only.")
        }
        .alert("Finish this workout?", isPresented: $confirmFinish) {
            Button("Finish", action: finish)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sets you haven't ticked off won't be saved.")
        }
        .alert("Discard this workout?", isPresented: $confirmDiscard) {
            Button("Discard", role: .destructive) {
                // Pop first: the session is the value backing this entry in the
                // navigation stack, so deleting it while the view is still
                // mounted would leave the stack holding an invalidated model.
                dismiss()
                Task { controller.discard(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything logged in this session will be deleted.")
        }
    }

    // MARK: Progress

    private var progressHeader: some View {
        let total = exercises.reduce(0) { $0 + $1.sets.count }
        let done = exercises.reduce(0) { $0 + $1.sets.filter(\.isComplete).count }
        let index = exercises.firstIndex { $0.persistentModelID == resolvedExpandedID } ?? 0

        return VStack(spacing: 8) {
            HStack {
                SectionLabel(exercises.isEmpty ? "No exercises" : "Exercise \(index + 1) of \(exercises.count)")
                Spacer()
                Text("\(done) / \(total) sets")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ForgeColor.ink2)
            }
            SegmentedProgress(segments: exercises.map { exercise in
                guard !exercise.sets.isEmpty else { return 0 }
                return Double(exercise.sets.filter(\.isComplete).count) / Double(exercise.sets.count)
            })
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    // MARK: Actions

    private func editNote(_ workoutExercise: WorkoutExercise) {
        Haptics.tap()
        noteDraft = workoutExercise.note ?? ""
        notingExercise = workoutExercise
    }

    private func startRest(after workoutExercise: WorkoutExercise, set: ExerciseSet) {
        let remaining = workoutExercise.orderedSets.filter { !$0.isComplete }
        let note: String
        if let next = remaining.first,
           let label = SetNumbering.number(workoutExercise.orderedSets).first(where: { $0.exerciseSet === next })?.label {
            note = "next: set \(label)"
        } else if let nextExercise = exercises.first(where: { $0.order > workoutExercise.order && $0.sets.contains { !$0.isComplete } }) {
            note = "next: \(nextExercise.exercise?.name ?? "next exercise")"
            // The card just finished; let the next one open.
            expandedID = nil
        } else {
            note = "last set done"
        }
        controller.restTimer.start(
            seconds: workoutExercise.restSeconds ?? Preferences.defaultRestSeconds,
            note: note
        )
    }

    /// A workout with nothing ticked off is discarded rather than summarised,
    /// so it never becomes an empty row in history.
    private func finish() {
        let plan = RoutineSync.plan(from: session)
        let diff = RoutineSync.diff(plan: plan, against: session.sourceRoutine)
        if let finished = controller.finish(session) {
            Haptics.success()
            routinePlan = plan
            routineDiff = diff
            summary = finished
        } else {
            Haptics.warning()
            dismiss()
        }
    }
}

private extension View {
    /// A full-width list row with no chrome, so cards sit on the background.
    func workoutRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
