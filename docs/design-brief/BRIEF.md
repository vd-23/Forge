# Forge — visual design brief

Paste this whole file into Claude Design, then attach the images in `screens/`.

---

## What Forge is

A personal iOS gym-tracking app (iPhone only, iOS 26, SwiftUI). One user, no
accounts, no social features, no coaching. The job is: start a routine, log
sets fast with one thumb while the other hand holds a dumbbell, finish, and
over weeks see the numbers go up.

The core loop: **pick a routine → Start → log each set → Finish → it lands in
History.** Everything else exists to make that loop faster or to show what it
produced.

The functionality is finished. This pass is purely visual: the app currently
uses default SwiftUI styling (see screenshots) and looks like a settings app.
It should feel like a product.

## What I want from you

A visual system and screen designs for the nine screens below, delivered as
iPhone-sized mockups (390×844 or 430×932). Specifically:

1. **A visual identity** — palette, type scale, spacing, card treatment, how
   numbers are emphasised. The app icon (attached) is the anchor: a lifter made
   of heatmap cells in a saturated blue, on a near-white ground (light) or
   near-black (dark). Extend that identity into the screens rather than
   inventing a new one.
2. **Light and dark mode** for every screen. Dark mode matters — the user is
   often in a dim gym.
3. **A clear visual hierarchy on the data-heavy screens** (Home, Exercise
   detail, Active workout). Right now everything is the same weight.
4. **The active-workout screen redesigned for one-thumb, mid-set use** — big
   tap targets, obvious "this is the set you're on", the rest timer impossible
   to miss.

## Hard constraints (these are not negotiable — flag anything that conflicts)

- **Native iOS 26 chrome stays native.** The tab bar, navigation bars, sheets,
  alerts and context menus are system Liquid Glass and will not be custom-drawn.
  Design *inside* them, don't replace them. If you show a tab bar, show the
  system floating glass tab bar, not a custom one.
- **Glass on chrome only, never on content.** Cards, rows, tables and charts sit
  on solid, opaque surfaces. No frosted cards, no translucent lists.
- **Five tabs, fixed:** Home · Workout · Exercises · History · Settings. Don't
  add, remove or rename.
- **No decorative imagery**, no stock photos, no illustrations of muscles or
  people. Numbers and structure are the visuals.
- **SF Pro** (system font) unless you have a strong reason. If you propose
  another face, it must be freely licensable and ship with the app.
- **SF Symbols** for iconography. Name the symbol you intend where it matters.
- **Every screen must work at Dynamic Type "Large" (default) and survive
  "xLarge"**. Don't design layouts that only work at one text size.
- Weights display in the user's chosen unit (kg or lb) — never assume one.
- Keep it buildable in SwiftUI without custom drawing beyond what's listed in
  "what's already custom" below. If a treatment would need a bespoke UIKit
  component, say so.

## What's already custom (fair game to restyle)

- The **consistency heatmap** (GitHub-style, 18 weeks × 7 days, 5 intensity
  levels, month labels on top).
- The **30-day volume bar chart** and **per-exercise trend line chart** (both
  Swift Charts — restylable: colours, gridlines, point marks, axis treatment).
- The **exercise card** and **set row** on the active-workout screen (custom
  views, fully restylable).
- The **rest timer bar** pinned above the tab bar during a workout.
- The **streak cards** on Home.

## The screens (see `screens/` — current state, iPhone 14 Plus, light mode)

Each note says what the screen is for and what's wrong with it now.

### 00 — App icon (`00-icon-light.png`, `00-icon-dark.png`)
The identity anchor. 7×7 grid of rounded cells; the filled cells form a
standing lifter holding a bar (the bar is the full middle row). Blue
`#3E82F7` on light, `#5BA8F5` on dark; bar is near-black / near-white.

### 01 — Home (`01-home.png`, `01b-home-scrolled.png`)
Purpose: "am I consistent, and what did I do lately?"
Content, top to bottom: current streak + longest streak · consistency heatmap
with legend · this week (workouts, volume) · last-30-days volume bar chart ·
recent records list (exercise, record type, when).
Problems: streak cards and stat rows have no hierarchy; the heatmap floats with
no framing; five equal white cards on grey. The streak — the single most
motivating number — doesn't feel like a headline.

### 02 — Workout tab (`02-workout.png`)
Purpose: pick a routine and go.
A list of routines, each with exercise count, "last performed", and a Start
button. Tap the row for detail, tap Start to begin immediately.
Problems: it's a plain list. Start should be the most obvious thing on screen.
Also **needs a "Workout in progress — resume" state** at the top when a session
is already running (doesn't exist yet visually; design it).

### 08 — Routine detail (`08-routine-detail.png`)
Purpose: preview a routine before starting. Facts (last performed, estimated
duration), the exercise list with set × rep targets, and a Start Workout
button pinned at the bottom.
Problems: fine structurally; just needs the system applied.

### 09 — Active workout (`09-active-workout.png`) — **the most important screen**
Purpose: log sets during the workout.
Structure: nav bar with routine name + elapsed timer, `···` menu, Finish. One
card per exercise: name, target ("4 × 5"), "Last: 120 kg × 5" reference line,
then set rows, then "Add set". Bottom: "Add exercise".
A set row is: set number (or "W" for warm-up) · weight field · reps field ·
RPE picker · done-tick. When a set is ticked, a rest-timer bar appears pinned
above the tab bar with −30 / countdown / +30 / Skip.
Problems: rows are small and undifferentiated; the current/next set is not
highlighted; the "Last:" reference is easy to miss but is the whole point
(it's what tells you what to beat); done state is just a blue tick; the rest
timer is quiet. Design this for a sweaty thumb.
Notes: the weight field shows a number pad with a Done button above it. Numbers
must remain editable text fields (not steppers) — typing "112.5" must be fast.

### 03 — Exercises (`03-exercises.png`)
Purpose: browse the library, grouped by body part (Back, Biceps, Chest, Core,
Glutes, Hamstrings, Quads, Shoulders, Triceps, Calves, Other). Search on top.
Badges: "BW" for bodyweight, "×2" for unilateral. Tap → detail.
Problems: fine as a list; badges could be more considered.

### 04 — Exercise detail (`04-exercise-detail.png`)
Purpose: one exercise's records and trend.
Facts (body part, sessions, last performed) · lifetime records (heaviest, most
reps, best est. 1RM) · trend chart with metric toggle (Est. 1RM / Volume, or
Max reps / Added weight for bodyweight moves) and range control (8W / 6M / 1Y /
All).
Problems: records should feel like records — they're currently a settings
list. The chart's two segmented controls stacked on top of each other are
clunky.

### 05 — History (`05-history.png`)
Purpose: past workouts, grouped by month, newest first. Row: routine name,
date · duration · volume. Sort/filter menu in the toolbar. Swipe to delete.
Problems: plain list; volume and duration could be scannable at a glance.

### 06 — Session detail (`06-session-detail.png`)
Purpose: everything logged in one past workout, and it's editable (same set
rows as the active workout). Header facts: date, duration, volume.
Problems: identical to the active workout rows — that's intentional
(one component), so whatever you design for 09 applies here. It should read
as "a record" rather than "in progress", though — no rest timer, no
elapsed clock.

### 07 — Settings (`07-settings.png`)
Weight unit (kg/lb), default rest seconds, version. Plain system settings
list is acceptable here; just make it consistent.

## Tone

Quiet, dense, confident. Think a well-made instrument, not a fitness brand.
No gradients-for-the-sake-of-it, no neon, no "crush your goals" energy. The
blue from the icon is the one accent; use it for the things that matter
(the current set, Start, records) and keep everything else neutral. Grey
scale should be warm-neutral, not blue-tinted, so the accent stays special.

Reference points I like: Apple Fitness's use of big numbers on dark; the
restraint of Apple's Health app; Linear's density.

## Deliverables

1. A one-page style sheet: palette (light + dark, with hex), type scale, spacing
   scale, corner radii, card treatment, chart colours.
2. Light + dark mockups of screens 01, 02, 04, 05, 06, 09 (the rest can be
   described in words if they're just "apply the system").
3. For 09 specifically: three states — no sets logged yet · mid-workout with
   the rest timer running · a set row in its "done" state.
4. A short list of anything you designed that you think will be hard to build
   natively, so it can be argued about before code is written.
