# M5 — Utilities

Six items from the M4 follow-up list, built feature-first, then hardening.
TDD throughout: failing test → implementation → green. (PRD's "M5 Claude chat"
becomes M6.)

## A · Custom body parts
`BodyPart` becomes a struct over its raw string: built-ins keep their raw values
(no migration), custom ones live in `Preferences.customBodyParts`. Settings gets
a "Body parts" screen: add, rename (propagates to exercises), delete (blocked
while in use). Editor picker and library grouping read `BodyPart.all`.

## B · Import / export
`ForgeBackup` — one Codable document holding exercises, routines, sessions,
custom body parts and preferences. Export shares a `.forge.json`; import
replaces everything after confirmation. Round-trip tested in memory.

## C · App Shortcuts
`StartWorkoutIntent(routine:)` + `AppShortcutsProvider`. The intent opens the
app and hands the routine to `ShortcutLauncher`, which starts the session
through `WorkoutController` (or resumes if one is running).

## D · Rest-timer Live Activity
`ForgeWidgets` extension with an `ActivityConfiguration` for
`RestActivityAttributes`; `RestTimer` drives start/update/end through a
`RestActivityPresenting` seam so the arithmetic stays testable.

## E · Validation and limits
`Limits` (name length, counts, numeric ranges) enforced at the editors and the
controller; `StoreHealth` reports the store size in Settings and warns past a
threshold.

## F · Review
Full-suite run, code review pass, simulator walkthrough of every touched screen.

---

## Status (overnight run, 2026-09-21)

All six items built with TDD; 141 app tests + 52 ForgeCore tests green; every
screen walked in the simulator (Body parts add/rename/delete, export produces a
valid 97 KB file with 54 sessions, import gated while a workout runs, Live
Activity shows on the lock screen and ends on Skip, Shortcut intent metadata
bundled). Code review found and fixed four real bugs before commit: restore's
batch delete failed on the Exercise→RoutineItem inverse after already wiping
history; a Live Activity could stack after an expiry in the background; export
included an unfinished session; expiry wasn't noticed until the bar ticked.

**Blocked:** device install. The `ForgeWidgets` target is a new bundle id and
Xcode's Apple ID session has expired ("No Accounts"), so no profile can be
issued from the command line. Sign in again under Xcode → Settings → Accounts,
then `xcodebuild … -allowProvisioningUpdates` (or ⌘R) will register it.

Not committed — waiting for review.
