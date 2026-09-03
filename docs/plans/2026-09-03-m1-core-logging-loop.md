# Forge M1 — Core Logging Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Tasks use `- [ ]` checkboxes.

**Goal:** A usable personal gym logger — create custom exercises, build routines, run a workout logging sets (with a "last time" reference and a rest timer), finish with a summary, browse history.

**Architecture:** SwiftUI + SwiftData iPhone app. One `ModelContainer` in an App Group container (so the M3 widget shares it with no migration). All non-trivial math lives in `ForgeCore`, a dependency-free local Swift package tested with `swift test`. App-layer logic (workout state machine, model⇄core mapping, seeding, formatting) is tested with `xcodebuild test` against an in-memory container. The `.xcodeproj` is generated from `project.yml` by XcodeGen.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Observation, UserNotifications, Swift Testing, XcodeGen.

**Spec:** [`docs/PRD.md`](../PRD.md) — this plan implements **Milestone 1** only.

## Global Constraints

- iOS deployment target `26.0`. Toolchain Xcode 26.6 / Swift 6.3. Test simulator: `iPhone 17` (iOS 26.5 runtime).
- No personal name in any identifier: bundle `com.forge.gym`, App Group `group.com.forge.gym`, package `ForgeCore`.
- `ForgeCore` imports only `Foundation` — never SwiftData / SwiftUI / Observation. Its tests pass under a bare `swift test`.
- All loads stored in **kilograms**. kg/lb is display + input only, handled in the app layer.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`). No XCTest.
- One primary type per file. No force-unwrap except the documented `ModelContainer` bootstrap. Doc comments on every `public` `ForgeCore` symbol. 4-space indent.
- Commit after every task (Conventional Commits). No external runtime dependencies; XcodeGen is build-time only.
- Simulator builds need no signing. Device runs need the user's personal team selected in Xcode — never commit a team ID.

## How every task works

- **ForgeCore tasks:** write the Swift Testing cases first, `cd Packages/ForgeCore && swift test` (red), implement, `swift test` (green), commit.
- **App tasks:** write logic tests first where the deliverable has testable logic; `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` (red → green). Build with `xcodebuild build …`. Verify screens with `#Preview` + a Simulator run. Commit.
- Regenerate the project with `xcodegen` whenever files or targets are added.

---

## File structure

```
project.yml, Brewfile, .gitignore                 # Forge.xcodeproj is git-ignored

Packages/ForgeCore/
  Package.swift
  Sources/ForgeCore/
    Inputs.swift          # ExerciseInput, SetInput, WorkoutExerciseInput, SessionInput
    OneRepMax.swift       # estimatedOneRepMax
    Volume.swift          # workingSets, setVolumeKg, sessionVolumeKg
    Progression.swift     # sessionBestE1RM
    PersonalRecords.swift # PRSet, personalRecords, PRKind, PRHit, newPersonalRecords
  Tests/ForgeCoreTests/   # one file per source file

Forge/
  App/            ForgeApp.swift, RootView.swift, PersistenceController.swift
  Models/         BodyPart, WeightUnit, Exercise, Routine, RoutineItem,
                  WorkoutSession, WorkoutExercise, ExerciseSet, Schema.swift
  Persistence/    ModelMapping.swift, SeedData.swift
  Preferences/    Preferences.swift, WeightFormatting.swift
  Features/
    ExerciseLibrary/  ExerciseLibraryView, ExerciseEditorView, ExerciseDeletion
    Routines/         RoutineListView, RoutineRow, RoutineDetailView,
                      RoutineEditorView, RoutineItemEditorView,
                      ExercisePickerView, RoutineDuplication
    Workout/          WorkoutController, ActiveWorkoutView, WorkoutExerciseCard,
                      SetEntryRow, LastPerformance, RestTimer, RestTimerBar,
                      WorkoutSummary, WorkoutSummaryView, StaleSessionCheck
    History/          HistoryListView, SessionDetailView, MonthGrouping
  Settings/       SettingsView.swift
  Shared/         RepRange.swift, RelativeDateText.swift

ForgeTests/       # xcodebuild test target — logic only, no UI tests
```

---

## Data model (the contract — build exactly this)

### Enums

```swift
enum BodyPart: String, CaseIterable, Codable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, core
    case quads, hamstrings, glutes, calves, traps
    case cardio, fullBody, other
    var id: String { rawValue }
    var displayName: String { self == .fullBody ? "Full Body" : rawValue.capitalized }
}

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case kg, lb
    var id: String { rawValue }
}
```

Enum-typed model fields are stored as a backing `…Raw: String` property with a computed accessor (predicate-friendly, trivial migration).

### `@Model` classes

Each of `Exercise` / `Routine` / `WorkoutSession` carries `@Attribute(.unique) var id: UUID = UUID()` (used by predicates and `navigationDestination(item:)`; `@Model` already gives `Identifiable` via `persistentModelID` but an explicit UUID is stable across contexts).

**`Exercise`** — `id`, `name: String`, `primaryBodyPartRaw: String` (+ `primaryBodyPart` accessor), `isBodyweight: Bool`, `isUnilateral: Bool`, `defaultRestSeconds: Int?`, `isArchived: Bool`, `createdAt: Date`. Inverse `@Relationship(deleteRule: .nullify) routineItems: [RoutineItem]`.
Init: `(name:primaryBodyPart:isBodyweight:isUnilateral:defaultRestSeconds:)`, defaults for all but the first two.

**`Routine`** — `id`, `name: String`, `isArchived: Bool`, `createdAt: Date`, `lastPerformedAt: Date?`. `@Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine) items: [RoutineItem]`. Computed `orderedItems` (sorted by `order`).
Init: `(name:)`.

**`RoutineItem`** — `routine: Routine?`, `exercise: Exercise?`, `order: Int`, `targetSets: Int?`, `targetRepMin: Int?`, `targetRepMax: Int?`, `targetRestSeconds: Int?`.
Init: `(exercise:order:targetSets:targetRepMin:targetRepMax:targetRestSeconds:)`.

**`WorkoutSession`** — `id`, `startedAt: Date`, `endedAt: Date?`, `notes: String?`, `sourceRoutine: Routine?`, `sourceRoutineName: String`. `@Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session) exercises: [WorkoutExercise]`. Computed `isActive` (`endedAt == nil`), `orderedExercises`.
Init: `(startedAt:sourceRoutine:sourceRoutineName:)`.

**`WorkoutExercise`** — sits between session and sets so a planned exercise exists before any set is logged, targets are snapshotted, and a mid-workout crash loses nothing. Fields: `session: WorkoutSession?`, `exercise: Exercise?` (one-way ref — no inverse collection on `Exercise`; history queries use `exerciseID` instead), `exerciseID: UUID` (denormalised `exercise.id`), `order: Int`, `targetSets/targetRepMin/targetRepMax: Int?`, `restSeconds: Int?`. `@Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise) sets: [ExerciseSet]`. Computed `orderedSets`.
Init: `(exercise:exerciseID:order:targetSets:targetRepMin:targetRepMax:restSeconds:)`.

**`ExerciseSet`** — `workoutExercise: WorkoutExercise?`, `order: Int`, `weightKg: Double?` (nil for pure bodyweight), `addedWeightKg: Double?` (belt/vest load), `reps: Int` (per-side for unilateral), `rpe: Double?` (6.0–10.0, 0.5 steps), `isWarmup: Bool`, `isComplete: Bool` (default false), `completedAt: Date?`.
Init: `(order:weightKg:addedWeightKg:reps:rpe:isWarmup:)`.

`Forge/Models/Schema.swift`: `let forgeSchemaModels: [any PersistentModel.Type] = [Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self]`.

### Deletion & archival

- Exercises and routines are **archived, not deleted**, while referenced by any routine item or workout exercise. Hard delete only when unreferenced.
- Deleting a routine leaves past sessions intact (`sourceRoutineName` snapshot).
- Deleting a session cascades to its workout-exercises and sets.

---

## ForgeCore API (exact signatures + behaviour)

All types `public`, `Sendable`, `Codable`, `Equatable`. `PRKind` also `Hashable`.

```swift
struct ExerciseInput   { let id: UUID; let isBodyweight: Bool; let isUnilateral: Bool }
struct SetInput        { let weightKg: Double?; let addedWeightKg: Double?; let reps: Int
                         let rpe: Double?; let isWarmup: Bool; let isComplete: Bool }
struct WorkoutExerciseInput { let exercise: ExerciseInput; let sets: [SetInput] }
struct SessionInput    { let id: UUID; let startedAt: Date; let endedAt: Date?
                         let exercises: [WorkoutExerciseInput]
                         var isFinished: Bool { endedAt != nil } }

func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double
// Epley: weightKg * (1 + reps/30). reps == 1 → weightKg. weightKg<=0 or reps<=0 → 0.

func workingSets(_ sets: [SetInput]) -> [SetInput]
// keeps only isComplete && !isWarmup

func setVolumeKg(_ set: SetInput, exercise: ExerciseInput) -> Double
// bodyweight → 0; nil weightKg → 0; unilateral → weight*reps*2; else weight*reps

func sessionVolumeKg(_ session: SessionInput) -> Double
// sum of setVolumeKg over workingSets of every exercise

func sessionBestE1RM(_ session: SessionInput, exerciseID: UUID) -> Double?
// max Epley over that exercise's working sets; nil if none

struct PRSet { let maxWeightKg: Double?; let maxReps: Int?; let bestE1RM: Double? }
func personalRecords(_ sessions: [SessionInput], exerciseID: UUID) -> PRSet
// over FINISHED sessions only, working sets only; any field nil if no data

enum PRKind { case weight, reps, e1rm }
struct PRHit { let exerciseID: UUID; let kind: PRKind; let value: Double }
func newPersonalRecords(in session: SessionInput, history: [SessionInput]) -> [PRHit]
// records in `session` that strictly beat everything in `history`.
// history MUST exclude `session`. No history → every category with a working set is a hit.
```

**Edge cases the tests must cover:** 1-rep vs multi-rep 1RM, zero/negative reps, unilateral doubling, bodyweight = 0 volume, warmup + incomplete filtering, unfinished sessions excluded from PRs, tied value is *not* a new PR, empty history.

---

## Tasks

### Task 1: Project scaffold
- **Create:** `Brewfile` (`brew "xcodegen"`), `project.yml`, `Packages/ForgeCore/Package.swift` (tools 6.0, platforms iOS 17 / macOS 14, language mode v6, no deps), `Forge/Forge.entitlements` (App Group `group.com.forge.gym`), `Forge/Info.plist`, `Forge/App/ForgeApp.swift` (`@main`), `Forge/App/RootView.swift` (empty `TabView` with Workout/History/Settings `Text` placeholders), one placeholder test in each of `ForgeCoreTests` and `ForgeTests`.
- **`project.yml`:** app target `Forge` (bundle `com.forge.gym`, deployment 26.0, `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, `SWIFT_STRICT_CONCURRENCY: complete`, `DEVELOPMENT_TEAM: ""`, package dep on `ForgeCore`); unit-test target `ForgeTests` depending on `Forge`; scheme `Forge` running `ForgeTests` on test.
- **Verify:** `brew bundle` → `xcodegen generate` → `swift test` in the package → `xcodebuild build` → `xcodebuild test`. All green.
- **Commit:** `chore: scaffold Xcode project, ForgeCore package, test targets`

### Task 2: ForgeCore — inputs + `estimatedOneRepMax`
- **Create:** `Inputs.swift` (the four value types above, memberwise `public init`s with sensible defaults), `OneRepMax.swift`. Delete the placeholder.
- **Tests (`OneRepMaxTests`):** `reps == 1` → weight; `100 × 5 → 116.667 ± 0.001`; `reps <= 0 → 0`; `weight 0 → 0`.
- **Commit:** `feat: ForgeCore value types and estimated 1RM`

### Task 3: ForgeCore — working sets + volume
- **Create:** `Volume.swift` (`workingSets`, `setVolumeKg`, `sessionVolumeKg`).
- **Tests (`VolumeTests`):** standard `100×5 → 500`; unilateral `20×10 → 400`; bodyweight → 0; nil weight non-bodyweight → 0; `workingSets` drops warmup + incomplete; a mixed session sums to the expected total.
- **Commit:** `feat: ForgeCore working-set filter and volume math`

### Task 4: ForgeCore — session 1RM + personal records
- **Create:** `Progression.swift` (`sessionBestE1RM`), `PersonalRecords.swift` (`PRSet`, `personalRecords`, `PRKind`, `PRHit`, `newPersonalRecords`).
- **Implementation notes:** `personalRecords` filters `sessions.filter(\.isFinished)` then flattens working sets for the exercise. `newPersonalRecords` compares this session's best weight / reps / `sessionBestE1RM` against `personalRecords(history, …)` with strict `>` and `?? 0` fallback.
- **Tests:** `sessionBestE1RM` picks the max estimate over working sets, nil when none; `personalRecords` aggregates max weight/reps/e1RM over finished sessions, ignores warmups + unfinished; `newPersonalRecords` returns only strictly-beaten categories, all three when history is empty.
- **Commit:** `feat: ForgeCore session 1RM and personal-record detection`

### Task 5: SwiftData models
- **Create:** all files under `Forge/Models/` per the data-model section, plus `Schema.swift`.
- **Verify:** `xcodegen generate && xcodebuild build`. (Tested in Task 6.)
- **Commit:** `feat: SwiftData models and enums for the M1 schema`

### Task 6: Persistence controller
- **Create:** `Forge/App/PersistenceController.swift` — `enum PersistenceController` with `static let appGroupID = "group.com.forge.gym"`, `makeSharedContainer() -> ModelContainer` (store at `containerURL(forSecurityApplicationGroupIdentifier:)`.appending("Forge.store"); `fatalError` only on missing App Group or unopenable schema, both documented), `makeInMemoryContainer() -> ModelContainer` (`isStoredInMemoryOnly`). Wire `.modelContainer(makeSharedContainer())` into `ForgeApp`.
- **Tests (`PersistenceControllerTests`, `@MainActor`):** in-memory insert + fetch of an `Exercise` round-trips `primaryBodyPart`; deleting a `WorkoutSession` cascades to its `WorkoutExercise`s and `ExerciseSet`s while the `Exercise` survives.
- **Verify:** also launch in the Simulator once — confirm no `fatalError` (if the App Group is unprovisioned on the free tier, open in Xcode once so automatic signing adds it).
- **Commit:** `feat: App Group and in-memory SwiftData containers`

### Task 7: Model ⇄ ForgeCore mapping
- **Create:** `Forge/Persistence/ModelMapping.swift` — `var coreInput` on `Exercise`, `ExerciseSet`, `WorkoutExercise` (uses `orderedSets`; falls back to a plain non-bodyweight `ExerciseInput(id: exerciseID, …)` if `exercise` is nil), `WorkoutSession` (uses `orderedExercises`, maps `id` straight through).
- **Tests (`ModelMappingTests`, `@MainActor`):** build a session with sets inserted out of `order`; assert `coreInput` reorders them, preserves `isWarmup`, carries `exercise.id`, and that `sessionVolumeKg` on the result counts only the working set.
- **Commit:** `feat: map SwiftData models to ForgeCore inputs`

### Task 8: Seed exercise catalogue
- **Create:** `Forge/Persistence/SeedData.swift` — `struct SeedExercise { name; bodyPart; isBodyweight; isUnilateral }` + `let seedExercises: [SeedExercise]` transcribed from **PRD Appendix A** (40 entries; do not re-type the list here — copy from the PRD). Add `PersistenceController.seedIfEmpty(_ context:)` inserting the catalogue only when `fetchCount(Exercise) == 0`. Call it from `ForgeApp`'s root `.task`.
- **Tests (`SeedDataTests`, `@MainActor`):** fresh store seeds `seedExercises.count` rows, includes "Barbell Bench Press", flags "Pull-up" bodyweight and "Bulgarian Split Squat" unilateral; second `seedIfEmpty` is a no-op.
- **Commit:** `feat: seed the starter exercise catalogue on first launch`

### Task 9: App shell — tabs, preferences, formatting
- **Create:**
  - `Preferences/Preferences.swift` — `enum Preferences` over `UserDefaults(suiteName: appGroupID)`: `weightUnit: WeightUnit` (default `.kg`), `defaultRestSeconds: Int` (default 120).
  - `Preferences/WeightFormatting.swift` — `display(_ kg:unit:fractionDigits:) -> String` (`"100 kg"`, `"220.5 lb"`, no trailing zeros), `kilograms(from:unit:) -> Double` (lb → kg for storage), `editableValue(_ kg:unit:) -> Double` (kg → user's unit for editing). `kgPerLb = 0.45359237`.
  - `Shared/RelativeDateText.swift` — `"Today"` / `"2 days ago"` / `"Never"`.
  - `Settings/SettingsView.swift` — Form: weight-unit picker, default-rest stepper (both persist via `Preferences` on change), `NavigationLink` to `ExerciseLibraryView`, an About section with the "don't delete the app / ⌘R" note.
  - `RootView` → 3 tabs: `RoutineListView`, `HistoryListView`, `SettingsView`.
- **PRD refinement:** M1 ships 3 tabs; Progress + Dashboard arrive in M2.
- **Tests (`WeightFormattingTests`):** kg display trims zeros; `100 kg → "220.5 lb"`; `225 lb → 102.058 kg ± 0.001`; editable value round-trips within a unit.
- **Stubs (build now, replaced later):** `RoutineListView` (Task 11), `HistoryListView` (Task 18), `ExerciseLibraryView` (Task 10) — one-line `Text(...)` placeholders, noted in the commit.
- **Commit:** `feat: app shell, App Group preferences, weight formatting`

### Task 10: Exercise library
- **Create:**
  - `Features/ExerciseLibrary/ExerciseDeletion.swift` — `canHardDelete(_ exercise:) -> Bool`: `routineItems.isEmpty && fetchCount(WorkoutExercise where exerciseID == id) == 0`.
  - `ExerciseEditorView(exercise: Exercise?)` — Form (name, body-part picker, bodyweight toggle, unilateral toggle, optional custom-rest stepper). `nil` → insert new on save; else mutate. Save disabled on blank name.
  - `ExerciseLibraryView` — `@Query` non-archived, grouped by body part, `.searchable`. Row tap → edit sheet; toolbar `＋` → create sheet. Swipe: **Archive** (set `isArchived`); **Delete** → `canHardDelete` ? delete : alert "archive it instead".
- Point `SettingsView`'s link at the real `ExerciseLibraryView`.
- **Tests (`ExerciseDeletionTests`, `@MainActor`):** unreferenced → deletable; referenced by a routine item → not; referenced by a workout exercise → not.
- **Verify (Simulator):** seeded list grouped correctly; add / edit / archive; delete an unreferenced exercise.
- **Commit:** `feat: exercise library list and editor`

### Task 11: Routine list — duplicate, delete/archive
- **Create:**
  - `Features/Routines/RoutineDuplication.swift` — `duplicate(_ routine:into context:) -> Routine`: new `Routine` named `"<name> Copy"`, `lastPerformedAt = nil`, new `RoutineItem` per source item (copy targets, **keep** the `Exercise` reference).
  - `RoutineRow` — name, `orderedItems.count` exercises, `RelativeDateText(lastPerformedAt)`, a capsule **Start** button.
  - `RoutineListView` — `NavigationStack`; `@Query` non-archived sorted by name; `ContentUnavailableView` when empty with a "New Routine" action; rows are `NavigationLink(value: routine)` → `RoutineDetailView`; a separate `navigationDestination(item:)` drives the Start button's `RoutineDetailView(routine:autoStart:true)`. Swipe: Edit sheet / Duplicate / Delete-or-archive (archive if any finished session's `sourceRoutine` is this routine — fetch all sessions and check in Swift; SwiftData predicates over optional relationships are unreliable).
- **Stubs:** `RoutineEditorView` (Task 12), `RoutineDetailView` (Task 13), `ActiveWorkoutView` (Task 14) — minimal, replaced in their tasks.
- **Tests (`RoutineDuplicationTests`, `@MainActor`):** copy has `" Copy"` name, `nil` lastPerformed, same count, same `Exercise` refs, distinct `RoutineItem` objects, copied targets; store now has 2 routines.
- **Commit:** `feat: routine list with duplicate and delete/archive`

### Task 12: Routine editor
- **Create:**
  - `Shared/RepRange.swift` — `label(min:max:) -> String?`: `8–12`, `5` (equal), `6+` (min only), `≤10` (max only), `nil` (neither).
  - `Features/Routines/ExercisePickerView(onPick:)` — `.searchable` list of non-archived exercises + "New exercise" (reuses `ExerciseEditorView`); calls `onPick` then dismisses.
  - `RoutineItemEditorView(item: RoutineItem)` — `@Bindable`; optional target sets / rep min–max / rest override via toggles + steppers; writes to the context `.onDisappear`.
  - `RoutineEditorView(routine: Routine?)` — name field; `List` of items with `.onMove` (rewrites `order`) and `.onDelete`; "Add exercise" sheet → `ExercisePickerView`; each row → `RoutineItemEditorView` and shows the `sets × reps` label. On `nil`, creates the `Routine` on first add/save; **Cancel** rolls back a newly-created empty routine.
- **Tests (`RepRangeTests`):** the five formatting cases above.
- **Verify (Simulator):** build a "Push" routine (add 3 exercises, reorder, set targets), reopen → persisted; cancel a new routine → not saved.
- **Commit:** `feat: routine editor with items, targets, and reordering`

### Task 13: Workout controller + routine detail / start

**This is the core state machine — build it exactly.**

- **Create `Features/Workout/WorkoutController.swift`:**

```swift
@Observable @MainActor
final class WorkoutController {
    private let context: ModelContext
    private(set) var activeSession: WorkoutSession?

    init(context: ModelContext) {
        self.context = context
        self.activeSession = Self.fetchActiveSession(in: context)
    }

    var hasActiveSession: Bool { activeSession != nil }
    enum WorkoutError: Error, Equatable { case sessionAlreadyActive }

    func start(from routine: Routine) throws -> WorkoutSession {
        guard activeSession == nil else { throw WorkoutError.sessionAlreadyActive }
        let session = WorkoutSession(startedAt: .now, sourceRoutine: routine, sourceRoutineName: routine.name)
        context.insert(session)
        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }
            session.exercises.append(WorkoutExercise(
                exercise: exercise, exerciseID: exercise.id, order: item.order,
                targetSets: item.targetSets, targetRepMin: item.targetRepMin, targetRepMax: item.targetRepMax,
                restSeconds: item.targetRestSeconds ?? exercise.defaultRestSeconds))
        }
        save(); activeSession = session
        return session
    }

    func addExercise(_ exercise: Exercise, to session: WorkoutSession) {
        let order = (session.orderedExercises.last?.order ?? -1) + 1
        session.exercises.append(WorkoutExercise(
            exercise: exercise, exerciseID: exercise.id, order: order, restSeconds: exercise.defaultRestSeconds))
        save()
    }

    @discardableResult
    func addSet(to we: WorkoutExercise, weightKg: Double?, addedWeightKg: Double?,
               reps: Int, rpe: Double?, isWarmup: Bool) -> ExerciseSet {
        let order = (we.orderedSets.last?.order ?? -1) + 1
        let set = ExerciseSet(order: order, weightKg: weightKg, addedWeightKg: addedWeightKg,
                              reps: reps, rpe: rpe, isWarmup: isWarmup)
        we.sets.append(set); save()
        return set
    }

    func toggleComplete(_ set: ExerciseSet) {
        set.isComplete.toggle()
        set.completedAt = set.isComplete ? .now : nil
        save()
    }

    func discard(_ session: WorkoutSession) {
        context.delete(session); save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    // Return type becomes WorkoutSummary in Task 16.
    @discardableResult
    func finish(_ session: WorkoutSession, history: [WorkoutSession]) -> Void {
        let now = Date.now
        session.endedAt = now
        session.sourceRoutine?.lastPerformedAt = now
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("WorkoutController save failed: \(error)") }
    }

    private static func fetchActiveSession(in context: ModelContext) -> WorkoutSession? {
        var d = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }
}
```

- **Create `RoutineDetailView(routine:autoStart:)`** — lists items with target labels, `lastPerformedAt`, a rough estimated duration (`Σ (targetSets ?? 3) × 2.5 min`); a bottom `safeAreaInset` **Start Workout** button. Holds a `@State WorkoutController?` built from `@Environment(\.modelContext)`. On start: if `hasActiveSession`, alert (Resume / Cancel); else `try? start(from:)` and push `ActiveWorkoutView` via `navigationDestination(item:)` (guard `if let controller` — no force-unwrap). `autoStart` triggers the start path in `.task`.
- **Tests (`WorkoutControllerTests`, `@MainActor`):** start copies items in order with rest resolved (item override beats exercise default); second `start` throws `sessionAlreadyActive`; a fresh controller recovers the active session on `init`; `addSet` increments `order` and leaves sets incomplete; `finish` stamps `endedAt`, clears `activeSession`, sets `routine.lastPerformedAt`; `discard` deletes the session.
- **Commit:** `feat: workout controller state machine and routine detail / start`

### Task 14: Active workout — set logging + "last time"
- **Create:**
  - `Features/Workout/LastPerformance.swift` — `mostRecentSets(ofExerciseID:excludingSession:in:) -> [ExerciseSet]`: fetch `WorkoutExercise` where `exerciseID == id && session.endedAt != nil && session.id != excluding`, sorted by `session.startedAt` desc, take the first, return its completed non-warmup sets. Fallback noted in a comment if the predicate misbehaves (fetch finished sessions, scan in Swift).
  - `SetEntryRow(set:isBodyweight:unit:onToggleComplete:)` — `@Bindable set`; complete checkbox; weight field (hidden for bodyweight, which shows an added-weight field instead) bound through `WeightFormatting.editableValue`/`kilograms`; reps field; RPE menu (None + 6.0…10.0 by 0.5); warmup toggle.
  - `WorkoutExerciseCard(workoutExercise:sessionID:controller:onSetCompleted:)` — header with name + target label; `"Last: …"` line from `LastPerformance` (`"First time"` if empty); `SetEntryRow` per `orderedSets`; "Add set" prefilled from the previous set. Completing a set calls `controller.toggleComplete` then `onSetCompleted`.
  - `ActiveWorkoutView(session:controller:)` — `ScrollView`/`LazyVStack` of cards; nav title = `sourceRoutineName`; principal toolbar = `TimelineView` elapsed clock; trailing **Finish**; "Add exercise" sheet → `ExercisePickerView` → `controller.addExercise`; `.interactiveDismissDisabled()`. Temporary Finish = confirm alert → `controller.finish(session, history: [])` → `dismiss()` (replaced in Task 16). `@Environment(\.modelContext)` for the history fetch later.
- **Stubs:** `RestTimer` / `RestTimerBar` minimal (Task 15).
- **Tests (`LastPerformanceTests`, `@MainActor`):** picks working sets from the most recent finished session, excludes the current session, filters warmups, ignores in-progress sessions.
- **Verify (Simulator):** log Bench 100×5 twice, finish, restart the routine → card shows `"Last: 100 kg × 5"`; switch unit to lb → re-renders.
- **Commit:** `feat: active workout screen with set logging and last-time reference`

### Task 15: Rest timer
- **Create `Features/Workout/RestTimer.swift`:**

```swift
@MainActor protocol RestNotifying { func schedule(after seconds: Int); func cancel() }

@Observable @MainActor
final class RestTimer {
    private(set) var endsAt: Date?
    private let notifier: RestNotifying
    init(notifier: RestNotifying = LocalRestNotifier()) { self.notifier = notifier }

    var isRunning: Bool { isRunning(at: .now) }
    func isRunning(at now: Date) -> Bool { (endsAt ?? .distantPast) > now }

    func start(seconds: Int, now: Date = .now) {
        endsAt = now.addingTimeInterval(.init(seconds))
        notifier.schedule(after: seconds)
    }
    func addSeconds(_ delta: Int, now: Date = .now) {
        endsAt = (endsAt ?? now).addingTimeInterval(.init(delta))
        notifier.schedule(after: remaining(at: now))
    }
    func skip() { endsAt = nil; notifier.cancel() }
    func remaining(at now: Date = .now) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }
}
```

  `LocalRestNotifier` (also in this file): schedules one `UNTimeIntervalNotificationTrigger` with a fixed identifier (`"forge.rest-timer"`) so reschedules replace it; requests `.alert, .sound` authorization on first `schedule`. `cancel()` removes the pending request.
- **Create `RestTimerBar(timer:)`** — `TimelineView(.periodic(by: 1))` showing `m:ss`, with `−30` / `Skip` / `+30`. Shown via `safeAreaInset` in `ActiveWorkoutView` while `timer.isRunning`. `onSetCompleted` in the card calls `timer.start(seconds: we.restSeconds ?? Preferences.defaultRestSeconds)`.
- **Tests (`RestTimerTests`, `@MainActor`, `SpyNotifier`):** `start` sets `endsAt`, `remaining` counts down, schedules `[120]`; `remaining` clamps to 0 and `isRunning(at:)` goes false; `addSeconds(30)` extends and reschedules; `skip` stops and cancels once.
- **Verify (Simulator):** completing a set shows the bar; +/−/Skip work; backgrounding fires the notification.
- **Commit:** `feat: rest timer with local notification and adjustable countdown`

### Task 16: Finish + summary
- **Create:**
  - `Features/Workout/WorkoutSummary.swift` — `struct PRHitDisplay { exerciseName; kind }`; `struct WorkoutSummary: Identifiable { let id = UUID(); durationSeconds; totalVolumeKg; workingSetCount; bodyParts: [BodyPart]; prHits: [PRHitDisplay] }`; `enum WorkoutSummaryBuilder { static func build(session:finishedAt:history:) -> WorkoutSummary }` using `session.coreInput`, `sessionVolumeKg`, `newPersonalRecords`, and an ordered-unique list of primary body parts. Exercise names resolved from the session's `WorkoutExercise.exercise`.
  - `WorkoutSummaryView(summary:onDone:)` — `List`: duration / volume / working sets / trained body parts; a "Personal records" section with a trophy per `PRHitDisplay` ("heaviest weight" / "most reps" / "best estimated 1RM"). "Done" button.
- **Modify:** `WorkoutController.finish` returns `WorkoutSummary` (build it after stamping `endedAt`). Update the Task 13 `finish` test to bind the result. `ActiveWorkoutView`: replace the temporary alert — Finish fetches finished sessions (`#Predicate { $0.endedAt != nil }`), calls `controller.finish`, presents `.sheet(item: $summary)`; Done dismisses both.
- **Tests (`WorkoutSummaryTests`, `@MainActor`):** a session beating a two-week-old bench shows correct duration, total volume, working-set count, body-part set, and bench PRs `{weight, e1rm}` plus a squat weight PR.
- **Commit:** `feat: finish workout with a summary of volume, sets, and PRs`

### Task 17: Stale-session prompt
- **Create:** `Features/Workout/StaleSessionCheck.swift` — `isStale(_ session:now:threshold: = 6*3600) -> Bool`: `endedAt == nil && now - startedAt > threshold`.
- **Modify:** `RootView` — in `.task`, build/keep a `WorkoutController`; if `activeSession` is stale, present an alert: **Finish it** (`controller.finish(_, history:)`) or **Discard** (`controller.discard`). A non-stale active session is left alone.
- **Tests (`StaleSessionCheckTests`):** older than threshold → stale; within → not; finished → never stale.
- **Commit:** `feat: prompt to finish or discard a stale workout on launch`

### Task 18: History
- **Create:**
  - `Features/History/MonthGrouping.swift` — `sections(_ sessions:calendar:) -> [(title: String, sessions: [WorkoutSession])]`: group by year+month, newest month first, sessions newest first, title `"LLLL yyyy"`.
  - `SessionDetailView(session:)` — header (date, duration, `sessionVolumeKg(session.coreInput)`, notes); a section per `orderedExercises` listing each set (`weight × reps` or bodyweight reps, warmup tag, RPE).
  - `HistoryListView` — `@Query` finished sessions desc; `ContentUnavailableView` when empty; `MonthGrouping` sections; row = routine name, date, duration, volume; tap → `SessionDetailView`.
- Wire `HistoryListView` into `RootView`.
- **Tests (`MonthGroupingTests`, `@MainActor`):** three sessions across two months → `["September 2026", "August 2026"]`, September has 2, ordered newest-first.
- **Verify (Simulator):** full pass — create routine, run it, hit a PR, finish → summary → appears in History → detail shows every set → restart shows "last time".
- **Final:** `cd Packages/ForgeCore && swift test` and `xcodebuild test …` both fully green.
- **Commit:** `feat: workout history list and session detail`

---

## Deviations from the PRD (already synced into `docs/PRD.md`)

1. **`WorkoutExercise`** entity added between `WorkoutSession` and `ExerciseSet` (planned exercises, snapshotted targets, crash-safety).
2. **Streak + heatmap deferred to M2** — nothing in M1 renders them.
3. **M1 ships 3 tabs** (Workout / History / Settings); Progress + Dashboard in M2.
4. **Identifiers** `com.forge.gym` / `group.com.forge.gym`.
5. `Exercise` / `Routine` / `WorkoutSession` each get an explicit `id: UUID`.

---

## Self-review

- **Spec coverage:** every PRD §5 model, §6 M1 function, §7.1–7.4 + §7.7 screen, and the archival rules map to a task (table above). Progress/Dashboard/Chat and streak/heatmap are explicitly out of M1 per PRD §8.
- **Type consistency:** `estimatedOneRepMax`, `sessionVolumeKg`, `sessionBestE1RM`, `newPersonalRecords` identical across Tasks 4/7/16. `WorkoutController.finish` returns `Void` in Task 13 → `WorkoutSummary` in Task 16 (called out, test updated there). `WorkoutExercise.exerciseID` is the query key in Tasks 10/14/16.
- **Stubs:** Tasks 9, 11, 13, 14 introduce named temporary stubs, each replaced in a specific later task and called out in its commit.

---

## Execution

**1. Subagent-driven (recommended)** — fresh subagent per task, two-stage review between tasks.
**2. Inline** — tasks run in this session with checkpoints.

Which approach?
