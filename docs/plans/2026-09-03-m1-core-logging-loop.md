# Forge M1 — Core Logging Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a usable personal gym logger — create custom exercises, build routines, run a workout logging sets (with a "last time" reference and a rest timer), finish with a summary, and browse workout history.

**Architecture:** A SwiftUI + SwiftData iPhone app backed by a single `ModelContainer` stored in an App Group container (so the M3 widget can share it without a migration). All non-trivial computation — estimated 1RM, volume, personal-record detection — lives in `ForgeCore`, a dependency-free local Swift package tested with `swift test`. App-layer logic (the workout state machine, model⇄core mapping, seeding, formatting) is tested with `xcodebuild test` against an in-memory container. The Xcode project is generated from a checked-in `project.yml` via XcodeGen.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Observation (`@Observable`), UserNotifications, Swift Testing, XcodeGen.

**Spec:** [`docs/PRD.md`](../PRD.md) — this plan implements **Milestone 1** only. Read the PRD's §4 (architecture), §5 (data model), §6 (computations), §7 (screens) alongside this plan.

## Global Constraints

- **iOS deployment target: `26.0`** (exact). Host toolchain: Xcode 26.6 / Swift 6.3. Simulator runtime available: iOS 26.5 (`iPhone 17`).
- **No personal name in any identifier.** Bundle identifier: `com.forge.gym`. App Group: `group.com.forge.gym`. Package/module name: `ForgeCore`.
- **`ForgeCore` is dependency-free** and imports only `Foundation`. It must never import `SwiftData`, `SwiftUI`, or `Observation`. Its test suite must pass under a bare `swift test`.
- **All loads are stored in kilograms.** `weightKg` / `addedWeightKg` are canonical. Unit (kg/lb) is a display-and-input concern only, handled in the app layer.
- **Tests use Swift Testing** (`import Testing`, `@Test`, `#expect`). No XCTest.
- **One primary type per file.** No force-unwrapping except the single documented `ModelContainer` bootstrap. Every `public` symbol in `ForgeCore` carries a doc comment. 4-space indentation.
- **Commit after every task** using Conventional Commits (`feat:`, `test:`, `chore:`, `refactor:`).
- **No external runtime dependencies.** XcodeGen is a build-time tool only, installed via Homebrew.
- **Simulator builds need no code signing.** Running on a physical device requires the user to select their personal team in Xcode → Signing & Capabilities; the team ID is never committed.

---

## File Structure

```
Forge/
  project.yml                          # XcodeGen project definition
  .gitignore                           # (exists) — Forge.xcodeproj is ignored
  Brewfile                             # xcodegen dependency
  docs/
    PRD.md
    plans/2026-09-03-m1-core-logging-loop.md

  Packages/
    ForgeCore/
      Package.swift
      Sources/ForgeCore/
        Inputs.swift                   # ExerciseInput, SetInput, WorkoutExerciseInput, SessionInput
        OneRepMax.swift                # estimatedOneRepMax(weightKg:reps:)
        Volume.swift                   # workingSets, setVolumeKg, sessionVolumeKg
        Progression.swift              # sessionBestE1RM
        PersonalRecords.swift          # PRSet, personalRecords, PRHit, newPersonalRecords
      Tests/ForgeCoreTests/
        OneRepMaxTests.swift
        VolumeTests.swift
        ProgressionTests.swift
        PersonalRecordsTests.swift

  Forge/                               # app target sources
    App/
      ForgeApp.swift                   # @main, model container, root scene
      RootView.swift                   # TabView scaffold
      PersistenceController.swift      # container factory (App Group + in-memory), first-run seeding hook
    Models/
      BodyPart.swift                   # enum
      WeightUnit.swift                 # enum
      Exercise.swift                   # @Model
      Routine.swift                    # @Model
      RoutineItem.swift                # @Model
      WorkoutSession.swift             # @Model
      WorkoutExercise.swift            # @Model
      ExerciseSet.swift                # @Model
    Persistence/
      ModelMapping.swift               # @Model -> ForgeCore.*Input
      SeedData.swift                   # starter exercise catalogue + seeding
    Preferences/
      Preferences.swift                # App Group UserDefaults accessor
      WeightFormatting.swift           # kg<->lb display + parse
    Features/
      ExerciseLibrary/
        ExerciseLibraryView.swift
        ExerciseEditorView.swift
        ExerciseDeletion.swift         # archive-vs-delete decision (pure, tested)
      Routines/
        RoutineListView.swift
        RoutineRow.swift
        RoutineDetailView.swift
        RoutineEditorView.swift
        RoutineItemEditorView.swift
        RoutineDuplication.swift       # deep-copy (pure-ish, tested)
      Workout/
        WorkoutController.swift        # @Observable state machine over ModelContext
        ActiveWorkoutView.swift
        WorkoutExerciseCard.swift
        SetEntryRow.swift
        LastPerformance.swift          # fetch helper (tested)
        RestTimer.swift                # @Observable countdown + notification
        RestTimerBar.swift
        WorkoutSummary.swift           # value type + assembly (tested)
        WorkoutSummaryView.swift
        StaleSessionCheck.swift        # pure detection (tested)
      History/
        HistoryListView.swift
        SessionDetailView.swift
        MonthGrouping.swift            # pure (tested)
    Settings/
      SettingsView.swift
    Shared/
      RepRange.swift                   # formatting a target rep range
      RelativeDateText.swift

  ForgeTests/                          # app unit-test target (xcodebuild test)
    PersistenceControllerTests.swift
    ModelMappingTests.swift
    SeedDataTests.swift
    WeightFormattingTests.swift
    ExerciseDeletionTests.swift
    RoutineDuplicationTests.swift
    WorkoutControllerTests.swift
    LastPerformanceTests.swift
    WorkoutSummaryTests.swift
    StaleSessionCheckTests.swift
    MonthGroupingTests.swift
```

---

## Task 1: Project scaffold & tooling

**Files:**
- Create: `Brewfile`, `project.yml`, `Packages/ForgeCore/Package.swift`, `Packages/ForgeCore/Sources/ForgeCore/Placeholder.swift`, `Packages/ForgeCore/Tests/ForgeCoreTests/PlaceholderTests.swift`
- Create: `Forge/App/ForgeApp.swift`, `Forge/App/RootView.swift`, `Forge/Forge.entitlements`, `Forge/Info.plist`
- Create: `ForgeTests/PlaceholderTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable `Forge.xcodeproj` (generated), a `ForgeCore` package that builds and tests standalone, and an app that launches to an empty `TabView`. Scheme name: `Forge`. Test destination: `platform=iOS Simulator,name=iPhone 17`.

- [ ] **Step 1: Write the Brewfile**

```ruby
# Brewfile — run `brew bundle` to install build tooling
brew "xcodegen"
```

- [ ] **Step 2: Write `Packages/ForgeCore/Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ForgeCore", targets: ["ForgeCore"]),
    ],
    targets: [
        .target(
            name: "ForgeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ForgeCoreTests",
            dependencies: ["ForgeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
```

- [ ] **Step 3: Write a placeholder so the package compiles**

`Packages/ForgeCore/Sources/ForgeCore/Placeholder.swift`:

```swift
// Replaced in Task 2.
enum ForgeCorePlaceholder {}
```

`Packages/ForgeCore/Tests/ForgeCoreTests/PlaceholderTests.swift`:

```swift
import Testing

@Test func packageBuilds() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Run the package test to prove the toolchain works**

Run: `cd Packages/ForgeCore && swift test`
Expected: PASS (1 test).

- [ ] **Step 5: Write `Forge/Forge.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.forge.gym</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Write `Forge/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
</dict>
</plist>
```

- [ ] **Step 7: Write `project.yml`**

```yaml
name: Forge
options:
  bundleIdPrefix: com.forge
  deploymentTarget:
    iOS: "26.0"
  createIntermediateGroups: true

packages:
  ForgeCore:
    path: Packages/ForgeCore

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: ""
    GENERATE_INFOPLIST_FILE: NO
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"

targets:
  Forge:
    type: application
    platform: iOS
    sources:
      - path: Forge
    dependencies:
      - package: ForgeCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.forge.gym
        INFOPLIST_FILE: Forge/Info.plist
        CODE_SIGN_ENTITLEMENTS: Forge/Forge.entitlements
        ENABLE_PREVIEWS: YES

  ForgeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ForgeTests
    dependencies:
      - target: Forge
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.forge.gym.tests
        GENERATE_INFOPLIST_FILE: YES

schemes:
  Forge:
    build:
      targets:
        Forge: all
        ForgeTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - ForgeTests
```

- [ ] **Step 8: Write the app entry point**

`Forge/App/ForgeApp.swift`:

```swift
import SwiftUI

@main
struct ForgeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

`Forge/App/RootView.swift`:

```swift
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
```

- [ ] **Step 9: Write a placeholder app test**

`ForgeTests/PlaceholderTests.swift`:

```swift
import Testing
@testable import Forge

@Test func appModuleImports() {
    #expect(Bool(true))
}
```

- [ ] **Step 10: Generate the project and build**

Run:
```bash
brew bundle
xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 11: Run the app test target**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "chore: scaffold Xcode project, ForgeCore package, and test targets"
```

---

## Task 2: ForgeCore — value types & estimated 1RM

**Files:**
- Create: `Packages/ForgeCore/Sources/ForgeCore/Inputs.swift`
- Create: `Packages/ForgeCore/Sources/ForgeCore/OneRepMax.swift`
- Delete: `Packages/ForgeCore/Sources/ForgeCore/Placeholder.swift`, `Packages/ForgeCore/Tests/ForgeCoreTests/PlaceholderTests.swift`
- Test: `Packages/ForgeCore/Tests/ForgeCoreTests/OneRepMaxTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ExerciseInput(id: UUID, isBodyweight: Bool, isUnilateral: Bool)`
  - `SetInput(weightKg: Double?, addedWeightKg: Double?, reps: Int, rpe: Double?, isWarmup: Bool, isComplete: Bool)`
  - `WorkoutExerciseInput(exercise: ExerciseInput, sets: [SetInput])`
  - `SessionInput(id: UUID, startedAt: Date, endedAt: Date?, exercises: [WorkoutExerciseInput])` with computed `var isFinished: Bool`
  - `func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double`
  - All types are `public`, `Sendable`, `Codable`, `Equatable`.

- [ ] **Step 1: Write the input value types**

`Inputs.swift`:

```swift
import Foundation

/// The exercise attributes ForgeCore needs to score a set.
/// Mapped from the app's `Exercise` model at the call site.
public struct ExerciseInput: Sendable, Codable, Equatable {
    public let id: UUID
    public let isBodyweight: Bool
    public let isUnilateral: Bool

    public init(id: UUID, isBodyweight: Bool, isUnilateral: Bool) {
        self.id = id
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
    }
}

/// One logged set. For unilateral exercises, `reps` is the count per side.
public struct SetInput: Sendable, Codable, Equatable {
    public let weightKg: Double?
    public let addedWeightKg: Double?
    public let reps: Int
    public let rpe: Double?
    public let isWarmup: Bool
    public let isComplete: Bool

    public init(
        weightKg: Double?,
        addedWeightKg: Double? = nil,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        isComplete: Bool = true
    ) {
        self.weightKg = weightKg
        self.addedWeightKg = addedWeightKg
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isComplete = isComplete
    }
}

/// One exercise slot within a session, with its logged sets in entry order.
public struct WorkoutExerciseInput: Sendable, Codable, Equatable {
    public let exercise: ExerciseInput
    public let sets: [SetInput]

    public init(exercise: ExerciseInput, sets: [SetInput]) {
        self.exercise = exercise
        self.sets = sets
    }
}

/// A whole workout session, finished or in progress.
public struct SessionInput: Sendable, Codable, Equatable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let exercises: [WorkoutExerciseInput]

    public init(id: UUID, startedAt: Date, endedAt: Date?, exercises: [WorkoutExerciseInput]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
    }

    /// A session counts as finished once it has an end timestamp.
    public var isFinished: Bool { endedAt != nil }
}
```

- [ ] **Step 2: Write the failing 1RM test**

`OneRepMaxTests.swift`:

```swift
import Foundation
import Testing
@testable import ForgeCore

@Suite struct OneRepMaxTests {
    @Test func singleRepReturnsTheWeight() {
        #expect(estimatedOneRepMax(weightKg: 100, reps: 1) == 100)
    }

    @Test func epleyFormulaForMultipleReps() {
        // 100 * (1 + 5/30) = 116.666...
        #expect(abs(estimatedOneRepMax(weightKg: 100, reps: 5) - 116.6667) < 0.001)
    }

    @Test func zeroOrNegativeRepsReturnsZero() {
        #expect(estimatedOneRepMax(weightKg: 100, reps: 0) == 0)
        #expect(estimatedOneRepMax(weightKg: 100, reps: -3) == 0)
    }

    @Test func zeroWeightReturnsZero() {
        #expect(estimatedOneRepMax(weightKg: 0, reps: 8) == 0)
    }
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `cd Packages/ForgeCore && swift test --filter OneRepMaxTests`
Expected: FAIL — `estimatedOneRepMax` is undefined.

- [ ] **Step 4: Implement `OneRepMax.swift`**

```swift
import Foundation

/// Estimated one-rep max using the Epley formula: `weight * (1 + reps / 30)`.
///
/// A single rep returns the weight unchanged. Non-positive `reps` or `weightKg`
/// return `0` — there is no meaningful estimate to make.
public func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
    guard weightKg > 0, reps > 0 else { return 0 }
    if reps == 1 { return weightKg }
    return weightKg * (1 + Double(reps) / 30)
}
```

- [ ] **Step 5: Delete the placeholders**

```bash
rm Packages/ForgeCore/Sources/ForgeCore/Placeholder.swift
rm Packages/ForgeCore/Tests/ForgeCoreTests/PlaceholderTests.swift
```

- [ ] **Step 6: Run the full package suite**

Run: `cd Packages/ForgeCore && swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: ForgeCore value types and estimated 1RM"
```

---

## Task 3: ForgeCore — working sets & volume

**Files:**
- Create: `Packages/ForgeCore/Sources/ForgeCore/Volume.swift`
- Test: `Packages/ForgeCore/Tests/ForgeCoreTests/VolumeTests.swift`

**Interfaces:**
- Consumes: `SetInput`, `ExerciseInput`, `WorkoutExerciseInput`, `SessionInput` (Task 2).
- Produces:
  - `func workingSets(_ sets: [SetInput]) -> [SetInput]` — drops warmups and incomplete sets.
  - `func setVolumeKg(_ set: SetInput, exercise: ExerciseInput) -> Double`
  - `func sessionVolumeKg(_ session: SessionInput) -> Double` — sum of working-set volume across all exercises.

- [ ] **Step 1: Write the failing tests**

`VolumeTests.swift`:

```swift
import Foundation
import Testing
@testable import ForgeCore

@Suite struct VolumeTests {
    let barbell = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: false)
    let unilateral = ExerciseInput(id: UUID(), isBodyweight: false, isUnilateral: true)
    let bodyweight = ExerciseInput(id: UUID(), isBodyweight: true, isUnilateral: false)

    @Test func standardSetVolumeIsWeightTimesReps() {
        let set = SetInput(weightKg: 100, reps: 5)
        #expect(setVolumeKg(set, exercise: barbell) == 500)
    }

    @Test func unilateralSetVolumeIsDoubled() {
        let set = SetInput(weightKg: 20, reps: 10)
        #expect(setVolumeKg(set, exercise: unilateral) == 400)
    }

    @Test func bodyweightSetsContributeNoVolume() {
        let set = SetInput(weightKg: nil, addedWeightKg: 20, reps: 12)
        #expect(setVolumeKg(set, exercise: bodyweight) == 0)
    }

    @Test func nilWeightOnANonBodyweightExerciseIsZero() {
        let set = SetInput(weightKg: nil, reps: 5)
        #expect(setVolumeKg(set, exercise: barbell) == 0)
    }

    @Test func workingSetsDropsWarmupsAndIncomplete() {
        let sets = [
            SetInput(weightKg: 40, reps: 10, isWarmup: true, isComplete: true),
            SetInput(weightKg: 100, reps: 5, isComplete: true),
            SetInput(weightKg: 100, reps: 5, isComplete: false),
        ]
        #expect(workingSets(sets).count == 1)
        #expect(workingSets(sets).first?.weightKg == 100)
    }

    @Test func sessionVolumeSumsWorkingSetsAcrossExercises() {
        let session = SessionInput(
            id: UUID(),
            startedAt: .now,
            endedAt: .now,
            exercises: [
                WorkoutExerciseInput(exercise: barbell, sets: [
                    SetInput(weightKg: 60, reps: 10, isWarmup: true),   // excluded
                    SetInput(weightKg: 100, reps: 5),                   // 500
                    SetInput(weightKg: 100, reps: 5),                   // 500
                ]),
                WorkoutExerciseInput(exercise: unilateral, sets: [
                    SetInput(weightKg: 20, reps: 10),                   // 400
                ]),
                WorkoutExerciseInput(exercise: bodyweight, sets: [
                    SetInput(weightKg: nil, reps: 15),                  // 0
                ]),
            ]
        )
        #expect(sessionVolumeKg(session) == 1400)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `cd Packages/ForgeCore && swift test --filter VolumeTests`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Implement `Volume.swift`**

```swift
import Foundation

/// Sets that count toward volume, 1RM, and PRs: completed and not a warmup.
public func workingSets(_ sets: [SetInput]) -> [SetInput] {
    sets.filter { $0.isComplete && !$0.isWarmup }
}

/// Training volume for one set, in kilograms.
///
/// - Bodyweight exercises contribute `0` (they are tracked by reps, not load).
/// - Unilateral exercises double the volume, since the logged reps are per side.
/// - A `nil` `weightKg` on a non-bodyweight exercise contributes `0`.
public func setVolumeKg(_ set: SetInput, exercise: ExerciseInput) -> Double {
    guard !exercise.isBodyweight, let weight = set.weightKg else { return 0 }
    let sides = exercise.isUnilateral ? 2.0 : 1.0
    return weight * Double(set.reps) * sides
}

/// Total working-set volume across every exercise in the session, in kilograms.
public func sessionVolumeKg(_ session: SessionInput) -> Double {
    session.exercises.reduce(0) { runningTotal, workoutExercise in
        let exerciseVolume = workingSets(workoutExercise.sets).reduce(0) { setTotal, set in
            setTotal + setVolumeKg(set, exercise: workoutExercise.exercise)
        }
        return runningTotal + exerciseVolume
    }
}
```

- [ ] **Step 4: Run the suite**

Run: `cd Packages/ForgeCore && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ForgeCore working-set filter and volume math"
```

---

## Task 4: ForgeCore — session 1RM, personal records, PR hits

**Files:**
- Create: `Packages/ForgeCore/Sources/ForgeCore/Progression.swift`
- Create: `Packages/ForgeCore/Sources/ForgeCore/PersonalRecords.swift`
- Test: `Packages/ForgeCore/Tests/ForgeCoreTests/ProgressionTests.swift`, `Packages/ForgeCore/Tests/ForgeCoreTests/PersonalRecordsTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 2–3.
- Produces:
  - `func sessionBestE1RM(_ session: SessionInput, exerciseID: UUID) -> Double?` — best Epley estimate over that exercise's working sets in the session; `nil` if none.
  - `struct PRSet { maxWeightKg: Double?; maxReps: Int?; bestE1RM: Double? }` — `public`, `Sendable`, `Equatable`.
  - `func personalRecords(_ sessions: [SessionInput], exerciseID: UUID) -> PRSet` — over **finished** sessions only.
  - `enum PRKind { case weight, reps, e1rm }` — `public`, `Sendable`, `Equatable`, `Hashable`.
  - `struct PRHit { exerciseID: UUID; kind: PRKind; value: Double }` — `public`, `Sendable`, `Equatable`.
  - `func newPersonalRecords(in session: SessionInput, history: [SessionInput]) -> [PRHit]` — records set by `session` that beat everything in `history`. `history` must exclude `session`.

- [ ] **Step 1: Write the failing progression test**

`ProgressionTests.swift`:

```swift
import Foundation
import Testing
@testable import ForgeCore

@Suite struct ProgressionTests {
    let squatID = UUID()

    func session(sets: [SetInput], exerciseID: UUID) -> SessionInput {
        let exercise = ExerciseInput(id: exerciseID, isBodyweight: false, isUnilateral: false)
        return SessionInput(
            id: UUID(), startedAt: .now, endedAt: .now,
            exercises: [WorkoutExerciseInput(exercise: exercise, sets: sets)]
        )
    }

    @Test func picksTheHighestEstimateAcrossWorkingSets() {
        let s = session(sets: [
            SetInput(weightKg: 140, reps: 1),          // 140
            SetInput(weightKg: 120, reps: 5),          // 140.0
            SetInput(weightKg: 100, reps: 10),         // 133.3
            SetInput(weightKg: 200, reps: 5, isWarmup: true), // excluded
        ], exerciseID: squatID)
        let best = sessionBestE1RM(s, exerciseID: squatID)
        #expect(best != nil)
        #expect(abs(best! - 140) < 0.001)
    }

    @Test func nilWhenTheExerciseHasNoWorkingSets() {
        let s = session(sets: [SetInput(weightKg: 100, reps: 5, isWarmup: true)], exerciseID: squatID)
        #expect(sessionBestE1RM(s, exerciseID: squatID) == nil)
        #expect(sessionBestE1RM(s, exerciseID: UUID()) == nil)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `Progression.swift`**

Run: `cd Packages/ForgeCore && swift test --filter ProgressionTests` → FAIL.

```swift
import Foundation

/// The best estimated 1RM among a given exercise's working sets in one session.
/// Returns `nil` when that exercise has no qualifying sets.
public func sessionBestE1RM(_ session: SessionInput, exerciseID: UUID) -> Double? {
    let estimates = session.exercises
        .filter { $0.exercise.id == exerciseID }
        .flatMap { workingSets($0.sets) }
        .compactMap { set -> Double? in
            guard let weight = set.weightKg else { return nil }
            return estimatedOneRepMax(weightKg: weight, reps: set.reps)
        }
    return estimates.max()
}
```

Run: `cd Packages/ForgeCore && swift test --filter ProgressionTests` → PASS.

- [ ] **Step 3: Write the failing personal-records test**

`PersonalRecordsTests.swift`:

```swift
import Foundation
import Testing
@testable import ForgeCore

@Suite struct PersonalRecordsTests {
    let benchID = UUID()

    func finished(_ sets: [SetInput], daysAgo: Int) -> SessionInput {
        let ex = ExerciseInput(id: benchID, isBodyweight: false, isUnilateral: false)
        let day = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
        return SessionInput(id: UUID(), startedAt: day, endedAt: day,
                            exercises: [WorkoutExerciseInput(exercise: ex, sets: sets)])
    }

    @Test func aggregatesMaxWeightRepsAndE1RMOverHistory() {
        let history = [
            finished([SetInput(weightKg: 80, reps: 8)], daysAgo: 20),
            finished([SetInput(weightKg: 100, reps: 3), SetInput(weightKg: 60, reps: 15)], daysAgo: 10),
        ]
        let pr = personalRecords(history, exerciseID: benchID)
        #expect(pr.maxWeightKg == 100)
        #expect(pr.maxReps == 15)
        // best e1rm: 100*(1+3/30)=110 vs 80*(1+8/30)=101.3 vs 60*(1+15/30)=90
        #expect(abs((pr.bestE1RM ?? 0) - 110) < 0.001)
    }

    @Test func warmupsAndUnfinishedSessionsAreIgnored() {
        var unfinished = finished([SetInput(weightKg: 200, reps: 1)], daysAgo: 1)
        unfinished = SessionInput(id: unfinished.id, startedAt: unfinished.startedAt,
                                  endedAt: nil, exercises: unfinished.exercises)
        let pr = personalRecords(
            [unfinished, finished([SetInput(weightKg: 90, reps: 5, isWarmup: true)], daysAgo: 3)],
            exerciseID: benchID
        )
        #expect(pr.maxWeightKg == nil)
        #expect(pr.bestE1RM == nil)
    }

    @Test func newPersonalRecordsReportsOnlyBeatenCategories() {
        let history = [finished([SetInput(weightKg: 100, reps: 5)], daysAgo: 7)] // e1rm 116.67, wt 100, reps 5
        let today = finished([SetInput(weightKg: 105, reps: 5)], daysAgo: 0)     // e1rm 122.5, wt 105, reps 5
        let hits = newPersonalRecords(in: today, history: history)
        let kinds = Set(hits.map(\.kind))
        #expect(kinds == [.weight, .e1rm])   // reps tied, not beaten
        #expect(hits.first(where: { $0.kind == .weight })?.value == 105)
    }

    @Test func noHistoryMeansEveryCategoryIsAPR() {
        let today = finished([SetInput(weightKg: 60, reps: 10)], daysAgo: 0)
        let hits = newPersonalRecords(in: today, history: [])
        #expect(Set(hits.map(\.kind)) == [.weight, .reps, .e1rm])
    }
}
```

- [ ] **Step 4: Run to confirm failure, then implement `PersonalRecords.swift`**

Run: `cd Packages/ForgeCore && swift test --filter PersonalRecordsTests` → FAIL.

```swift
import Foundation

/// The best weight, rep count, and estimated 1RM ever recorded for one exercise.
/// Any field is `nil` when there is no qualifying working set in history.
public struct PRSet: Sendable, Equatable {
    public let maxWeightKg: Double?
    public let maxReps: Int?
    public let bestE1RM: Double?

    public init(maxWeightKg: Double?, maxReps: Int?, bestE1RM: Double?) {
        self.maxWeightKg = maxWeightKg
        self.maxReps = maxReps
        self.bestE1RM = bestE1RM
    }
}

public enum PRKind: Sendable, Equatable, Hashable {
    case weight, reps, e1rm
}

/// A personal record achieved in a specific session.
public struct PRHit: Sendable, Equatable {
    public let exerciseID: UUID
    public let kind: PRKind
    public let value: Double

    public init(exerciseID: UUID, kind: PRKind, value: Double) {
        self.exerciseID = exerciseID
        self.kind = kind
        self.value = value
    }
}

/// All working sets for one exercise across finished sessions.
private func workingSetsForExercise(_ sessions: [SessionInput], exerciseID: UUID) -> [SetInput] {
    sessions
        .filter(\.isFinished)
        .flatMap(\.exercises)
        .filter { $0.exercise.id == exerciseID }
        .flatMap { workingSets($0.sets) }
}

/// Aggregate personal records for one exercise over the given sessions
/// (finished sessions only).
public func personalRecords(_ sessions: [SessionInput], exerciseID: UUID) -> PRSet {
    let sets = workingSetsForExercise(sessions, exerciseID: exerciseID)
    let weights = sets.compactMap(\.weightKg)
    let e1rms = sets.compactMap { set -> Double? in
        guard let weight = set.weightKg else { return nil }
        return estimatedOneRepMax(weightKg: weight, reps: set.reps)
    }
    return PRSet(
        maxWeightKg: weights.max(),
        maxReps: sets.map(\.reps).max(),
        bestE1RM: e1rms.max()
    )
}

/// Records set by `session` that exceed everything in `history`.
/// `history` MUST NOT contain `session`.
public func newPersonalRecords(in session: SessionInput, history: [SessionInput]) -> [PRHit] {
    var hits: [PRHit] = []

    for workoutExercise in session.exercises {
        let exerciseID = workoutExercise.exercise.id
        let todaysSets = workingSets(workoutExercise.sets)
        guard !todaysSets.isEmpty else { continue }

        let previous = personalRecords(history, exerciseID: exerciseID)

        if let bestWeight = todaysSets.compactMap(\.weightKg).max(),
           bestWeight > (previous.maxWeightKg ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .weight, value: bestWeight))
        }
        if let bestReps = todaysSets.map(\.reps).max(),
           bestReps > (previous.maxReps ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .reps, value: Double(bestReps)))
        }
        if let bestE1RM = sessionBestE1RM(session, exerciseID: exerciseID),
           bestE1RM > (previous.bestE1RM ?? 0) {
            hits.append(PRHit(exerciseID: exerciseID, kind: .e1rm, value: bestE1RM))
        }
    }
    return hits
}
```

- [ ] **Step 5: Run the full package suite**

Run: `cd Packages/ForgeCore && swift test`
Expected: PASS (all suites).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: ForgeCore session 1RM and personal-record detection"
```

---

## Task 5: SwiftData models & enums

**Files:**
- Create: `Forge/Models/BodyPart.swift`, `Forge/Models/WeightUnit.swift`, `Forge/Models/Exercise.swift`, `Forge/Models/Routine.swift`, `Forge/Models/RoutineItem.swift`, `Forge/Models/WorkoutSession.swift`, `Forge/Models/WorkoutExercise.swift`, `Forge/Models/ExerciseSet.swift`

**Interfaces:**
- Consumes: nothing.
- Produces the SwiftData schema. Key public surface later tasks rely on:
  - `enum BodyPart: String, CaseIterable, Codable` — cases per PRD §5; `var displayName: String`.
  - `enum WeightUnit: String, CaseIterable, Codable { case kg, lb }`.
  - `Exercise(name:primaryBodyPart:isBodyweight:isUnilateral:defaultRestSeconds:)`, plus `isArchived: Bool`, `createdAt: Date`.
  - `Routine(name:)` with `items: [RoutineItem]`, `isArchived`, `createdAt`, `lastPerformedAt: Date?`, and `var orderedItems: [RoutineItem]`.
  - `RoutineItem(exercise:order:)` with optional `targetSets`, `targetRepMin`, `targetRepMax`, `targetRestSeconds`.
  - `WorkoutSession(startedAt:sourceRoutine:sourceRoutineName:)` with `endedAt: Date?`, `notes: String?`, `exercises: [WorkoutExercise]`, `var orderedExercises`.
  - `WorkoutExercise(exercise:exerciseID:order:targetSets:targetRepMin:targetRepMax:restSeconds:)` with `sets: [ExerciseSet]`, `var orderedSets`.
  - `ExerciseSet(order:weightKg:addedWeightKg:reps:rpe:isWarmup:)` with `isComplete: Bool`, `completedAt: Date?`.
  - `let forgeSchemaModels: [any PersistentModel.Type]` exported for the container.

- [ ] **Step 1: Write `BodyPart.swift`**

```swift
import Foundation

enum BodyPart: String, CaseIterable, Codable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, core
    case quads, hamstrings, glutes, calves, traps
    case cardio, fullBody, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody: "Full Body"
        default: rawValue.capitalized
        }
    }
}
```

- [ ] **Step 2: Write `WeightUnit.swift`**

```swift
import Foundation

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var displayName: String { rawValue }
}
```

- [ ] **Step 3: Write `Exercise.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Exercise {
    /// Stable identifier used by history queries and the ForgeCore mapping.
    /// `@Model` already provides `persistentModelID`, but an explicit `UUID`
    /// is stable across contexts and safe to use inside `#Predicate`.
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var primaryBodyPartRaw: String
    var isBodyweight: Bool
    var isUnilateral: Bool
    var defaultRestSeconds: Int?
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []

    init(
        name: String,
        primaryBodyPart: BodyPart,
        isBodyweight: Bool = false,
        isUnilateral: Bool = false,
        defaultRestSeconds: Int? = nil
    ) {
        self.name = name
        self.primaryBodyPartRaw = primaryBodyPart.rawValue
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
        self.defaultRestSeconds = defaultRestSeconds
        self.isArchived = false
        self.createdAt = .now
    }

    var primaryBodyPart: BodyPart {
        get { BodyPart(rawValue: primaryBodyPartRaw) ?? .other }
        set { primaryBodyPartRaw = newValue.rawValue }
    }
}
```

> Enums are stored as their raw `String` via a backing property + computed
> accessor. This is the most predictable option for `#Predicate` support and
> lightweight migration.

- [ ] **Step 4: Write `Routine.swift` and `RoutineItem.swift`**

`Routine.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var isArchived: Bool
    var createdAt: Date
    var lastPerformedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []

    init(name: String) {
        self.name = name
        self.isArchived = false
        self.createdAt = .now
        self.lastPerformedAt = nil
    }

    var orderedItems: [RoutineItem] {
        items.sorted { $0.order < $1.order }
    }
}
```

`RoutineItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class RoutineItem {
    var routine: Routine?
    var exercise: Exercise?
    var order: Int
    var targetSets: Int?
    var targetRepMin: Int?
    var targetRepMax: Int?
    var targetRestSeconds: Int?

    init(
        exercise: Exercise,
        order: Int,
        targetSets: Int? = nil,
        targetRepMin: Int? = nil,
        targetRepMax: Int? = nil,
        targetRestSeconds: Int? = nil
    ) {
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.targetRepMin = targetRepMin
        self.targetRepMax = targetRepMax
        self.targetRestSeconds = targetRestSeconds
    }
}
```

- [ ] **Step 5: Write `WorkoutSession.swift`, `WorkoutExercise.swift`, `ExerciseSet.swift`**

`WorkoutSession.swift`:

```swift
import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    var sourceRoutine: Routine?
    var sourceRoutineName: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise] = []

    init(startedAt: Date = .now, sourceRoutine: Routine?, sourceRoutineName: String) {
        self.startedAt = startedAt
        self.endedAt = nil
        self.sourceRoutine = sourceRoutine
        self.sourceRoutineName = sourceRoutineName
    }

    var isActive: Bool { endedAt == nil }

    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }
}
```

`WorkoutExercise.swift`:

```swift
import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    var session: WorkoutSession?
    var exercise: Exercise?
    /// Denormalised copy of `exercise.id` for predicate-friendly history queries.
    var exerciseID: UUID
    var order: Int
    var targetSets: Int?
    var targetRepMin: Int?
    var targetRepMax: Int?
    var restSeconds: Int?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    init(
        exercise: Exercise,
        exerciseID: UUID,
        order: Int,
        targetSets: Int? = nil,
        targetRepMin: Int? = nil,
        targetRepMax: Int? = nil,
        restSeconds: Int? = nil
    ) {
        self.exercise = exercise
        self.exerciseID = exerciseID
        self.order = order
        self.targetSets = targetSets
        self.targetRepMin = targetRepMin
        self.targetRepMax = targetRepMax
        self.restSeconds = restSeconds
    }

    var orderedSets: [ExerciseSet] {
        sets.sorted { $0.order < $1.order }
    }
}
```

> `exerciseID` is passed in explicitly (rather than read from `exercise.id`)
> so callers stay in control and tests can construct a `WorkoutExercise` without
> a fully-populated `Exercise`. In practice callers pass `exercise.id`.
>
> `Exercise` keeps its `routineItems` inverse (used by `ExerciseDeletion`), but
> `WorkoutExercise.exercise` is deliberately a one-way reference with **no**
> inverse collection on `Exercise` — history uses the denormalised `exerciseID`,
> so `Exercise` never needs a large to-many `workoutExercises` relationship. If
> SwiftData emits an "implicit inverse" warning at runtime, add a private
> `@Relationship(inverse: \WorkoutExercise.exercise) var workoutExercises: [WorkoutExercise] = []`
> to `Exercise`.

`ExerciseSet.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var workoutExercise: WorkoutExercise?
    var order: Int
    var weightKg: Double?
    var addedWeightKg: Double?
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var isComplete: Bool
    var completedAt: Date?

    init(
        order: Int,
        weightKg: Double? = nil,
        addedWeightKg: Double? = nil,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.order = order
        self.weightKg = weightKg
        self.addedWeightKg = addedWeightKg
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isComplete = false
        self.completedAt = nil
    }
}
```

- [ ] **Step 6: Export the schema list**

Create `Forge/Models/Schema.swift`:

```swift
import SwiftData

let forgeSchemaModels: [any PersistentModel.Type] = [
    Exercise.self, Routine.self, RoutineItem.self,
    WorkoutSession.self, WorkoutExercise.self, ExerciseSet.self,
]
```

- [ ] **Step 7: Build**

Run: `xcodegen generate && xcodebuild build -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: SwiftData models and enums for the M1 schema"
```

---

## Task 6: Persistence controller & app entry point

**Files:**
- Create: `Forge/App/PersistenceController.swift`
- Modify: `Forge/App/ForgeApp.swift`
- Test: `ForgeTests/PersistenceControllerTests.swift`

**Interfaces:**
- Consumes: `forgeSchemaModels` (Task 5).
- Produces:
  - `enum PersistenceController` with:
    - `static let appGroupID = "group.com.forge.gym"`
    - `static func makeSharedContainer() -> ModelContainer` — App Group store, crashes only on unrecoverable schema failure (documented).
    - `static func makeInMemoryContainer() -> ModelContainer` — for tests and previews.
  - `ForgeApp` attaches the shared container via `.modelContainer(_:)`.

- [ ] **Step 1: Write the failing test**

`ForgeTests/PersistenceControllerTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerInsertsAndFetches() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Back Squat", primaryBodyPart: .quads)
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Back Squat")
        #expect(fetched.first?.primaryBodyPart == .quads)
    }

    @Test func deletingASessionCascadesToExercisesAndSets() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Bench", primaryBodyPart: .chest)
        let session = WorkoutSession(sourceRoutine: nil, sourceRoutineName: "Ad hoc")
        let we = WorkoutExercise(exercise: exercise, exerciseID: exercise.id, order: 0)
        let set = ExerciseSet(order: 0, weightKg: 100, reps: 5)
        we.sets.append(set)
        session.exercises.append(we)
        context.insert(exercise)
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<WorkoutExercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1) // exercise survives
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/PersistenceControllerTests -quiet`
Expected: FAIL — `PersistenceController` undefined.

- [ ] **Step 3: Implement `PersistenceController.swift`**

```swift
import Foundation
import SwiftData

/// Builds the app's SwiftData containers.
///
/// The production store lives in the App Group container so the widget
/// extension (M3) can open the same database without a migration.
enum PersistenceController {
    static let appGroupID = "group.com.forge.gym"

    /// The shared, on-disk container. A failure here means the schema itself
    /// is unopenable — there is no safe way to continue, so we trap.
    static func makeSharedContainer() -> ModelContainer {
        let schema = Schema(forgeSchemaModels)
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group \(appGroupID) is not provisioned. Check the entitlement and signing.")
        }
        let configuration = ModelConfiguration(
            schema: schema,
            url: groupURL.appending(path: "Forge.store")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the Forge store: \(error)")
        }
    }

    /// A throwaway in-memory container for tests and SwiftUI previews.
    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(forgeSchemaModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not build the in-memory container: \(error)")
        }
    }
}
```

- [ ] **Step 4: Wire it into `ForgeApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container = PersistenceController.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/PersistenceControllerTests -quiet`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Launch the app to confirm the App Group store opens**

Run: `xcodebuild build -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`, then use the iOS Simulator tools to boot `iPhone 17`, install, and launch. Confirm it does not crash on the `fatalError` paths.

> If the App Group is not provisioned on the free tier, Xcode's automatic
> signing normally adds it on first build. If `containerURL(...)` still returns
> `nil` in the simulator, open the project in Xcode once (Signing & Capabilities
> → App Groups shows `group.com.forge.gym`) and rebuild.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: App Group and in-memory SwiftData containers"
```

---

## Task 7: Model ↔ ForgeCore mapping

**Files:**
- Create: `Forge/Persistence/ModelMapping.swift`
- Test: `ForgeTests/ModelMappingTests.swift`

**Interfaces:**
- Consumes: models (Task 5), `ForgeCore` input types (Task 2).
- Produces:
  - `extension Exercise { var coreInput: ExerciseInput }`
  - `extension ExerciseSet { var coreInput: SetInput }`
  - `extension WorkoutExercise { var coreInput: WorkoutExerciseInput }`
  - `extension WorkoutSession { var coreInput: SessionInput }`

- [ ] **Step 1: Write the failing test**

`ForgeTests/ModelMappingTests.swift`:

```swift
import Testing
import SwiftData
import ForgeCore
@testable import Forge

@Suite @MainActor
struct ModelMappingTests {
    @Test func sessionMapsToCoreInputWithOrderedExercisesAndSets() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        let squat = Exercise(name: "Squat", primaryBodyPart: .quads, isUnilateral: false)
        context.insert(squat)

        let session = WorkoutSession(startedAt: .now, sourceRoutine: nil, sourceRoutineName: "Legs")
        let we = WorkoutExercise(exercise: squat, exerciseID: squat.id, order: 0)
        let warm = ExerciseSet(order: 0, weightKg: 60, reps: 8, isWarmup: true)
        let work = ExerciseSet(order: 1, weightKg: 120, reps: 5)
        work.isComplete = true
        we.sets = [work, warm]                // deliberately out of order
        session.exercises = [we]
        context.insert(session)
        try context.save()

        let input = session.coreInput
        #expect(input.exercises.count == 1)
        #expect(input.exercises[0].sets.map(\.reps) == [8, 5])   // reordered by `order`
        #expect(input.exercises[0].sets[0].isWarmup == true)
        #expect(input.exercises[0].exercise.id == squat.id)
        #expect(sessionVolumeKg(input) == 600)                   // only the working set
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `ModelMapping.swift`**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/ModelMappingTests -quiet` → FAIL.

```swift
import Foundation
import ForgeCore

extension Exercise {
    var coreInput: ExerciseInput {
        ExerciseInput(id: id, isBodyweight: isBodyweight, isUnilateral: isUnilateral)
    }
}

extension ExerciseSet {
    var coreInput: SetInput {
        SetInput(
            weightKg: weightKg,
            addedWeightKg: addedWeightKg,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup,
            isComplete: isComplete
        )
    }
}

extension WorkoutExercise {
    /// Uses the live `exercise` relationship for flags; falls back to a plain
    /// non-bodyweight exercise if the relationship is somehow missing.
    var coreInput: WorkoutExerciseInput {
        let exerciseInput = exercise?.coreInput
            ?? ExerciseInput(id: exerciseID, isBodyweight: false, isUnilateral: false)
        return WorkoutExerciseInput(
            exercise: exerciseInput,
            sets: orderedSets.map(\.coreInput)
        )
    }
}

extension WorkoutSession {
    var coreInput: SessionInput {
        SessionInput(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            exercises: orderedExercises.map(\.coreInput)
        )
    }
}
```

- [ ] **Step 3: Run the test**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/ModelMappingTests -quiet`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: map SwiftData models to ForgeCore inputs"
```

---

## Task 8: Seed exercise data

**Files:**
- Create: `Forge/Persistence/SeedData.swift`
- Modify: `Forge/App/PersistenceController.swift` (add `seedIfEmpty(_:)`), `Forge/App/ForgeApp.swift` (call it on launch)
- Test: `ForgeTests/SeedDataTests.swift`

**Interfaces:**
- Consumes: `Exercise` (Task 5), containers (Task 6).
- Produces:
  - `struct SeedExercise { let name: String; let bodyPart: BodyPart; let isBodyweight: Bool; let isUnilateral: Bool }`
  - `let seedExercises: [SeedExercise]` — the PRD Appendix A catalogue (40 entries).
  - `PersistenceController.seedIfEmpty(_ context: ModelContext)` — inserts the catalogue only when no `Exercise` rows exist.

- [ ] **Step 1: Write the failing test**

`ForgeTests/SeedDataTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct SeedDataTests {
    @Test func seedsAFreshStore() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        PersistenceController.seedIfEmpty(context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())

        #expect(exercises.count == seedExercises.count)
        #expect(exercises.contains { $0.name == "Barbell Bench Press" })
        #expect(exercises.first { $0.name == "Pull-up" }?.isBodyweight == true)
        #expect(exercises.first { $0.name == "Bulgarian Split Squat" }?.isUnilateral == true)
    }

    @Test func seedingIsIdempotent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        PersistenceController.seedIfEmpty(context)
        PersistenceController.seedIfEmpty(context)

        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == seedExercises.count)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/SeedDataTests -quiet`
Expected: FAIL.

- [ ] **Step 3: Implement `SeedData.swift`**

Transcribe PRD Appendix A. Full list (name — bodyPart — flags):

```swift
import Foundation

struct SeedExercise {
    let name: String
    let bodyPart: BodyPart
    let isBodyweight: Bool
    let isUnilateral: Bool

    init(_ name: String, _ bodyPart: BodyPart, bodyweight: Bool = false, unilateral: Bool = false) {
        self.name = name
        self.bodyPart = bodyPart
        self.isBodyweight = bodyweight
        self.isUnilateral = unilateral
    }
}

let seedExercises: [SeedExercise] = [
    // Chest
    .init("Barbell Bench Press", .chest),
    .init("Incline Dumbbell Press", .chest),
    .init("Machine Chest Press", .chest),
    .init("Cable Fly", .chest),
    .init("Push-up", .chest, bodyweight: true),
    // Back
    .init("Deadlift", .back),
    .init("Barbell Row", .back),
    .init("Lat Pulldown", .back),
    .init("Seated Cable Row", .back),
    .init("Pull-up", .back, bodyweight: true),
    .init("Chin-up", .back, bodyweight: true),
    .init("Single-arm Dumbbell Row", .back, unilateral: true),
    // Shoulders
    .init("Overhead Press", .shoulders),
    .init("Seated Dumbbell Shoulder Press", .shoulders),
    .init("Lateral Raise", .shoulders),
    .init("Rear Delt Fly", .shoulders),
    .init("Face Pull", .shoulders),
    // Biceps
    .init("Barbell Curl", .biceps),
    .init("Dumbbell Curl", .biceps),
    .init("Hammer Curl", .biceps),
    .init("Cable Curl", .biceps),
    // Triceps
    .init("Close-grip Bench Press", .triceps),
    .init("Triceps Pushdown", .triceps),
    .init("Overhead Cable Extension", .triceps),
    .init("Dip", .triceps, bodyweight: true),
    // Quads
    .init("Back Squat", .quads),
    .init("Front Squat", .quads),
    .init("Leg Press", .quads),
    .init("Leg Extension", .quads),
    .init("Walking Lunge", .quads, unilateral: true),
    .init("Bulgarian Split Squat", .quads, unilateral: true),
    // Hamstrings / glutes
    .init("Romanian Deadlift", .hamstrings),
    .init("Lying Leg Curl", .hamstrings),
    .init("Hip Thrust", .glutes),
    .init("Back Extension", .hamstrings, bodyweight: true),
    // Calves
    .init("Standing Calf Raise", .calves),
    .init("Seated Calf Raise", .calves),
    // Core
    .init("Hanging Leg Raise", .core, bodyweight: true),
    .init("Cable Crunch", .core),
    .init("Plank", .core, bodyweight: true),
]
```

- [ ] **Step 4: Add `seedIfEmpty` to `PersistenceController`**

```swift
extension PersistenceController {
    /// Inserts the starter exercise catalogue if the store has no exercises yet.
    @MainActor
    static func seedIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existing == 0 else { return }

        for seed in seedExercises {
            context.insert(Exercise(
                name: seed.name,
                primaryBodyPart: seed.bodyPart,
                isBodyweight: seed.isBodyweight,
                isUnilateral: seed.isUnilateral
            ))
        }
        try? context.save()
    }
}
```

- [ ] **Step 5: Call it on launch**

In `ForgeApp.swift`:

```swift
var body: some Scene {
    WindowGroup {
        RootView()
            .task { PersistenceController.seedIfEmpty(container.mainContext) }
    }
    .modelContainer(container)
}
```

- [ ] **Step 6: Run the tests, then the full suites**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/SeedDataTests -quiet` → PASS.
Run: `cd Packages/ForgeCore && swift test` → PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: seed the starter exercise catalogue on first launch"
```

---

## Task 9: App shell — tabs, preferences, weight formatting

**Files:**
- Create: `Forge/Preferences/Preferences.swift`, `Forge/Preferences/WeightFormatting.swift`, `Forge/Settings/SettingsView.swift`, `Forge/Shared/RelativeDateText.swift`
- Modify: `Forge/App/RootView.swift`
- Test: `ForgeTests/WeightFormattingTests.swift`

**Interfaces:**
- Consumes: `WeightUnit` (Task 5).
- Produces:
  - `enum Preferences` with `static var weightUnit: WeightUnit { get set }` and `static var defaultRestSeconds: Int { get set }`, backed by `UserDefaults(suiteName: PersistenceController.appGroupID)`.
  - `struct WeightFormatting`:
    - `static func display(_ kg: Double, unit: WeightUnit, fractionDigits: Int = 1) -> String` → e.g. `"100 kg"`, `"225 lb"`.
    - `static func kilograms(from input: Double, unit: WeightUnit) -> Double` → converts entered value to kg.
    - `static func editableValue(_ kg: Double, unit: WeightUnit) -> Double` → kg shown in the user's unit for editing.
  - `RootView` shows the 3 M1 tabs: **Workout**, **History**, **Settings**.

> **M1 tab-bar note (refinement of PRD §7):** M1 ships three tabs. **Progress**
> and **Dashboard** arrive in M2. This avoids shipping placeholder tabs.

- [ ] **Step 1: Write the failing test**

`ForgeTests/WeightFormattingTests.swift`:

```swift
import Testing
@testable import Forge

@Suite struct WeightFormattingTests {
    @Test func displaysKilogramsWithoutTrailingZeros() {
        #expect(WeightFormatting.display(100, unit: .kg) == "100 kg")
        #expect(WeightFormatting.display(102.5, unit: .kg) == "102.5 kg")
    }

    @Test func displaysPoundsConvertedFromKilograms() {
        // 100 kg -> 220.462 lb -> "220.5 lb"
        #expect(WeightFormatting.display(100, unit: .lb) == "220.5 lb")
    }

    @Test func convertsEnteredPoundsToKilogramsForStorage() {
        #expect(abs(WeightFormatting.kilograms(from: 225, unit: .lb) - 102.058) < 0.001)
        #expect(WeightFormatting.kilograms(from: 100, unit: .kg) == 100)
    }

    @Test func editableValueRoundTripsWithinUnit() {
        let kg = WeightFormatting.kilograms(from: 135, unit: .lb)
        #expect(abs(WeightFormatting.editableValue(kg, unit: .lb) - 135) < 0.01)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement**

`Preferences/WeightFormatting.swift`:

```swift
import Foundation

enum WeightFormatting {
    private static let kgPerLb = 0.45359237

    static func display(_ kg: Double, unit: WeightUnit, fractionDigits: Int = 1) -> String {
        let value = editableValue(kg, unit: unit)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: value as NSNumber) ?? "\(value)"
        return "\(number) \(unit.rawValue)"
    }

    static func kilograms(from input: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: input
        case .lb: input * kgPerLb
        }
    }

    static func editableValue(_ kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: kg
        case .lb: kg / kgPerLb
        }
    }
}
```

`Preferences/Preferences.swift`:

```swift
import Foundation

enum Preferences {
    private static let store = UserDefaults(suiteName: PersistenceController.appGroupID)
        ?? .standard

    private enum Key {
        static let weightUnit = "weightUnit"
        static let defaultRestSeconds = "defaultRestSeconds"
    }

    static var weightUnit: WeightUnit {
        get { store.string(forKey: Key.weightUnit).flatMap(WeightUnit.init) ?? .kg }
        set { store.set(newValue.rawValue, forKey: Key.weightUnit) }
    }

    static var defaultRestSeconds: Int {
        get {
            let stored = store.integer(forKey: Key.defaultRestSeconds)
            return stored == 0 ? 120 : stored
        }
        set { store.set(newValue, forKey: Key.defaultRestSeconds) }
    }
}
```

- [ ] **Step 3: Write `SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
    @State private var weightUnit = Preferences.weightUnit
    @State private var restSeconds = Preferences.defaultRestSeconds

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Rest timer") {
                    Stepper("Default rest: \(restSeconds)s", value: $restSeconds, in: 30...600, step: 15)
                }
                Section {
                    NavigationLink("Manage exercises") { ExerciseLibraryView() }
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("Free personal signing: don't delete the app. Re-run from Xcode (⌘R) when it stops launching.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: weightUnit) { Preferences.weightUnit = weightUnit }
            .onChange(of: restSeconds) { Preferences.defaultRestSeconds = restSeconds }
        }
    }
}
```

> `ExerciseLibraryView` is created in Task 10. Until then, temporarily point the
> `NavigationLink` at `Text("Exercises")` so this task builds; Task 10 swaps it.

- [ ] **Step 4: Write `Shared/RelativeDateText.swift`**

```swift
import SwiftUI

/// "2 days ago" / "Today" / "Never" — used on routine rows and history.
struct RelativeDateText: View {
    let date: Date?
    var prefix: String = ""

    var body: some View {
        Text(formatted)
    }

    private var formatted: String {
        guard let date else { return "\(prefix)Never".trimmingCharacters(in: .whitespaces) }
        if Calendar.current.isDateInToday(date) { return "\(prefix)Today".trimmingCharacters(in: .whitespaces) }
        let style = RelativeDateTimeFormatter()
        style.unitsStyle = .full
        return "\(prefix)\(style.localizedString(for: date, relativeTo: .now))"
    }
}
```

- [ ] **Step 5: Update `RootView.swift`**

```swift
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
```

> `RoutineListView` and `HistoryListView` come in Tasks 11 and 18. Temporarily
> use `Text("Workout")` / `Text("History")` so this task builds; the later tasks
> swap them in.

- [ ] **Step 6: Run tests and build**

Run: `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ForgeTests/WeightFormattingTests -quiet` → PASS.
Run: `xcodebuild build -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` → `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: app shell, App Group preferences, weight formatting"
```

---

## Task 10: Exercise library — list & editor

**Files:**
- Create: `Forge/Features/ExerciseLibrary/ExerciseLibraryView.swift`, `Forge/Features/ExerciseLibrary/ExerciseEditorView.swift`, `Forge/Features/ExerciseLibrary/ExerciseDeletion.swift`
- Modify: `Forge/Settings/SettingsView.swift` (point `NavigationLink` at the real view)
- Test: `ForgeTests/ExerciseDeletionTests.swift`

**Interfaces:**
- Consumes: `Exercise`, containers, `BodyPart`.
- Produces:
  - `enum ExerciseDeletion { static func canHardDelete(_ exercise: Exercise) -> Bool }` — `true` only when the exercise is referenced by no routine item and no workout exercise.
  - `ExerciseLibraryView` — `@Query` of non-archived exercises, grouped by body part, searchable, with an add button and swipe actions (Edit / Archive / Delete).
  - `ExerciseEditorView(exercise: Exercise?)` — create (nil) or edit; writes to the context on save.

- [ ] **Step 1: Write the failing test**

`ForgeTests/ExerciseDeletionTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct ExerciseDeletionTests {
    @Test func unreferencedExerciseCanBeHardDeleted() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let ex = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(ex)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == true)
    }

    @Test func exerciseUsedByARoutineCannotBeHardDeleted() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let ex = Exercise(name: "Squat", primaryBodyPart: .quads)
        let routine = Routine(name: "Legs")
        let item = RoutineItem(exercise: ex, order: 0)
        routine.items.append(item)
        ctx.insert(ex); ctx.insert(routine)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == false)
    }

    @Test func exerciseUsedByAPastWorkoutCannotBeHardDeleted() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let ex = Exercise(name: "Bench", primaryBodyPart: .chest)
        let session = WorkoutSession(sourceRoutine: nil, sourceRoutineName: "x")
        let we = WorkoutExercise(exercise: ex, exerciseID: ex.id, order: 0)
        session.exercises.append(we)
        ctx.insert(ex); ctx.insert(session)
        try ctx.save()
        #expect(ExerciseDeletion.canHardDelete(ex) == false)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `ExerciseDeletion.swift`**

```swift
import Foundation
import SwiftData

/// Rule from PRD §5: an exercise referenced by history is archived, not deleted.
enum ExerciseDeletion {
    static func canHardDelete(_ exercise: Exercise) -> Bool {
        exercise.routineItems.isEmpty && workoutExerciseCount(for: exercise) == 0
    }

    private static func workoutExerciseCount(for exercise: Exercise) -> Int {
        guard let context = exercise.modelContext else { return 0 }
        let id = exercise.id
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate { $0.exerciseID == id }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
```

- [ ] **Step 3: Run the test → PASS. Then write `ExerciseEditorView.swift`**

```swift
import SwiftUI
import SwiftData

struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil → creating a new exercise.
    let exercise: Exercise?

    @State private var name: String
    @State private var bodyPart: BodyPart
    @State private var isBodyweight: Bool
    @State private var isUnilateral: Bool
    @State private var usesCustomRest: Bool
    @State private var restSeconds: Int

    init(exercise: Exercise?) {
        self.exercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _bodyPart = State(initialValue: exercise?.primaryBodyPart ?? .chest)
        _isBodyweight = State(initialValue: exercise?.isBodyweight ?? false)
        _isUnilateral = State(initialValue: exercise?.isUnilateral ?? false)
        _usesCustomRest = State(initialValue: exercise?.defaultRestSeconds != nil)
        _restSeconds = State(initialValue: exercise?.defaultRestSeconds ?? 120)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Body part", selection: $bodyPart) {
                    ForEach(BodyPart.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section {
                Toggle("Bodyweight exercise", isOn: $isBodyweight)
                Toggle("Unilateral (counts volume ×2)", isOn: $isUnilateral)
            } footer: {
                Text(isBodyweight
                     ? "Only reps are logged; added weight is optional."
                     : "Weight and reps are logged.")
            }
            Section("Rest") {
                Toggle("Custom default rest", isOn: $usesCustomRest)
                if usesCustomRest {
                    Stepper("\(restSeconds)s", value: $restSeconds, in: 30...600, step: 15)
                }
            }
        }
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(!canSave)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target = exercise ?? {
            let new = Exercise(name: trimmed, primaryBodyPart: bodyPart)
            context.insert(new)
            return new
        }()
        target.name = trimmed
        target.primaryBodyPart = bodyPart
        target.isBodyweight = isBodyweight
        target.isUnilateral = isUnilateral
        target.defaultRestSeconds = usesCustomRest ? restSeconds : nil
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { ExerciseEditorView(exercise: nil) }
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
```

- [ ] **Step 4: Write `ExerciseLibraryView.swift`**

```swift
import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var search = ""
    @State private var editing: Exercise?
    @State private var creating = false
    @State private var deleteError: String?

    private var filtered: [Exercise] {
        guard !search.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(BodyPart, [Exercise])] {
        Dictionary(grouping: filtered, by: \.primaryBodyPart)
            .sorted { $0.key.displayName < $1.key.displayName }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { bodyPart, items in
                Section(bodyPart.displayName) {
                    ForEach(items) { exercise in
                        Button { editing = exercise } label: { row(exercise) }
                            .tint(.primary)
                            .swipeActions(edge: .trailing) {
                                Button("Archive", systemImage: "archivebox") {
                                    exercise.isArchived = true
                                    try? context.save()
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(exercise)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $search)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { creating = true }
            }
        }
        .sheet(item: $editing) { exercise in
            NavigationStack { ExerciseEditorView(exercise: exercise) }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { ExerciseEditorView(exercise: nil) }
        }
        .alert("Can't delete", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private func row(_ exercise: Exercise) -> some View {
        HStack {
            Text(exercise.name)
            Spacer()
            if exercise.isBodyweight { Tag("BW") }
            if exercise.isUnilateral { Tag("×2") }
        }
    }

    private func delete(_ exercise: Exercise) {
        guard ExerciseDeletion.canHardDelete(exercise) else {
            deleteError = "\(exercise.name) is used by a routine or a past workout. Archive it instead."
            return
        }
        context.delete(exercise)
        try? context.save()
    }
}

private struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

#Preview {
    NavigationStack { ExerciseLibraryView() }
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
```

- [ ] **Step 5: Point Settings at the real view**

In `SettingsView.swift` change the link to `NavigationLink("Manage exercises") { ExerciseLibraryView() }` (remove the temporary placeholder).

- [ ] **Step 6: Build, and visually verify in the Simulator**

Run: `xcodebuild build -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`.
Then boot `iPhone 17`, install, launch. In Settings → Manage exercises: confirm the seeded catalogue lists grouped by body part; add "Landmine Press" (Shoulders); edit it; archive it; try to delete "Back Squat" (should be allowed — not yet referenced).

- [ ] **Step 7: Run all suites and commit**

Run: `cd Packages/ForgeCore && swift test` and `xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` → PASS.

```bash
git add -A
git commit -m "feat: exercise library list and editor"
```

---

## Task 11: Routines — list, duplicate, delete/archive

**Files:**
- Create: `Forge/Features/Routines/RoutineListView.swift`, `Forge/Features/Routines/RoutineRow.swift`, `Forge/Features/Routines/RoutineDuplication.swift`
- Modify: `Forge/App/RootView.swift` (use the real `RoutineListView`)
- Test: `ForgeTests/RoutineDuplicationTests.swift`

**Interfaces:**
- Consumes: `Routine`, `RoutineItem`, `Exercise`.
- Produces:
  - `enum RoutineDuplication { static func duplicate(_ routine: Routine, into context: ModelContext) -> Routine }` — deep-copies the routine and its items (new `Routine`, new `RoutineItem`s, same `Exercise` references), name suffixed " Copy", `lastPerformedAt` reset to nil.
  - `RoutineListView` — `@Query` of non-archived routines sorted by `name`; row shows name, exercise count, last-performed; a **Start** button; swipe actions Edit / Duplicate / Delete.
  - Navigation: tapping the row body pushes `RoutineDetailView` (Task 13); **Start** also goes through `RoutineDetailView`'s start path in M1 (keep one start path).

- [ ] **Step 1: Write the failing test**

`ForgeTests/RoutineDuplicationTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct RoutineDuplicationTests {
    @Test func deepCopiesItemsAndKeepsExerciseReferences() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(squat); ctx.insert(curl)

        let original = Routine(name: "Legs & Arms")
        original.items = [
            RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5),
            RoutineItem(exercise: curl, order: 1, targetSets: 3, targetRepMin: 8, targetRepMax: 12),
        ]
        original.lastPerformedAt = .now
        ctx.insert(original)
        try ctx.save()

        let copy = RoutineDuplication.duplicate(original, into: ctx)
        try ctx.save()

        #expect(copy.name == "Legs & Arms Copy")
        #expect(copy.lastPerformedAt == nil)
        #expect(copy.orderedItems.count == 2)
        #expect(copy.orderedItems[0].exercise === squat)          // same reference
        #expect(copy.orderedItems[0].targetSets == 3)
        #expect(copy.orderedItems[1].targetRepMax == 12)
        #expect(original.orderedItems[0] !== copy.orderedItems[0]) // distinct items
        #expect(try ctx.fetch(FetchDescriptor<Routine>()).count == 2)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `RoutineDuplication.swift`**

```swift
import Foundation
import SwiftData

enum RoutineDuplication {
    @MainActor
    static func duplicate(_ routine: Routine, into context: ModelContext) -> Routine {
        let copy = Routine(name: routine.name + " Copy")
        context.insert(copy)
        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }
            let newItem = RoutineItem(
                exercise: exercise,
                order: item.order,
                targetSets: item.targetSets,
                targetRepMin: item.targetRepMin,
                targetRepMax: item.targetRepMax,
                targetRestSeconds: item.targetRestSeconds
            )
            copy.items.append(newItem)
        }
        return copy
    }
}
```

- [ ] **Step 3: Write `RoutineRow.swift`**

```swift
import SwiftUI

struct RoutineRow: View {
    let routine: Routine
    let onStart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name).font(.headline)
                HStack(spacing: 6) {
                    Text("\(routine.orderedItems.count) exercises")
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
        }
    }
}
```

- [ ] **Step 4: Write `RoutineListView.swift`**

```swift
import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Routine> { !$0.isArchived }, sort: \Routine.name)
    private var routines: [Routine]

    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false
    @State private var startTarget: Routine?

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No routines yet", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a routine to start logging workouts.")
                    } actions: {
                        Button("New Routine") { creatingRoutine = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(routine: routine) { startTarget = routine }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Edit", systemImage: "pencil") { editingRoutine = routine }
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    _ = RoutineDuplication.duplicate(routine, into: context)
                                    try? context.save()
                                }.tint(.indigo)
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteOrArchive(routine)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Routine", systemImage: "plus") { creatingRoutine = true }
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .navigationDestination(item: $startTarget) { routine in
                RoutineDetailView(routine: routine, autoStart: true)
            }
            .sheet(item: $editingRoutine) { routine in
                NavigationStack { RoutineEditorView(routine: routine) }
            }
            .sheet(isPresented: $creatingRoutine) {
                NavigationStack { RoutineEditorView(routine: nil) }
            }
        }
    }

    private func deleteOrArchive(_ routine: Routine) {
        // Predicates over optional relationships are unreliable in SwiftData;
        // the finished-session count is small, so filter in Swift.
        let allSessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let isReferenced = allSessions.contains { $0.sourceRoutine?.id == routine.id }
        if isReferenced {
            routine.isArchived = true
        } else {
            context.delete(routine)
        }
        try? context.save()
    }
}
```

> This references `RoutineEditorView` (Task 12) and `RoutineDetailView` (Task 13).
> To keep this task independently buildable, add **minimal stub files** for both
> now (`struct RoutineEditorView: View { let routine: Routine?; var body: some View { Text("Editor") } }`
> and `struct RoutineDetailView: View { let routine: Routine; var autoStart = false; var body: some View { Text(routine.name) } }`)
> and flesh them out in their tasks. Note the stubs in the commit message.

- [ ] **Step 5: Add `id` to `Routine`**

`Routine` needs a stable identifier to compare against `WorkoutSession.sourceRoutine`
in `deleteOrArchive` (and for `$startTarget` / `navigationDestination(item:)`,
which requires `Identifiable`). Add `@Attribute(.unique) var id: UUID = UUID()` to
`Routine.swift`. `@Model` types are already `Identifiable` via `persistentModelID`,
but an explicit `UUID` is stable across contexts and predicate-friendly.

- [ ] **Step 6: Use the real list in `RootView`**

Replace the temporary `Text("Workout")` with `RoutineListView()`. Remove the outer `NavigationStack` from `RootView` if present — `RoutineListView` owns its own.

- [ ] **Step 7: Build, verify, run suites, commit**

Run build + both test suites → PASS. Visually: create a routine (empty via stub editor is fine), duplicate it, delete it.

```bash
git add -A
git commit -m "feat: routine list with duplicate and delete/archive (editor/detail stubbed)"
```

---

## Task 12: Routines — editor (items, targets, reorder)

**Files:**
- Create: `Forge/Features/Routines/RoutineEditorView.swift` (replace stub), `Forge/Features/Routines/RoutineItemEditorView.swift`, `Forge/Shared/RepRange.swift`
- Create: `Forge/Features/Routines/ExercisePickerView.swift`

**Interfaces:**
- Consumes: `Routine`, `RoutineItem`, `Exercise`, `ExerciseEditorView` (Task 10).
- Produces:
  - `enum RepRange { static func label(min: Int?, max: Int?) -> String? }` → `"8–12"`, `"5"`, or `nil`.
  - `RoutineEditorView(routine: Routine?)` — name field; ordered item list with drag-to-reorder and delete; "Add exercise" → `ExercisePickerView`; tap an item → `RoutineItemEditorView`. Creates the `Routine` on first save when `routine == nil`.
  - `ExercisePickerView(onPick: (Exercise) -> Void)` — searchable list of non-archived exercises + "New exercise" (reuses `ExerciseEditorView`).
  - `RoutineItemEditorView(item: RoutineItem)` — optional target sets / rep min / rep max / rest override, edited in place.

- [ ] **Step 1: Write `RepRange.swift` with a quick test**

Add to `ForgeCore`? No — it is display only, keep in the app. Add a test in `ForgeTests/RepRangeTests.swift`:

```swift
import Testing
@testable import Forge

@Suite struct RepRangeTests {
    @Test func formatsRanges() {
        #expect(RepRange.label(min: 8, max: 12) == "8–12")
        #expect(RepRange.label(min: 5, max: 5) == "5")
        #expect(RepRange.label(min: nil, max: nil) == nil)
        #expect(RepRange.label(min: 6, max: nil) == "6+")
        #expect(RepRange.label(min: nil, max: 10) == "≤10")
    }
}
```

Implementation:

```swift
import Foundation

enum RepRange {
    static func label(min: Int?, max: Int?) -> String? {
        switch (min, max) {
        case let (m?, x?) where m == x: "\(m)"
        case let (m?, x?): "\(m)–\(x)"
        case let (m?, nil): "\(m)+"
        case let (nil, x?): "≤\(x)"
        case (nil, nil): nil
        }
    }
}
```

- [ ] **Step 2: Run the test → PASS. Then write `ExercisePickerView.swift`**

```swift
import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var search = ""
    @State private var creating = false

    let onPick: (Exercise) -> Void

    private var filtered: [Exercise] {
        search.isEmpty ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Button("New exercise", systemImage: "plus") { creating = true }
            ForEach(filtered) { exercise in
                Button(exercise.name) {
                    onPick(exercise)
                    dismiss()
                }
                .tint(.primary)
            }
        }
        .searchable(text: $search)
        .navigationTitle("Add Exercise")
        .sheet(isPresented: $creating) {
            NavigationStack { ExerciseEditorView(exercise: nil) }
        }
    }
}
```

- [ ] **Step 3: Write `RoutineItemEditorView.swift`**

```swift
import SwiftUI

struct RoutineItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: RoutineItem

    @State private var setsEnabled: Bool
    @State private var sets: Int
    @State private var repsEnabled: Bool
    @State private var repMin: Int
    @State private var repMax: Int
    @State private var restEnabled: Bool
    @State private var rest: Int

    init(item: RoutineItem) {
        self.item = item
        _setsEnabled = State(initialValue: item.targetSets != nil)
        _sets = State(initialValue: item.targetSets ?? 3)
        _repsEnabled = State(initialValue: item.targetRepMin != nil || item.targetRepMax != nil)
        _repMin = State(initialValue: item.targetRepMin ?? 8)
        _repMax = State(initialValue: item.targetRepMax ?? 12)
        _restEnabled = State(initialValue: item.targetRestSeconds != nil)
        _rest = State(initialValue: item.targetRestSeconds ?? 120)
    }

    var body: some View {
        Form {
            Section("Target sets") {
                Toggle("Set a target", isOn: $setsEnabled)
                if setsEnabled { Stepper("\(sets) sets", value: $sets, in: 1...10) }
            }
            Section("Target reps") {
                Toggle("Set a target", isOn: $repsEnabled)
                if repsEnabled {
                    Stepper("Min \(repMin)", value: $repMin, in: 1...30)
                    Stepper("Max \(repMax)", value: $repMax, in: repMin...50)
                }
            }
            Section("Rest override") {
                Toggle("Override exercise default", isOn: $restEnabled)
                if restEnabled { Stepper("\(rest)s", value: $rest, in: 30...600, step: 15) }
            }
        }
        .navigationTitle(item.exercise?.name ?? "Exercise")
        .onDisappear(perform: persist)
    }

    private func persist() {
        item.targetSets = setsEnabled ? sets : nil
        item.targetRepMin = repsEnabled ? repMin : nil
        item.targetRepMax = repsEnabled ? repMax : nil
        item.targetRestSeconds = restEnabled ? rest : nil
        try? context.save()
    }
}
```

- [ ] **Step 4: Write `RoutineEditorView.swift`**

```swift
import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let routine: Routine?

    @State private var name: String
    @State private var draft: Routine?      // the live routine being edited
    @State private var pickingExercise = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _draft = State(initialValue: routine)
    }

    private var items: [RoutineItem] { draft?.orderedItems ?? [] }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section { TextField("Routine name", text: $name) }

            Section("Exercises") {
                ForEach(items) { item in
                    NavigationLink {
                        RoutineItemEditorView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise?.name ?? "—")
                            if let target = targetLabel(item) {
                                Text(target).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button("Add exercise", systemImage: "plus") { pickingExercise = true }
            }
        }
        .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!canSave)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }
        }
        .environment(\.editMode, .constant(.active))   // always allow reorder
        .sheet(isPresented: $pickingExercise) {
            NavigationStack {
                ExercisePickerView { exercise in addExercise(exercise) }
            }
        }
    }

    private func targetLabel(_ item: RoutineItem) -> String? {
        let reps = RepRange.label(min: item.targetRepMin, max: item.targetRepMax)
        switch (item.targetSets, reps) {
        case let (s?, r?): return "\(s) × \(r)"
        case let (s?, nil): return "\(s) sets"
        case let (nil, r?): return "reps \(r)"
        case (nil, nil): return nil
        }
    }

    private func ensureDraft() -> Routine {
        if let draft { return draft }
        let new = Routine(name: name)
        context.insert(new)
        draft = new
        return new
    }

    private func addExercise(_ exercise: Exercise) {
        let routine = ensureDraft()
        let item = RoutineItem(exercise: exercise, order: routine.items.count)
        routine.items.append(item)
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.order = index }
    }

    private func delete(_ offsets: IndexSet) {
        let ordered = items
        for index in offsets { context.delete(ordered[index]) }
        for (index, item) in items.enumerated() { item.order = index }
    }

    private func save() {
        let routine = ensureDraft()
        routine.name = name.trimmingCharacters(in: .whitespaces)
        try? context.save()
        dismiss()
    }

    private func cancel() {
        // If we created a brand-new routine in this session, roll it back.
        if routine == nil, let draft {
            context.delete(draft)
            try? context.save()
        }
        dismiss()
    }
}

#Preview {
    NavigationStack { RoutineEditorView(routine: nil) }
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
```

- [ ] **Step 5: Build & verify in Simulator**

Create a "Push" routine: add Barbell Bench Press (3 × 5–8), Overhead Press, Triceps Pushdown; reorder; set targets; save. Reopen to confirm persistence. Cancel a new routine and confirm it does not appear.

- [ ] **Step 6: Run suites and commit**

```bash
git add -A
git commit -m "feat: routine editor with items, targets, and reordering"
```

---

## Task 13: Routine detail & start workout

**Files:**
- Create: `Forge/Features/Workout/WorkoutController.swift`, `Forge/Features/Routines/RoutineDetailView.swift` (replace stub)
- Test: `ForgeTests/WorkoutControllerTests.swift`

**Interfaces:**
- Consumes: models, `ForgeCore` mapping.
- Produces:
  - `@Observable @MainActor final class WorkoutController`:
    - `init(context: ModelContext)`
    - `private(set) var activeSession: WorkoutSession?`
    - `var hasActiveSession: Bool`
    - `enum WorkoutError: Error { case sessionAlreadyActive }`
    - `func start(from routine: Routine) throws -> WorkoutSession`
    - `func addExercise(_ exercise: Exercise, to session: WorkoutSession)`
    - `@discardableResult func addSet(to workoutExercise: WorkoutExercise, weightKg: Double?, addedWeightKg: Double?, reps: Int, rpe: Double?, isWarmup: Bool) -> ExerciseSet`
    - `func toggleComplete(_ set: ExerciseSet)`
    - `func finish(_ session: WorkoutSession, history: [WorkoutSession]) -> WorkoutSummary` (summary type in Task 17 — for this task, `finish` just stamps `endedAt` + `lastPerformedAt` and returns `Void`; Task 17 changes the return type)
    - `func discard(_ session: WorkoutSession)`
  - `RoutineDetailView(routine: Routine, autoStart: Bool = false)` — shows items with targets, last-performed, estimated duration; a **Start Workout** button; navigates to `ActiveWorkoutView` (Task 14). If `autoStart`, triggers start on appear. If a session is already active, the button offers to resume it.

- [ ] **Step 1: Write the failing tests**

`ForgeTests/WorkoutControllerTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct WorkoutControllerTests {
    private func makeContext() -> ModelContext {
        PersistenceController.makeInMemoryContainer().mainContext
    }

    @Test func startFromRoutineCopiesItemsInOrderWithResolvedRest() throws {
        let ctx = makeContext()
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads, defaultRestSeconds: 180)
        let curl = Exercise(name: "Curl", primaryBodyPart: .biceps)
        ctx.insert(squat); ctx.insert(curl)
        let routine = Routine(name: "Day A")
        routine.items = [
            RoutineItem(exercise: squat, order: 0, targetSets: 3, targetRepMin: 5, targetRepMax: 5),
            RoutineItem(exercise: curl, order: 1, targetRestSeconds: 60),
        ]
        ctx.insert(routine)
        try ctx.save()

        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        #expect(controller.hasActiveSession)
        #expect(session.sourceRoutineName == "Day A")
        #expect(session.orderedExercises.map { $0.exercise?.name } == ["Squat", "Curl"])
        #expect(session.orderedExercises[0].restSeconds == 180)   // exercise default
        #expect(session.orderedExercises[0].targetSets == 3)
        #expect(session.orderedExercises[1].restSeconds == 60)    // item override
    }

    @Test func cannotStartASecondSessionWhileOneIsActive() throws {
        let ctx = makeContext()
        let routine = Routine(name: "R")
        ctx.insert(routine); try ctx.save()
        let controller = WorkoutController(context: ctx)
        _ = try controller.start(from: routine)
        #expect(throws: WorkoutController.WorkoutError.sessionAlreadyActive) {
            _ = try controller.start(from: routine)
        }
    }

    @Test func controllerRecoversAnActiveSessionOnInit() throws {
        let ctx = makeContext()
        let routine = Routine(name: "R")
        ctx.insert(routine); try ctx.save()
        _ = try WorkoutController(context: ctx).start(from: routine)

        let fresh = WorkoutController(context: ctx)
        #expect(fresh.hasActiveSession)
    }

    @Test func addSetAppendsWithIncrementingOrderAndSavesIncomplete() throws {
        let ctx = makeContext()
        let bench = Exercise(name: "Bench", primaryBodyPart: .chest)
        ctx.insert(bench)
        let routine = Routine(name: "R")
        routine.items = [RoutineItem(exercise: bench, order: 0)]
        ctx.insert(routine); try ctx.save()

        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        let we = session.orderedExercises[0]

        let first = controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: nil, isWarmup: false)
        let second = controller.addSet(to: we, weightKg: 100, addedWeightKg: nil, reps: 5, rpe: 8, isWarmup: false)
        #expect(first.order == 0)
        #expect(second.order == 1)
        #expect(we.orderedSets.count == 2)
        #expect(we.orderedSets.allSatisfy { !$0.isComplete })
    }

    @Test func finishStampsEndAndUpdatesRoutineLastPerformed() throws {
        let ctx = makeContext()
        let routine = Routine(name: "R")
        ctx.insert(routine); try ctx.save()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)

        controller.finish(session, history: [])
        #expect(session.endedAt != nil)
        #expect(controller.hasActiveSession == false)
        #expect(routine.lastPerformedAt != nil)
    }

    @Test func discardDeletesTheSession() throws {
        let ctx = makeContext()
        let routine = Routine(name: "R")
        ctx.insert(routine); try ctx.save()
        let controller = WorkoutController(context: ctx)
        let session = try controller.start(from: routine)
        controller.discard(session)
        #expect(controller.hasActiveSession == false)
        #expect(try ctx.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `WorkoutController.swift`**

```swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class WorkoutController {
    private let context: ModelContext
    private(set) var activeSession: WorkoutSession?

    init(context: ModelContext) {
        self.context = context
        self.activeSession = Self.fetchActiveSession(in: context)
    }

    var hasActiveSession: Bool { activeSession != nil }

    enum WorkoutError: Error, Equatable { case sessionAlreadyActive }

    // MARK: Lifecycle

    func start(from routine: Routine) throws -> WorkoutSession {
        guard activeSession == nil else { throw WorkoutError.sessionAlreadyActive }

        let session = WorkoutSession(
            startedAt: .now,
            sourceRoutine: routine,
            sourceRoutineName: routine.name
        )
        context.insert(session)

        for item in routine.orderedItems {
            guard let exercise = item.exercise else { continue }
            let workoutExercise = WorkoutExercise(
                exercise: exercise,
                exerciseID: exercise.id,
                order: item.order,
                targetSets: item.targetSets,
                targetRepMin: item.targetRepMin,
                targetRepMax: item.targetRepMax,
                restSeconds: item.targetRestSeconds ?? exercise.defaultRestSeconds
            )
            session.exercises.append(workoutExercise)
        }

        save()
        activeSession = session
        return session
    }

    func discard(_ session: WorkoutSession) {
        context.delete(session)
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    @discardableResult
    func finish(_ session: WorkoutSession, history: [WorkoutSession]) -> Void {
        session.endedAt = .now
        session.sourceRoutine?.lastPerformedAt = session.endedAt
        save()
        if activeSession?.id == session.id { activeSession = nil }
    }

    // MARK: Editing

    func addExercise(_ exercise: Exercise, to session: WorkoutSession) {
        let order = (session.orderedExercises.last?.order ?? -1) + 1
        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            exerciseID: exercise.id,
            order: order,
            restSeconds: exercise.defaultRestSeconds
        )
        session.exercises.append(workoutExercise)
        save()
    }

    @discardableResult
    func addSet(
        to workoutExercise: WorkoutExercise,
        weightKg: Double?,
        addedWeightKg: Double?,
        reps: Int,
        rpe: Double?,
        isWarmup: Bool
    ) -> ExerciseSet {
        let order = (workoutExercise.orderedSets.last?.order ?? -1) + 1
        let set = ExerciseSet(
            order: order,
            weightKg: weightKg,
            addedWeightKg: addedWeightKg,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup
        )
        workoutExercise.sets.append(set)
        save()
        return set
    }

    func toggleComplete(_ set: ExerciseSet) {
        set.isComplete.toggle()
        set.completedAt = set.isComplete ? .now : nil
        save()
    }

    // MARK: Helpers

    private func save() {
        do { try context.save() }
        catch { assertionFailure("WorkoutController save failed: \(error)") }
    }

    private static func fetchActiveSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
```

- [ ] **Step 3: Run the tests → PASS. Then write `RoutineDetailView.swift`**

```swift
import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    let routine: Routine
    var autoStart: Bool = false

    @State private var controller: WorkoutController?
    @State private var startedSession: WorkoutSession?
    @State private var showActiveConflict = false

    private var estimatedMinutes: Int {
        // ~2.5 min per planned set, default 3 sets when no target.
        routine.orderedItems.reduce(0) { $0 + Int(Double($1.targetSets ?? 3) * 2.5) }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Last performed") { RelativeDateText(date: routine.lastPerformedAt) }
                LabeledContent("Estimated", value: "~\(estimatedMinutes) min")
            }
            Section("Exercises") {
                ForEach(routine.orderedItems) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.exercise?.name ?? "—")
                        if let target = targetLabel(item) {
                            Text(target).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(routine.name)
        .safeAreaInset(edge: .bottom) {
            Button("Start Workout", action: attemptStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .navigationDestination(item: $startedSession) { session in
            if let controller {
                ActiveWorkoutView(session: session, controller: controller)
            }
        }
        .alert("A workout is already in progress", isPresented: $showActiveConflict) {
            Button("Resume it") { resumeExisting() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            if controller == nil { controller = WorkoutController(context: context) }
            if autoStart { attemptStart() }
        }
    }

    private func targetLabel(_ item: RoutineItem) -> String? {
        let reps = RepRange.label(min: item.targetRepMin, max: item.targetRepMax)
        switch (item.targetSets, reps) {
        case let (s?, r?): return "\(s) × \(r)"
        case let (s?, nil): return "\(s) sets"
        case let (nil, r?): return "reps \(r)"
        default: return nil
        }
    }

    private func attemptStart() {
        guard let controller else { return }
        if controller.hasActiveSession { showActiveConflict = true; return }
        startedSession = try? controller.start(from: routine)
    }

    private func resumeExisting() {
        startedSession = controller?.activeSession
    }
}
```

> References `ActiveWorkoutView` (Task 14). Keep the Task 11 stub for
> `ActiveWorkoutView` in place (`struct ActiveWorkoutView: View { let session: WorkoutSession; let controller: WorkoutController; var body: some View { Text("Active") } }`) so this builds; Task 14 replaces it.

- [ ] **Step 4: Build, verify, run suites, commit**

Simulator: from the routine list, tap a routine → detail shows exercises + targets; **Start Workout** → lands on the stub active screen. Back out, Start again → "already in progress" alert.

```bash
git add -A
git commit -m "feat: workout controller state machine and routine detail / start"
```

---

## Task 14: Active workout — set logging & "last time"

**Files:**
- Create: `Forge/Features/Workout/ActiveWorkoutView.swift` (replace stub), `Forge/Features/Workout/WorkoutExerciseCard.swift`, `Forge/Features/Workout/SetEntryRow.swift`, `Forge/Features/Workout/LastPerformance.swift`
- Test: `ForgeTests/LastPerformanceTests.swift`

**Interfaces:**
- Consumes: `WorkoutController` (Task 13), models, `WeightFormatting` (Task 9), `RepRange` (Task 12).
- Produces:
  - `enum LastPerformance { static func mostRecentSets(ofExerciseID id: UUID, excludingSession: UUID, in context: ModelContext) -> [ExerciseSet] }` — working sets from the most recent **finished** session that included that exercise; `[]` if none.
  - `ActiveWorkoutView(session: WorkoutSession, controller: WorkoutController)` — scrollable list of `WorkoutExerciseCard`; header with elapsed time and **Finish**; "Add exercise" button (uses `ExercisePickerView`).
  - `WorkoutExerciseCard` — target label, "last time" summary, `SetEntryRow`s, "Add set".
  - `SetEntryRow` — weight (hidden for bodyweight; added-weight field shown), reps, RPE menu, warmup toggle, complete checkbox.

- [ ] **Step 1: Write the failing test**

`ForgeTests/LastPerformanceTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct LastPerformanceTests {
    @Test func returnsWorkingSetsFromTheMostRecentFinishedSession() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let bench = Exercise(name: "Bench", primaryBodyPart: .chest)
        ctx.insert(bench)

        func session(daysAgo: Int, weight: Double, finished: Bool) -> WorkoutSession {
            let day = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
            let s = WorkoutSession(startedAt: day, sourceRoutine: nil, sourceRoutineName: "x")
            if finished { s.endedAt = day }
            let we = WorkoutExercise(exercise: bench, exerciseID: bench.id, order: 0)
            let warm = ExerciseSet(order: 0, weightKg: 40, reps: 10, isWarmup: true); warm.isComplete = true
            let work = ExerciseSet(order: 1, weightKg: weight, reps: 5); work.isComplete = true
            we.sets = [warm, work]
            s.exercises = [we]
            ctx.insert(s)
            return s
        }

        _ = session(daysAgo: 10, weight: 90, finished: true)
        let recent = session(daysAgo: 3, weight: 100, finished: true)
        _ = session(daysAgo: 1, weight: 110, finished: false)   // in progress, ignored
        try ctx.save()

        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: bench.id,
            excludingSession: recent.id,   // exclude self -> should pick the 90kg day
            in: ctx
        )
        #expect(sets.map(\.weightKg) == [90])       // warmup filtered out
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `LastPerformance.swift`**

```swift
import Foundation
import SwiftData

enum LastPerformance {
    /// Working sets for `exerciseID` from the most recent finished session
    /// that is not `excludingSession`. Empty when there is no prior history.
    @MainActor
    static func mostRecentSets(
        ofExerciseID exerciseID: UUID,
        excludingSession: UUID,
        in context: ModelContext
    ) -> [ExerciseSet] {
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate { workoutExercise in
                workoutExercise.exerciseID == exerciseID
                && workoutExercise.session?.endedAt != nil
                && workoutExercise.session?.id != excludingSession
            },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return [] }
        guard let mostRecent = candidates.first else { return [] }
        return mostRecent.orderedSets.filter { $0.isComplete && !$0.isWarmup }
    }
}
```

> If `#Predicate` rejects the optional-relationship key paths at runtime, fall
> back to fetching finished `WorkoutSession`s sorted by `startedAt` desc and
> scanning in Swift for the first containing `exerciseID`. Note which path was
> used in the commit message.

- [ ] **Step 3: Run the test → PASS. Write `SetEntryRow.swift`**

```swift
import SwiftUI

struct SetEntryRow: View {
    @Bindable var set: ExerciseSet
    let isBodyweight: Bool
    let unit: WeightUnit
    let onToggleComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.isComplete ? .green : .secondary)
            }
            .buttonStyle(.plain)

            if isBodyweight {
                weightField(title: "+kg", keyPath: \.addedWeightKg)
            } else {
                weightField(title: unit.rawValue, keyPath: \.weightKg)
            }

            repsField

            Menu {
                Button("No RPE") { set.rpe = nil }
                ForEach(Array(stride(from: 6.0, through: 10.0, by: 0.5)), id: \.self) { value in
                    Button(String(format: "RPE %.1f", value)) { set.rpe = value }
                }
            } label: {
                Text(set.rpe.map { String(format: "%.1f", $0) } ?? "RPE")
                    .font(.caption)
                    .foregroundStyle(set.rpe == nil ? .secondary : .primary)
            }

            Toggle("Warmup", isOn: $set.isWarmup).labelsHidden().toggleStyle(.button)
        }
    }

    private var repsField: some View {
        TextField("reps", value: $set.reps, format: .number)
            .keyboardType(.numberPad)
            .frame(width: 44)
            .multilineTextAlignment(.center)
    }

    private func weightField(title: String, keyPath: ReferenceWritableKeyPath<ExerciseSet, Double?>) -> some View {
        let binding = Binding<Double>(
            get: {
                let kg = set[keyPath: keyPath] ?? 0
                return WeightFormatting.editableValue(kg, unit: unit)
            },
            set: { entered in
                set[keyPath: keyPath] = WeightFormatting.kilograms(from: entered, unit: unit)
            }
        )
        return TextField(title, value: binding, format: .number)
            .keyboardType(.decimalPad)
            .frame(width: 60)
            .multilineTextAlignment(.center)
    }
}
```

- [ ] **Step 4: Write `WorkoutExerciseCard.swift`**

```swift
import SwiftUI
import SwiftData

struct WorkoutExerciseCard: View {
    @Environment(\.modelContext) private var context
    let workoutExercise: WorkoutExercise
    let sessionID: UUID
    let controller: WorkoutController
    let onSetCompleted: (ExerciseSet) -> Void   // hands off to the rest timer

    private var unit: WeightUnit { Preferences.weightUnit }
    private var isBodyweight: Bool { workoutExercise.exercise?.isBodyweight ?? false }

    private var lastTime: String {
        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: workoutExercise.exerciseID,
            excludingSession: sessionID,
            in: context
        )
        guard !sets.isEmpty else { return "First time" }
        return sets.map { summary($0) }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workoutExercise.exercise?.name ?? "—").font(.headline)
                Spacer()
                if let target = targetLabel { Text(target).font(.caption).foregroundStyle(.secondary) }
            }
            Text("Last: \(lastTime)").font(.caption).foregroundStyle(.secondary)

            ForEach(workoutExercise.orderedSets) { set in
                SetEntryRow(set: set, isBodyweight: isBodyweight, unit: unit) {
                    controller.toggleComplete(set)
                    if set.isComplete { onSetCompleted(set) }
                }
            }

            Button("Add set", systemImage: "plus") {
                let previous = workoutExercise.orderedSets.last
                controller.addSet(
                    to: workoutExercise,
                    weightKg: isBodyweight ? nil : previous?.weightKg,
                    addedWeightKg: isBodyweight ? previous?.addedWeightKg : nil,
                    reps: previous?.reps ?? 0,
                    rpe: nil,
                    isWarmup: false
                )
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }

    private var targetLabel: String? {
        let reps = RepRange.label(min: workoutExercise.targetRepMin, max: workoutExercise.targetRepMax)
        switch (workoutExercise.targetSets, reps) {
        case let (s?, r?): return "\(s) × \(r)"
        case let (s?, nil): return "\(s) sets"
        case let (nil, r?): return "reps \(r)"
        default: return nil
        }
    }

    private func summary(_ set: ExerciseSet) -> String {
        if isBodyweight {
            if let added = set.addedWeightKg, added > 0 {
                return "+\(WeightFormatting.display(added, unit: unit)) × \(set.reps)"
            }
            return "\(set.reps)"
        }
        let weight = WeightFormatting.display(set.weightKg ?? 0, unit: unit)
        return "\(weight) × \(set.reps)"
    }
}
```

- [ ] **Step 5: Write `ActiveWorkoutView.swift`**

```swift
import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    let controller: WorkoutController

    @State private var addingExercise = false
    @State private var restTimer = RestTimer()            // Task 15
    @State private var showFinish = false                 // Task 16 wires the summary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(session.orderedExercises) { workoutExercise in
                    WorkoutExerciseCard(
                        workoutExercise: workoutExercise,
                        sessionID: session.id,
                        controller: controller
                    ) { _ in
                        restTimer.start(seconds: workoutExercise.restSeconds ?? Preferences.defaultRestSeconds)
                    }
                    Divider()
                }
                Button("Add exercise", systemImage: "plus.circle") { addingExercise = true }
            }
            .padding()
        }
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { showFinish = true }
            }
            ToolbarItem(placement: .principal) {
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(elapsed(to: context.date)).monospacedDigit().font(.subheadline)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if restTimer.isRunning { RestTimerBar(timer: restTimer) }   // Task 15
        }
        .sheet(isPresented: $addingExercise) {
            NavigationStack {
                ExercisePickerView { exercise in
                    controller.addExercise(exercise, to: session)
                }
            }
        }
        // Task 16 replaces the finish alert below with a WorkoutSummaryView sheet.
        .interactiveDismissDisabled()
    }

    private func elapsed(to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(session.startedAt))
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}
```

> `RestTimer` / `RestTimerBar` are Task 15. For this task, add a tiny stub
> (`@Observable final class RestTimer { var isRunning = false; func start(seconds: Int) {} }`
> and `struct RestTimerBar: View { let timer: RestTimer; var body: some View { EmptyView() } }`).
> Task 15 replaces both. `showFinish` currently just stamps the session via a
> temporary `.alert` calling `controller.finish(session, history: [])` then
> `dismiss()`; Task 16 replaces that with the summary sheet.

- [ ] **Step 6: Wire a temporary finish**

Add to `ActiveWorkoutView` until Task 17:

```swift
.alert("Finish workout?", isPresented: $showFinish) {
    Button("Finish", role: .destructive) {
        controller.finish(session, history: [])
        dismiss()
    }
    Button("Keep going", role: .cancel) {}
}
```

- [ ] **Step 7: Build & verify in Simulator (the core loop)**

Start a workout from a routine. For Bench: add a set, enter 100 × 5, check it off. Add another set (prefilled 100 × 5). Confirm "Last: First time" on the first ever session. Finish. Start the same routine again — confirm "Last: 100 kg × 5" now shows. Switch unit to lb in Settings and confirm the card re-renders in lb.

- [ ] **Step 8: Run suites and commit**

```bash
git add -A
git commit -m "feat: active workout screen with set logging and last-time reference"
```

---

## Task 15: Rest timer & notification

**Files:**
- Create: `Forge/Features/Workout/RestTimer.swift` (replace stub), `Forge/Features/Workout/RestTimerBar.swift` (replace stub)
- Modify: `Forge/App/ForgeApp.swift` (request notification authorization lazily is fine; do it on first timer start)
- Test: `ForgeTests/RestTimerTests.swift`

**Interfaces:**
- Consumes: nothing app-specific.
- Produces:
  - `@Observable @MainActor final class RestTimer`:
    - `private(set) var endsAt: Date?`
    - `var isRunning: Bool`
    - `func start(seconds: Int, now: Date = .now)`
    - `func addSeconds(_ delta: Int)`
    - `func skip()`
    - `func remaining(at now: Date = .now) -> Int` (never negative)
    - Injectable `notifier: RestNotifying` (default schedules a `UNUserNotificationRequest`); tests pass a spy.
  - `protocol RestNotifying { func schedule(after seconds: Int); func cancel() }`
  - `RestTimerBar(timer: RestTimer)` — countdown text, −30 / Skip / +30 buttons.

- [ ] **Step 1: Write the failing test**

`ForgeTests/RestTimerTests.swift`:

```swift
import Testing
import Foundation
@testable import Forge

@MainActor
final class SpyNotifier: RestNotifying {
    var scheduled: [Int] = []
    var cancelled = 0
    func schedule(after seconds: Int) { scheduled.append(seconds) }
    func cancel() { cancelled += 1 }
}

@Suite @MainActor
struct RestTimerTests {
    @Test func startSetsAnEndDateAndSchedulesANotification() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        let t0 = Date(timeIntervalSince1970: 1_000)

        timer.start(seconds: 120, now: t0)

        #expect(timer.isRunning)
        #expect(timer.remaining(at: t0) == 120)
        #expect(timer.remaining(at: t0.addingTimeInterval(45)) == 75)
        #expect(spy.scheduled == [120])
    }

    @Test func remainingClampsToZeroAndStopsRunning() {
        let timer = RestTimer(notifier: SpyNotifier())
        let t0 = Date(timeIntervalSince1970: 0)
        timer.start(seconds: 60, now: t0)
        #expect(timer.remaining(at: t0.addingTimeInterval(90)) == 0)
        #expect(timer.isRunning(at: t0.addingTimeInterval(90)) == false)
    }

    @Test func addSecondsExtendsAndReschedules() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        let t0 = Date(timeIntervalSince1970: 0)
        timer.start(seconds: 60, now: t0)
        timer.addSeconds(30, now: t0.addingTimeInterval(10))   // 50 left -> 80 left
        #expect(timer.remaining(at: t0.addingTimeInterval(10)) == 80)
        #expect(spy.scheduled == [60, 80])
    }

    @Test func skipStopsAndCancels() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        timer.start(seconds: 60)
        timer.skip()
        #expect(timer.isRunning == false)
        #expect(spy.cancelled == 1)
    }
}
```

> Note: the test uses `timer.isRunning(at:)`. Provide both a parameterless
> `var isRunning` (evaluated at `.now`) and `func isRunning(at:) -> Bool`.

- [ ] **Step 2: Run to confirm failure, then implement `RestTimer.swift`**

```swift
import Foundation
import Observation
import UserNotifications

@MainActor
protocol RestNotifying {
    func schedule(after seconds: Int)
    func cancel()
}

/// Schedules a single local notification with a fixed identifier so a
/// reschedule replaces the previous one.
@MainActor
struct LocalRestNotifier: RestNotifying {
    private let identifier = "forge.rest-timer"

    func schedule(after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, TimeInterval(seconds)),
            repeats: false
        )
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

@Observable
@MainActor
final class RestTimer {
    private(set) var endsAt: Date?
    private let notifier: RestNotifying

    init(notifier: RestNotifying = LocalRestNotifier()) {
        self.notifier = notifier
    }

    var isRunning: Bool { isRunning(at: .now) }

    func isRunning(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return endsAt > now
    }

    func start(seconds: Int, now: Date = .now) {
        endsAt = now.addingTimeInterval(TimeInterval(seconds))
        notifier.schedule(after: seconds)
    }

    func addSeconds(_ delta: Int, now: Date = .now) {
        let base = endsAt ?? now
        endsAt = base.addingTimeInterval(TimeInterval(delta))
        notifier.schedule(after: remaining(at: now))
    }

    func skip() {
        endsAt = nil
        notifier.cancel()
    }

    func remaining(at now: Date = .now) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }
}
```

- [ ] **Step 3: Run the test → PASS. Write `RestTimerBar.swift`**

```swift
import SwiftUI

struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remaining(at: context.date)
            HStack(spacing: 16) {
                Button("−30") { timer.addSeconds(-30) }
                Spacer()
                Text(format(remaining)).font(.title3).monospacedDigit().bold()
                Spacer()
                Button("Skip") { timer.skip() }
                Button("+30") { timer.addSeconds(30) }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
```

- [ ] **Step 4: Remove the Task 14 stubs; build & verify**

Delete the stub `RestTimer` / `RestTimerBar` declarations. Build. In the Simulator, complete a set → the bar appears counting down; +30/−30 adjust it; Skip dismisses it. Background the app for the remaining time → the local notification fires.

- [ ] **Step 5: Run suites and commit**

```bash
git add -A
git commit -m "feat: rest timer with local notification and adjustable countdown"
```

---

## Task 16: Finish workout & summary

**Files:**
- Create: `Forge/Features/Workout/WorkoutSummary.swift`, `Forge/Features/Workout/WorkoutSummaryView.swift`
- Modify: `Forge/Features/Workout/WorkoutController.swift` (`finish` returns `WorkoutSummary`), `Forge/Features/Workout/ActiveWorkoutView.swift` (present the summary), `ForgeTests/WorkoutControllerTests.swift` (update the `finish` assertions)
- Test: `ForgeTests/WorkoutSummaryTests.swift`

**Interfaces:**
- Consumes: `ForgeCore` (`sessionVolumeKg`, `newPersonalRecords`), mapping (Task 7), models.
- Produces:
  - `struct WorkoutSummary: Identifiable { let id = UUID(); let durationSeconds: Int; let totalVolumeKg: Double; let workingSetCount: Int; let bodyParts: [BodyPart]; let prHits: [PRHitDisplay] }` — `Identifiable` so it drives `.sheet(item:)`.
  - `struct PRHitDisplay: Equatable { let exerciseName: String; let kind: PRKind }`
  - `enum WorkoutSummaryBuilder { static func build(session: WorkoutSession, finishedAt: Date, history: [WorkoutSession]) -> WorkoutSummary }`
  - `WorkoutController.finish(_:history:) -> WorkoutSummary`
  - `WorkoutSummaryView(summary: WorkoutSummary, onDone: () -> Void)`

- [ ] **Step 1: Write the failing test**

`ForgeTests/WorkoutSummaryTests.swift`:

```swift
import Testing
import SwiftData
import ForgeCore
@testable import Forge

@Suite @MainActor
struct WorkoutSummaryTests {
    @Test func summarisesVolumeSetsBodyPartsAndPRs() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        let bench = Exercise(name: "Bench", primaryBodyPart: .chest)
        let squat = Exercise(name: "Squat", primaryBodyPart: .quads)
        ctx.insert(bench); ctx.insert(squat)

        // history: bench 100x5 two weeks ago
        let past = WorkoutSession(startedAt: .now.addingTimeInterval(-1_209_600),
                                  sourceRoutine: nil, sourceRoutineName: "old")
        past.endedAt = past.startedAt
        let pastWE = WorkoutExercise(exercise: bench, exerciseID: bench.id, order: 0)
        let pastSet = ExerciseSet(order: 0, weightKg: 100, reps: 5); pastSet.isComplete = true
        pastWE.sets = [pastSet]; past.exercises = [pastWE]
        ctx.insert(past)

        // today: bench 105x5 (weight + e1rm PR), squat 140x3
        let today = WorkoutSession(startedAt: .now.addingTimeInterval(-3600),
                                   sourceRoutine: nil, sourceRoutineName: "PPL")
        let bWE = WorkoutExercise(exercise: bench, exerciseID: bench.id, order: 0)
        let bSet = ExerciseSet(order: 0, weightKg: 105, reps: 5); bSet.isComplete = true
        bWE.sets = [bSet]
        let sWE = WorkoutExercise(exercise: squat, exerciseID: squat.id, order: 1)
        let sSet = ExerciseSet(order: 0, weightKg: 140, reps: 3); sSet.isComplete = true
        sWE.sets = [sSet]
        today.exercises = [bWE, sWE]
        ctx.insert(today)
        try ctx.save()

        let summary = WorkoutSummaryBuilder.build(
            session: today,
            finishedAt: today.startedAt.addingTimeInterval(3600),
            history: [past]
        )

        #expect(summary.durationSeconds == 3600)
        #expect(summary.totalVolumeKg == 105 * 5 + 140 * 3)   // 945
        #expect(summary.workingSetCount == 2)
        #expect(Set(summary.bodyParts) == [.chest, .quads])
        let benchPRs = summary.prHits.filter { $0.exerciseName == "Bench" }.map(\.kind)
        #expect(Set(benchPRs) == [.weight, .e1rm])
        #expect(summary.prHits.contains { $0.exerciseName == "Squat" && $0.kind == .weight })
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `WorkoutSummary.swift`**

```swift
import Foundation
import ForgeCore

struct PRHitDisplay: Equatable {
    let exerciseName: String
    let kind: PRKind
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let durationSeconds: Int
    let totalVolumeKg: Double
    let workingSetCount: Int
    let bodyParts: [BodyPart]
    let prHits: [PRHitDisplay]
}

enum WorkoutSummaryBuilder {
    @MainActor
    static func build(
        session: WorkoutSession,
        finishedAt: Date,
        history: [WorkoutSession]
    ) -> WorkoutSummary {
        let sessionInput = session.coreInput
        let historyInput = history.map(\.coreInput)

        let workingSetCount = session.orderedExercises
            .flatMap { $0.orderedSets }
            .filter { $0.isComplete && !$0.isWarmup }
            .count

        let bodyParts = orderedUniqueBodyParts(in: session)

        let names = exerciseNamesByID(in: session)
        let prHits = newPersonalRecords(in: sessionInput, history: historyInput).map {
            PRHitDisplay(exerciseName: names[$0.exerciseID] ?? "Exercise", kind: $0.kind)
        }

        return WorkoutSummary(
            durationSeconds: Int(finishedAt.timeIntervalSince(session.startedAt)),
            totalVolumeKg: sessionVolumeKg(sessionInput),
            workingSetCount: workingSetCount,
            bodyParts: bodyParts,
            prHits: prHits
        )
    }

    private static func orderedUniqueBodyParts(in session: WorkoutSession) -> [BodyPart] {
        var seen = Set<BodyPart>()
        var result: [BodyPart] = []
        for we in session.orderedExercises {
            guard let part = we.exercise?.primaryBodyPart else { continue }
            if seen.insert(part).inserted { result.append(part) }
        }
        return result
    }

    private static func exerciseNamesByID(in session: WorkoutSession) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: session.orderedExercises.compactMap { we in
            we.exercise.map { (we.exerciseID, $0.name) }
        })
    }
}
```

- [ ] **Step 3: Update `WorkoutController.finish`**

```swift
@discardableResult
func finish(_ session: WorkoutSession, history: [WorkoutSession]) -> WorkoutSummary {
    let finishedAt = Date.now
    session.endedAt = finishedAt
    session.sourceRoutine?.lastPerformedAt = finishedAt
    save()
    if activeSession?.id == session.id { activeSession = nil }
    return WorkoutSummaryBuilder.build(session: session, finishedAt: finishedAt, history: history)
}
```

Update `WorkoutControllerTests.finishStampsEndAndUpdatesRoutineLastPerformed` to `let summary = controller.finish(...)` and assert `summary.durationSeconds >= 0`.

- [ ] **Step 4: Write `WorkoutSummaryView.swift`**

```swift
import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    private var unit: WeightUnit { Preferences.weightUnit }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Duration", value: "\(summary.durationSeconds / 60) min")
                    LabeledContent("Volume", value: WeightFormatting.display(summary.totalVolumeKg, unit: unit, fractionDigits: 0))
                    LabeledContent("Working sets", value: "\(summary.workingSetCount)")
                    LabeledContent("Trained", value: summary.bodyParts.map(\.displayName).joined(separator: ", "))
                }
                if !summary.prHits.isEmpty {
                    Section("Personal records") {
                        ForEach(Array(summary.prHits.enumerated()), id: \.offset) { _, hit in
                            Label("\(hit.exerciseName) — \(label(hit.kind))", systemImage: "trophy.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Workout complete")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone) }
            }
        }
    }

    private func label(_ kind: PRKind) -> String {
        switch kind {
        case .weight: "heaviest weight"
        case .reps: "most reps"
        case .e1rm: "best estimated 1RM"
        }
    }
}
```

- [ ] **Step 5: Present it from `ActiveWorkoutView`**

Replace the temporary finish alert:

```swift
@State private var summary: WorkoutSummary?

// toolbar Finish button:
Button("Finish") {
    let history = (try? modelContext.fetch(
        FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt != nil })
    )) ?? []
    summary = controller.finish(session, history: history)
}

// presentation:
.sheet(item: $summary) { summary in
    WorkoutSummaryView(summary: summary) {
        self.summary = nil
        dismiss()
    }
}
```

`WorkoutSummary` is already `Identifiable` (Step 2), so `.sheet(item:)` works
directly. The `WorkoutSummaryTests` assertions read individual fields, so no
`Equatable` conformance is needed.

- [ ] **Step 6: Build & verify**

Complete a workout that beats a previous bench — the summary shows the PR with a trophy. Confirm the session now appears finished (next task renders History).

- [ ] **Step 7: Run suites and commit**

```bash
git add -A
git commit -m "feat: finish workout with a summary of volume, sets, and PRs"
```

---

## Task 17: Stale active-session prompt on launch

**Files:**
- Create: `Forge/Features/Workout/StaleSessionCheck.swift`
- Modify: `Forge/App/RootView.swift` (check on appear, present prompt)
- Test: `ForgeTests/StaleSessionCheckTests.swift`

**Interfaces:**
- Consumes: `WorkoutSession`.
- Produces:
  - `enum StaleSessionCheck { static func isStale(_ session: WorkoutSession, now: Date, threshold: TimeInterval = 6 * 3600) -> Bool }`
  - `RootView` on appear: if there is an active session and it is stale, present an alert — **Finish it** (calls `controller.finish`) or **Discard** (calls `controller.discard`). A non-stale active session is left alone (the user is mid-workout).

- [ ] **Step 1: Write the failing test**

`ForgeTests/StaleSessionCheckTests.swift`:

```swift
import Testing
import Foundation
@testable import Forge

@Suite struct StaleSessionCheckTests {
    @MainActor
    @Test func sessionOlderThanThresholdIsStale() {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 0),
            sourceRoutine: nil, sourceRoutineName: "x"
        )
        #expect(StaleSessionCheck.isStale(session, now: Date(timeIntervalSince1970: 7 * 3600)) == true)
        #expect(StaleSessionCheck.isStale(session, now: Date(timeIntervalSince1970: 3 * 3600)) == false)
    }

    @MainActor
    @Test func finishedSessionsAreNeverStale() {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 0),
            sourceRoutine: nil, sourceRoutineName: "x"
        )
        session.endedAt = Date(timeIntervalSince1970: 60)
        #expect(StaleSessionCheck.isStale(session, now: Date(timeIntervalSince1970: 999_999)) == false)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `StaleSessionCheck.swift`**

```swift
import Foundation

enum StaleSessionCheck {
    static func isStale(
        _ session: WorkoutSession,
        now: Date,
        threshold: TimeInterval = 6 * 3600
    ) -> Bool {
        guard session.endedAt == nil else { return false }
        return now.timeIntervalSince(session.startedAt) > threshold
    }
}
```

- [ ] **Step 3: Present the prompt from `RootView`**

```swift
struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var controller: WorkoutController?
    @State private var staleSession: WorkoutSession?

    var body: some View {
        TabView {
            RoutineListView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            let controller = controller ?? WorkoutController(context: context)
            self.controller = controller
            if let active = controller.activeSession,
               StaleSessionCheck.isStale(active, now: .now) {
                staleSession = active
            }
        }
        .alert("Unfinished workout", isPresented: .constant(staleSession != nil)) {
            Button("Finish it") {
                if let s = staleSession { _ = controller?.finish(s, history: finishedSessions()) }
                staleSession = nil
            }
            Button("Discard", role: .destructive) {
                if let s = staleSession { controller?.discard(s) }
                staleSession = nil
            }
        } message: {
            Text("A workout from earlier is still open. Finish or discard it?")
        }
    }

    private func finishedSessions() -> [WorkoutSession] {
        (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt != nil }
        ))) ?? []
    }
}
```

- [ ] **Step 4: Build & verify**

Temporarily lower the threshold to `1` second in a debug build, start a workout, kill and relaunch the app → the prompt appears. Restore the threshold.

- [ ] **Step 5: Run suites and commit**

```bash
git add -A
git commit -m "feat: prompt to finish or discard a stale workout on launch"
```

---

## Task 18: History — list & session detail

**Files:**
- Create: `Forge/Features/History/HistoryListView.swift`, `Forge/Features/History/SessionDetailView.swift`, `Forge/Features/History/MonthGrouping.swift`
- Modify: `Forge/App/RootView.swift` (use the real `HistoryListView`)
- Test: `ForgeTests/MonthGroupingTests.swift`

**Interfaces:**
- Consumes: `WorkoutSession`, `WeightFormatting`, `ForgeCore` (`sessionVolumeKg`).
- Produces:
  - `enum MonthGrouping { static func sections(_ sessions: [WorkoutSession], calendar: Calendar = .current) -> [(title: String, sessions: [WorkoutSession])] }` — newest month first, sessions newest first, title like `"September 2026"`.
  - `HistoryListView` — `@Query` finished sessions; grouped; row shows date, routine name, duration, volume, PR-free (M1 keeps the row simple: date · routine · duration · volume).
  - `SessionDetailView(session:)` — every workout-exercise with its sets (warmups tagged), RPE, notes.

- [ ] **Step 1: Write the failing test**

`ForgeTests/MonthGroupingTests.swift`:

```swift
import Testing
import SwiftData
@testable import Forge

@Suite @MainActor
struct MonthGroupingTests {
    @Test func groupsByMonthNewestFirst() throws {
        let ctx = PersistenceController.makeInMemoryContainer().mainContext
        func finished(_ iso: String) -> WorkoutSession {
            let date = ISO8601DateFormatter().date(from: iso)!
            let s = WorkoutSession(startedAt: date, sourceRoutine: nil, sourceRoutineName: "x")
            s.endedAt = date
            ctx.insert(s)
            return s
        }
        _ = finished("2026-08-30T10:00:00Z")
        _ = finished("2026-09-02T10:00:00Z")
        _ = finished("2026-09-20T10:00:00Z")
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        let sections = MonthGrouping.sections(all, calendar: .init(identifier: .gregorian))

        #expect(sections.map(\.title) == ["September 2026", "August 2026"])
        #expect(sections[0].sessions.count == 2)
        #expect(sections[0].sessions.first!.startedAt > sections[0].sessions.last!.startedAt)
    }
}
```

- [ ] **Step 2: Run to confirm failure, then implement `MonthGrouping.swift`**

```swift
import Foundation

enum MonthGrouping {
    static func sections(
        _ sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> [(title: String, sessions: [WorkoutSession])] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"

        let groups = Dictionary(grouping: sessions) { session -> DateComponents in
            calendar.dateComponents([.year, .month], from: session.startedAt)
        }

        return groups
            .map { components, sessions in
                let date = calendar.date(from: components) ?? .distantPast
                return (
                    title: formatter.string(from: date),
                    sessions: sessions.sorted { $0.startedAt > $1.startedAt },
                    sortKey: date
                )
            }
            .sorted { $0.sortKey > $1.sortKey }
            .map { ($0.title, $0.sessions) }
    }
}
```

- [ ] **Step 3: Run the test → PASS. Write `SessionDetailView.swift`**

```swift
import SwiftUI
import ForgeCore

struct SessionDetailView: View {
    let session: WorkoutSession
    private var unit: WeightUnit { Preferences.weightUnit }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let ended = session.endedAt {
                    LabeledContent("Duration", value: "\(Int(ended.timeIntervalSince(session.startedAt)) / 60) min")
                }
                LabeledContent("Volume", value: WeightFormatting.display(sessionVolumeKg(session.coreInput), unit: unit, fractionDigits: 0))
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes).font(.callout)
                }
            }
            ForEach(session.orderedExercises) { we in
                Section(we.exercise?.name ?? "—") {
                    ForEach(we.orderedSets) { set in
                        HStack {
                            Text(setLine(set, bodyweight: we.exercise?.isBodyweight ?? false))
                            if set.isWarmup {
                                Text("warmup").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let rpe = set.rpe { Text(String(format: "RPE %.1f", rpe)).font(.caption) }
                        }
                    }
                }
            }
        }
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setLine(_ set: ExerciseSet, bodyweight: Bool) -> String {
        if bodyweight {
            if let added = set.addedWeightKg, added > 0 {
                return "+\(WeightFormatting.display(added, unit: unit)) × \(set.reps)"
            }
            return "\(set.reps) reps"
        }
        return "\(WeightFormatting.display(set.weightKg ?? 0, unit: unit)) × \(set.reps)"
    }
}
```

- [ ] **Step 4: Write `HistoryListView.swift`**

```swift
import SwiftUI
import SwiftData
import ForgeCore

struct HistoryListView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    private var unit: WeightUnit { Preferences.weightUnit }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Finished workouts show up here."))
                } else {
                    List {
                        ForEach(MonthGrouping.sections(sessions), id: \.title) { section in
                            Section(section.title) {
                                ForEach(section.sessions) { session in
                                    NavigationLink {
                                        SessionDetailView(session: session)
                                    } label: {
                                        row(session)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func row(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.sourceRoutineName).font(.headline)
            HStack(spacing: 6) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                if let ended = session.endedAt {
                    Text("·")
                    Text("\(Int(ended.timeIntervalSince(session.startedAt)) / 60) min")
                }
                Text("·")
                Text(WeightFormatting.display(sessionVolumeKg(session.coreInput), unit: unit, fractionDigits: 0))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 5: Wire into `RootView`, build, verify end-to-end**

Replace the temporary `Text("History")` with `HistoryListView()`. Full manual pass:
1. Create a "Full Body" routine (5 exercises with targets).
2. Start it, log every exercise, hit a PR, Finish → summary.
3. History shows the session under this month; tap in → all sets, warmups tagged, RPE shown.
4. Start again → "last time" now populated on each card.

- [ ] **Step 6: Run every suite**

```bash
cd Packages/ForgeCore && swift test
cd ../.. && xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: workout history list and session detail"
```

---

## Self-Review

### 1. Spec coverage

| PRD section | Covered by |
|---|---|
| §4 App Group container from day one | Task 6 |
| §4 ForgeCore dependency-free, `swift test` | Tasks 2–4 |
| §4 Widget snapshot | **Deferred to M3** (PRD §8 M3) — not in this plan |
| §5 `Exercise` (minus `secondaryBodyParts`) | Task 5, 10 |
| §5 `Routine` / `RoutineItem` with optional targets | Task 5, 12 |
| §5 `WorkoutSession` + `WorkoutExercise` + `ExerciseSet` | Task 5 (adds `WorkoutExercise` — see Deviations) |
| §5 archive-not-delete rules | Task 10 (`ExerciseDeletion`), Task 11 (routine delete/archive) |
| §5 seed catalogue | Task 8 |
| §6 Epley e1RM | Task 2 |
| §6 working sets, volume, unilateral ×2, bodyweight 0 | Task 3 |
| §6 personal records + PR hits | Task 4 |
| §6 streak, heatmap | **Deferred to M2** — see Deviations |
| §7.1 routine list (start / edit / duplicate / delete) | Task 11 |
| §7.2 routine editor (items, targets, reorder, inline new exercise) | Task 12 |
| §7.3 active workout (last time, targets, rest timer, warmup, RPE, add exercise, finish, summary) | Tasks 13–16 |
| §7.3 stale-session prompt | Task 17 |
| §7.4 history list + detail | Task 18 |
| §7.7 settings (unit, default rest, manage exercises, about) | Task 9, 10 |
| §7.5 Progress, §7.6 Dashboard, §7.8 Chat | Out of scope for M1 (PRD §8) |
| §9 verification: `swift test` + `xcodebuild test` + previews + simulator | Every task |

### 2. Placeholder scan

The plan deliberately introduces temporary stubs (Tasks 11, 13, 14) to keep each
task independently buildable; each is explicitly named, quoted in full, and
replaced in a named later task. No `TBD` / `TODO` / "add error handling"–style
gaps remain. Every code step carries real code.

### 3. Type consistency

- `estimatedOneRepMax(weightKg:reps:)`, `sessionVolumeKg(_:)`, `sessionBestE1RM(_:exerciseID:)`, `newPersonalRecords(in:history:)` — signatures identical across Tasks 2–4, 7, 16.
- `WorkoutController.finish(_:history:)` returns `Void` in Task 13, changed to `WorkoutSummary` in Task 16 — the change is called out in Task 16 Step 3, and the Task 13 test is updated there.
- `RestTimer` exposes both `var isRunning` and `func isRunning(at:)` — the test in Task 15 Step 1 uses both; noted under the test.
- `WorkoutExercise.exerciseID: UUID` (Task 5) is the query key used in `ExerciseDeletion` (10), `LastPerformance` (14), `WorkoutSummaryBuilder` (16).
- `Exercise.id`, `Routine.id`, `WorkoutSession.id` all defined as `@Attribute(.unique) var id: UUID = UUID()` in Task 5 — used by predicates, `navigationDestination(item:)`, and the ForgeCore mapping.

---

## Deviations & refinements from the PRD

Fold these back into `docs/PRD.md` after the plan is approved:

1. **`WorkoutExercise` entity added** between `WorkoutSession` and `ExerciseSet`. The PRD's flat `ExerciseSet`-on-session model can't represent a planned-but-unlogged exercise, snapshot per-session targets, or survive a mid-workout crash cleanly. `ExerciseSet` now belongs to a `WorkoutExercise`, which belongs to a `WorkoutSession`.
2. **`WorkoutExercise.exerciseID: UUID`** denormalised alongside the `exercise` relationship, for predicate-friendly history queries.
3. **Streak and heatmap deferred to M2.** Nothing in M1 renders them; M1's ForgeCore is 1RM + volume + PR detection only. `currentStreakDays` / `longestStreakDays` / `heatmap` land with the Dashboard.
4. **M1 ships three tabs** (Workout, History, Settings). Progress and Dashboard tabs arrive in M2 — no placeholder tabs in M1.
5. **Identifiers**: bundle `com.forge.gym`, App Group `group.com.forge.gym` — no personal name (per the owner's instruction). Supersedes the PRD §3 working assumption. Each of `Exercise` / `Routine` / `WorkoutSession` also gets an explicit `id: UUID` (Task 5) for predicate and navigation use.
6. **`secondaryBodyParts`** stays deferred to M2 (already noted in PRD §5).

---

## Execution Handoff

**Plan complete and saved to `docs/plans/2026-09-03-m1-core-logging-loop.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — tasks run in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
