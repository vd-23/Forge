# Forge — Product Requirements Document

**Status:** Draft for review
**Date:** 2026-09-03
**Owner:** VD
**Platform:** iOS 26+ (iPhone), SwiftUI + SwiftData, on-device only

---

## Table of contents

1. [Overview & vision](#1-overview--vision)
2. [Goals & non-goals](#2-goals--non-goals)
3. [Platform & signing constraints](#3-platform--signing-constraints)
4. [Technical architecture](#4-technical-architecture)
5. [Data model](#5-data-model)
6. [ForgeCore computations](#6-forgecore-computations)
7. [Screens & UX](#7-screens--ux)
8. [Milestones](#8-milestones)
9. [Verification strategy](#9-verification-strategy)
10. [Open questions](#10-open-questions)
11. [Appendix A — seed exercises](#appendix-a--seed-exercises)
12. [Appendix B — formulas](#appendix-b--formulas)

---

## 1. Overview & vision

Forge is a personal iOS app for logging gym workouts and tracking strength
progression over time. It is built for one user, runs entirely on-device, and is
not intended for the App Store.

The primary motivation is a **workout logger that feels genuinely good to use** —
fast to log a set mid-workout, honest about whether you are getting stronger, and
visually polished using iOS 26's Liquid Glass in the chrome layer. Functionality
comes first; visual polish is a dedicated later milestone, not a running concern.

The core loop:

> Open the app → pick a routine → Start → log each set (the screen shows what you
> did last time and the target) → Finish → see a short summary → it lands in
> History. Over weeks, the Progress tab shows your estimated 1RM trending up per
> exercise, and the Dashboard shows a heatmap of the days you trained.

---

## 2. Goals & non-goals

### Goals

- Frictionless set logging during a workout, always starting from a routine.
- Routine management: build, edit, duplicate, delete named routines from a
  personal library of custom exercises.
- Per-exercise strength progression visibility (estimated 1RM, volume, rep PRs).
- A consistency habit view: a day heatmap plus a consecutive-day streak.
- Polished Liquid Glass chrome, gated to iOS 26 with solid fallbacks.
- A later Claude chat tab that can answer questions grounded in actual logged
  data (progression, deload timing, etc.).

### Non-goals (v1)

| Not doing | Notes |
|---|---|
| Body measurements (weight, chest, waist, arms…) | Cut entirely. No `BodyMeasurement` model. Nothing records bodyweight. |
| Cloud sync / backend | Everything is local SwiftData. |
| Data export / backup / restore | Deferred to a later version. See signing constraints below. |
| Multi-user | Single user, single device. |
| App Store submission | No privacy policy, no App Store Connect metadata. |
| Supersets / circuits / exercise grouping | Routines are a flat ordered list in v1. |
| Plate-math / warmup-ramp calculator | — |
| Weekly schedule / calendar (which routine on which day) | Routines are picked manually each session. |
| Apple Health / HealthKit integration | Possible v2. |
| Apple Watch app | Possible v2. |
| Per-set notes | Session-level notes only. |
| Editing past workouts | Deferred to M2. |
| Reordering exercises mid-workout | Deferred to M2. Adding an exercise mid-workout **is** in M1. |

---

## 3. Platform & signing constraints

- **iOS 26+ deployment target.** Required for Liquid Glass (`glassEffect`,
  `GlassEffectContainer`) and assumed throughout; no back-deployment.
- **Xcode 26.6** (installed and verified).
- **Free personal Apple ID signing.** Consequences:
  - Signing certificates expire every 7 days. The app stops launching and must be
    re-run from Xcode (`⌘R`). This is expected and acceptable.
  - **App Groups do NOT work on the free tier.** This was assumed at M1 and is
    wrong: the entitlement cannot be provisioned by a personal team, and code
    signing fails outright rather than degrading. Corrected during M2 when the
    app was first installed on a real device — the store moved to the app's own
    Application Support directory and the entitlement was removed. This blocks
    the M3 widget (see M3).
  - **There is no data export in v1.** Reinstalling *over* the existing app with
    the same bundle identifier and signing team preserves the SwiftData store.
    **Do not delete the app.** This risk is accepted for v1; export/restore is a
    later milestone.
- Bundle identifier: `com.forge.gym`. No personal name appears in any
  identifier, package, or module.

---

## 4. Technical architecture

### Targets

- **Forge** — the app target (SwiftUI lifecycle).
- **ForgeWidgets** — a Widget Extension target (added in M3).
- The app carries no entitlements: everything it needs is available to a free
  personal team.

### Persistence

- A single SwiftData `ModelContainer`, with its store in the app's own
  **Application Support** directory. It was originally placed in an App Group
  container so a widget could share it; that had to be undone in M2 when the
  free-tier limitation surfaced.
- SwiftData `@Model` classes are the source of truth for entities.
- Scalar preferences (unit, default rest, etc.) live in standard `UserDefaults`,
  not SwiftData — simpler at app launch.
- The Claude API key lives in the **Keychain**, never in SwiftData or
  `UserDefaults`, never hardcoded.

### ForgeCore (local Swift package)

All non-trivial computation lives in a local SPM package, `ForgeCore`, with
**no dependency on SwiftData or SwiftUI**. It operates on plain `Codable` value
structs. The app maps `@Model` objects into these structs at the call site.

This exists so the math is **unit-tested with `swift test` on the command line**,
without needing an Xcode build or a simulator. Given that the app-layer
build/verify loop runs through the user's Xcode, ForgeCore's test suite is the
primary automated safety net.

`ForgeCore` eventually contains: the e1RM formula, working-set filtering, volume
math (including unilateral ×2 and bodyweight = 0), session/weekly/per-body-part
aggregation, PR detection, streak and heatmap bucketing, and the chat-context
summariser. Each function lands in the milestone that first renders it — see §6.

### Widget data

The widget does **not** read SwiftData directly (historically unreliable).
On every workout **Finish**, the app writes a small `WidgetSnapshot` (`Codable`)
into the shared `UserDefaults`:

```
WidgetSnapshot {
  lastWorkoutDate: Date?
  lastWorkoutRoutineName: String?
  lastWorkoutDurationMinutes: Int?
  lastWorkoutVolumeKg: Double?
  currentStreakDays: Int
  workoutsThisWeek: Int
  generatedAt: Date
}
```

The widget renders from that snapshot only.

### Liquid Glass

- Applied to the **chrome layer only**: tab bar, navigation bars, the floating
  Start / Finish / rest-timer controls, toolbar buttons.
- **Never** on content: list rows, workout history, charts, set tables stay on
  solid, readable surfaces.
- Every use is gated `if #available(iOS 26, *)` with a non-glass fallback, even
  though the deployment target is 26 (belt and suspenders, and keeps the pattern
  explicit).
- This is **Milestone 4**. Earlier milestones use plain SwiftUI styling.

### Project generation

- The `.xcodeproj` is generated by **XcodeGen** from a checked-in `project.yml`.
- The generated `Forge.xcodeproj` is git-ignored; contributors run `xcodegen`
  after pulling structural changes.
- One-time setup: `brew install xcodegen`.

### Module / folder layout (app target)

```
Forge/
  App/            App entry point, ModelContainer setup, tab scaffold
  Models/         SwiftData @Model types + enums
  Persistence/    Container factory, seed data, @Model <-> ForgeCore mapping
  Features/
    Workout/      Routine list, routine editor, active workout, summary
    History/      Session list + detail
    Progress/     Per-exercise charts
    Dashboard/    Heatmap + stats
    Settings/     Preferences, exercise library management
    Chat/         Claude chat (M5)
  Shared/         Reusable views, formatters, design tokens
Packages/
  ForgeCore/      Pure logic + tests
ForgeWidgets/     Widget extension (M3)
```

---

## 5. Data model

### Enums

```
enum BodyPart: String, Codable, CaseIterable {
  case chest, back, shoulders, biceps, triceps, forearms, core,
       quads, hamstrings, glutes, calves, traps, cardio, fullBody, other
}

enum WeightUnit: String, Codable { case kg, lb }   // display only; storage is always kg
```

RPE is stored as `Double?` in the range 6.0–10.0 in 0.5 steps (nil = not recorded).

### `Exercise` (`@Model`)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | unique-ish, user-facing |
| `primaryBodyPart` | `BodyPart` | required |
| `isBodyweight` | `Bool` | true → set logging hides the main weight field, shows reps + optional added weight |
| `isUnilateral` | `Bool` | true → volume counts ×2; logged per side |
| `defaultRestSeconds` | `Int?` | optional per-exercise rest default |
| `isArchived` | `Bool` | soft-delete; archived exercises stay out of pickers but keep history intact |
| `createdAt` | `Date` | |

> `secondaryBodyParts` is **deferred to M2** (when per-body-part volume charts
> actually consume it). M1 exercises have a single primary body part.

### `Routine` (`@Model`)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | |
| `items` | `[RoutineItem]` | ordered by `RoutineItem.order` |
| `isArchived` | `Bool` | |
| `createdAt` | `Date` | |
| `lastPerformedAt` | `Date?` | updated on workout Finish |

### `RoutineItem` (`@Model`)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `routine` | `Routine` | inverse relationship |
| `exercise` | `Exercise` | |
| `order` | `Int` | position within the routine |
| `targetSets` | `Int?` | optional |
| `targetRepMin` | `Int?` | optional |
| `targetRepMax` | `Int?` | optional |
| `targetRestSeconds` | `Int?` | optional; overrides `Exercise.defaultRestSeconds` |

### `WorkoutSession` (`@Model`)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `startedAt` | `Date` | |
| `endedAt` | `Date?` | nil → session is active |
| `notes` | `String?` | session-level only |
| `sourceRoutine` | `Routine?` | nullable (routine may be deleted later) |
| `sourceRoutineName` | `String` | snapshot at start, always present |
| `exercises` | `[WorkoutExercise]` | ordered by `WorkoutExercise.order` |

Derived (not stored): `isActive` (`endedAt == nil`), `duration`,
`totalVolumeKg`, `prCount`.

**One active session at a time.** Starting a workout while one is active is
blocked (offer to resume or discard the existing one).

**Stale sessions:** on app launch, if an active session's `startedAt` is more
than ~6 hours ago, prompt: *Finish* (stamp `endedAt`) or *Discard*. (A fuller
auto-finish-at-midnight behaviour can come later; this keeps M1 simple.)

### `WorkoutExercise` (`@Model`)

One exercise slot within a session — created when a workout starts (copied from
the routine) or added mid-workout. Sits between `WorkoutSession` and
`ExerciseSet` so a planned exercise exists before any set is logged, per-session
targets are snapshotted, and a mid-workout crash loses nothing.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `session` | `WorkoutSession?` | inverse relationship |
| `exercise` | `Exercise?` | one-way reference; archived, not deleted, while referenced |
| `exerciseID` | `UUID` | denormalised `exercise.id` for predicate-friendly history queries |
| `order` | `Int` | position within the session |
| `targetSets` / `targetRepMin` / `targetRepMax` | `Int?` | snapshot of the routine item's targets |
| `restSeconds` | `Int?` | resolved at start: routine-item override → exercise default |
| `sets` | `[ExerciseSet]` | ordered by `ExerciseSet.order` |

### `ExerciseSet` (`@Model`)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `workoutExercise` | `WorkoutExercise?` | inverse relationship |
| `order` | `Int` | position within the workout-exercise |
| `weightKg` | `Double?` | working weight; nil for pure bodyweight |
| `addedWeightKg` | `Double?` | added load for bodyweight exercises (belt, vest); nil/0 otherwise |
| `reps` | `Int` | for unilateral, this is reps *per side* |
| `rpe` | `Double?` | 6.0–10.0, 0.5 steps, optional |
| `isWarmup` | `Bool` | warmups are excluded from volume, e1RM, and PR detection but shown in History |
| `isComplete` | `Bool` | checked off during the workout |
| `completedAt` | `Date?` | set when checked off |

### Deletion & archival rules

- **Exercises and routines are archived, not deleted**, when referenced by any
  historical session or routine. A hard delete is only offered when there is no
  reference.
- Deleting a routine never touches past sessions — `sourceRoutineName` preserves
  the label.
- Deleting a session cascades to its `WorkoutExercise`s and their `ExerciseSet`s.
- **Finishing prunes what was never done.** A set that was never ticked complete
  was never performed — it already counted for nothing in volume or PRs, so it
  is deleted rather than stored. An exercise left with no sets goes with it, and
  a session with nothing logged anywhere is discarded instead of being written
  to history. Bodyweight sets count as logged: they are tracked by reps, and
  contributing `0` volume is by design, not a sign of an empty set.

### Seed data

On first launch, the store is seeded with ~40 common exercises
([Appendix A](#appendix-a--seed-exercises)), all editable and deletable. No seed
routines — the user builds those.

---

## 6. ForgeCore computations

All pure functions over value structs. Representative signatures below;
**M1 implements only** `estimatedOneRepMax`, `workingSets`, `setVolumeKg`,
`sessionVolumeKg`, `sessionBestE1RM`, `personalRecords`, and `newPersonalRecords`.
The series builders, `currentStreakDays` / `longestStreakDays` / `heatmap`, and
`chatContext` arrive with the milestone that renders them (M2 for streak/heatmap,
M5 for chat).

```
// Epley
func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double
// = weightKg * (1 + Double(reps) / 30.0); reps == 1 -> weightKg

// A "working set" excludes warmups.
func workingSets(_ sets: [SetInput]) -> [SetInput]

// Per-set volume:
//   bodyweight exercise      -> 0
//   unilateral               -> weightKg * reps * 2
//   otherwise                -> weightKg * reps
func setVolumeKg(_ set: SetInput, exercise: ExerciseInput) -> Double

func sessionVolumeKg(_ session: SessionInput) -> Double
func weeklyVolumeSeries(_ sessions: [SessionInput], weeks: Int) -> [(weekStart: Date, volumeKg: Double)]

// Best estimated 1RM among a session's working sets for one exercise.
func sessionBestE1RM(_ session: SessionInput, exerciseID: UUID) -> Double?
func e1rmSeries(_ sessions: [SessionInput], exerciseID: UUID) -> [(date: Date, e1rm: Double)]

// PR detection for one exercise across history.
func personalRecords(_ sessions: [SessionInput], exerciseID: UUID) -> PRSet
// weight PR, rep PR (at-or-above a weight), e1RM PR

// Consistency
func currentStreakDays(_ sessions: [SessionInput], today: Date) -> Int   // consecutive days ending today or yesterday
func longestStreakDays(_ sessions: [SessionInput]) -> Int
func heatmap(_ sessions: [SessionInput], window: DateInterval) -> [Date: HeatLevel]

// Chat (M5)
func chatContext(recentSessions: [SessionInput], routines: [RoutineInput], maxSessions: Int) -> String
```

**Bodyweight exercises** never contribute to volume or e1RM series. Their
Progress view is a **max-reps trend** plus an **added-weight trend**.

**Streak semantics:** a day "counts" if it contains at least one *finished*
session (`endedAt != nil`). `currentStreakDays` counts back from today; if today
has no workout but yesterday does, the streak is still shown (anchored to
yesterday) so the number does not read 0 first thing in the morning. It only
resets once a full day passes with no finished session.

---

## 7. Screens & UX

The full app has five tabs: **Home · Workout · Exercises · History · Settings**,
with Chat added as a sixth in M5. **M1 ships three** — Workout, History,
Settings — and M2 adds Home and Exercises. Default tab: Workout.

Per-exercise progress charts live inside the Exercises tab rather than a tab of
their own: an exercise is the natural owner of its own trend line, and it keeps
the dock at five.

### 7.1 Workout tab — routine list (M1)

- List of non-archived routines. Row: name, "last performed" relative date,
  exercise count, and a prominent **Start** button.
- Swipe actions / long-press menu on a row: **Edit**, **Duplicate**, **Delete**
  (delete confirms; archives instead if the routine has history).
- **＋ New routine** in the toolbar.
- Tapping the row body (not Start) opens **Routine Detail**: the ordered exercise
  list with targets, last-performed date, estimated duration, and its own Start
  button.
- Empty state: a friendly prompt to create the first routine, with a shortcut to
  the exercise library.

### 7.2 Workout tab — routine editor (M1)

- Name field.
- Ordered list of exercises. **Add exercise** opens the library picker (search by
  name / filter by body part) with **＋ Create new exercise** inline (name,
  primary body part, `isBodyweight`, `isUnilateral`, optional default rest).
- Per item: optional target sets, optional target rep range (min–max), optional
  rest override. All blank = freestyle.
- Reorder (drag) and remove.

### 7.3 Active workout (M1)

Presented full-screen over the Workout tab.

- **Header:** routine name, running elapsed timer, **Finish** button.
- **Body:** one card per exercise in routine order. Each card shows:
  - the target ("3 × 8–10") if set,
  - **"last time"**: the sets from the most recent session containing this
    exercise, e.g. `80 × 8 · 80 × 8 · 80 × 7`,
  - the set rows logged so far this session.
- **Logging a set:** tap **Add set** → weight (hidden for bodyweight; added-weight
  field shown instead) + reps + optional RPE + warmup toggle → the row is added.
  Checking the row's checkbox marks it complete and **starts the rest timer**.
- **Rest timer:** duration resolved as item override → exercise default → global
  default. Shows a countdown in the chrome; **Skip**, **+30s**, **−30s**
  controls; fires a **local notification** when it reaches zero (notification
  permission requested the first time a timer starts).
- **Add exercise mid-workout:** picks from the library, appends a card. Not
  written back to the routine.
- **Skip an exercise:** simply leave it with no sets.
- **Finish:** confirms if some targeted exercises have no sets, then shows the
  **summary sheet** — duration, total volume, per-exercise set counts, PRs hit,
  body parts trained — then saves. `sourceRoutine.lastPerformedAt` and the
  `WidgetSnapshot` are updated here.

### 7.4 History tab (M1)

- Sessions grouped by month, newest first. Row: date, routine name, duration,
  total volume, PR badge count.
- Sortable by date (either direction), total volume, or duration, and filterable
  to a single routine. Month headings apply only to the date orders.
- Tap → **Session Detail**: every exercise with its sets (warmups marked), RPE if
  present, session notes.
- Swipe a row to delete a workout, behind a confirmation. Nothing else refers to
  a session, so unlike exercises and routines it has no archived state.
- Editing sets from History is **M2**.

### 7.5 Exercises tab — library and per-exercise progress (M2)

- The full library: create, edit, archive/unarchive, delete (when unused),
  grouped by body part and searchable. Moved here from Settings.
- Tap an exercise → its detail: flags, body part, lifetime PRs, and its charts.
- For a weighted exercise: an **estimated 1RM** line chart (best working set per
  session) with a **Volume** toggle (per-session working volume), rep-PR markers,
  and a date-range control (8w / 6m / 1y / all).
- For a bodyweight exercise: **max reps** trend + **added weight** trend; no
  e1RM/volume.
- Swift Charts; solid background.

### 7.6 Home tab (M2)

- **Heatmap:** ~16–20 weeks, horizontally scrollable, GitHub-style. Intensity by
  **working-set count** — volume would render every bodyweight day as the
  lightest shade. Rest days render in a flat neutral colour. Tap a day → that
  session.
- **Current streak** and **longest streak** (consecutive days).
- **This week:** workout count + total volume.
- **30-day volume** trend line.
- **Recent PRs** list.

### 7.7 Settings tab (M1 core, grows later)

- **Unit** — kg / lb (display only; storage is always kg).
- **Default rest** — global fallback, seconds.
- **Claude API key** — entered here, stored in Keychain (M5).
- **About** — version, and the "don't delete the app / reinstall via ⌘R" note.

### 7.8 Chat tab (M5)

- Claude **Messages API** over `URLSession`, streamed responses.
- Model: `claude-sonnet-5` (id in code; not user-selectable in v1).
- Before each request, `ForgeCore.chatContext(...)` builds a compact summary of
  recent sessions, current PRs, and active routines; it is supplied as context so
  answers are grounded in real logged data.
- API key read from Keychain; if absent, the tab prompts the user to add it in
  Settings.

---

## 8. Milestones

Each milestone is independently usable and is a checkpoint to reassess scope.
**Implementation is planned one milestone at a time** — the first implementation
plan covers M1 only, and later milestones are re-planned against what M1 actually
taught us.

### M1 — Core logging loop

1. Project scaffold (`project.yml`, XcodeGen), App Group, shared `ModelContainer`,
   `ForgeCore` package skeleton, CI-free `swift test` wiring.
2. SwiftData models + enums; `ForgeCore` value structs, mapping layer, seed data,
   SwiftUI previews with in-memory sample data.
3. `ForgeCore` math (volume, e1RM, PRs, streak, heatmap) with a full `swift test`
   suite — **written test-first**.
4. Exercise library: list, create, edit, archive, delete-when-unused.
5. Routines: list, detail, editor (ordered items + optional targets), duplicate,
   delete/archive.
6. Active workout: start from routine, log sets, "last time" reference, rest
   timer + local notification, warmup toggle, RPE, add-exercise mid-workout,
   Finish → summary → save. Stale-session prompt on launch.
7. History: list + session detail.

**Exit:** you can run your real training from the app.

### M2 — Insight

- `secondaryBodyParts` added to `Exercise` + editor.
- Progress tab (e1RM / volume / rep PRs; bodyweight variant).
- Dashboard (heatmap, streak, weekly stats, recent PRs).
- Edit past sets from History.

### M3 — Widget — **blocked on a paid account**

A widget cannot read the app's data without an App Group, and an App Group
cannot be provisioned by a free personal team. M3 needs either a paid Apple
Developer Program membership or to be dropped. Decide before starting it.

- `ForgeWidgets` extension target, App Group wiring.
- `WidgetSnapshot` writer on Finish.
- Small widget (streak + last workout date) and medium widget (this week + last
  workout summary).

### M4 — Liquid Glass polish

- `glassEffect` / `GlassEffectContainer` on tab bar, nav bars, Start/Finish/rest
  controls, gated to iOS 26 with fallbacks.
- App icon, empty states, haptics, transitions, list/section polish.

### M5 — Claude chat

- Settings: API key entry → Keychain.
- `URLSession` Messages API client with streaming.
- `ForgeCore.chatContext` builder.
- Chat tab UI.

---

## 9. Verification strategy

| Layer | How it's verified |
|---|---|
| `ForgeCore` (all math) | `swift test`, test-first, aiming for thorough coverage of edge cases (unilateral, bodyweight, warmups, empty history, streak boundaries). **Primary automated safety net.** |
| App compiles | `xcodebuild build` from the terminal after each change. |
| Screens | `#Preview` with seeded sample data for every view; Simulator for interaction and visual checks. |
| Integration | Manual runs in the Simulator; the user supervises in Xcode and reports build/runtime issues. |

TDD (superpowers:test-driven-development) applies to every `ForgeCore` unit and
to any app-layer logic that can be isolated from SwiftUI/SwiftData.

---

## 10. Open questions

Resolve at or before the relevant milestone; none block M1 start.

1. **Seed exercise list** — [Appendix A](#appendix-a--seed-exercises) is a first
   draft; refine during M1.4.
2. ~~**Heatmap intensity metric**~~ — resolved in M2: working-set count, so a
   bodyweight day registers as honestly as a heavy squat day.
3. **Stale-session handling** — M1 uses a launch-time prompt at ~6h; revisit
   whether a true midnight auto-finish is worth it later.
4. **Chat context budget** — how many sessions / how much detail fits a
   reasonable token budget. Tune in M5.
5. **Widget planned-exercises view** — dropped for now (no schedule model). Could
   later surface "most recent routine" as a suggestion.

---

## Appendix A — seed exercises

Format: name — primary body part — flags.

**Chest**
- Barbell Bench Press — chest
- Incline Dumbbell Press — chest
- Machine Chest Press — chest
- Cable Fly — chest
- Push-up — chest — bodyweight

**Back**
- Deadlift — back
- Barbell Row — back
- Lat Pulldown — back
- Seated Cable Row — back
- Pull-up — back — bodyweight
- Chin-up — back — bodyweight
- Single-arm Dumbbell Row — back — unilateral

**Shoulders**
- Overhead Press — shoulders
- Seated Dumbbell Shoulder Press — shoulders
- Lateral Raise — shoulders
- Rear Delt Fly — shoulders
- Face Pull — shoulders

**Biceps**
- Barbell Curl — biceps
- Dumbbell Curl — biceps
- Hammer Curl — biceps
- Cable Curl — biceps

**Triceps**
- Close-grip Bench Press — triceps
- Triceps Pushdown — triceps
- Overhead Cable Extension — triceps
- Dip — triceps — bodyweight

**Quads**
- Back Squat — quads
- Front Squat — quads
- Leg Press — quads
- Leg Extension — quads
- Walking Lunge — quads — unilateral
- Bulgarian Split Squat — quads — unilateral

**Hamstrings / glutes**
- Romanian Deadlift — hamstrings
- Lying Leg Curl — hamstrings
- Hip Thrust — glutes
- Back Extension — hamstrings — bodyweight

**Calves**
- Standing Calf Raise — calves
- Seated Calf Raise — calves

**Core**
- Hanging Leg Raise — core — bodyweight
- Cable Crunch — core
- Plank — core — bodyweight

---

## Appendix B — formulas

**Estimated 1RM (Epley):**

```
e1RM = weight × (1 + reps / 30)          for reps > 1
e1RM = weight                            for reps = 1
```

Brzycki and other variants are not used; Epley is chosen for simplicity and its
well-behaved output across the 1–12 rep range typical of logged working sets.

**Set volume:**

```
bodyweight exercise            → 0
unilateral (per-side reps r)   → weight × r × 2
standard                       → weight × reps
```

Warmup sets contribute 0 to volume, e1RM, and PRs regardless of the above.
