#!/usr/bin/env python3
"""Writes a .forgebackup with ~10 weeks of push/pull/legs training.

Used for the README screenshots: launch a Debug build with
`-demoBackupPath <file>` and the app restores it on start.

    python3 scripts/make-demo-backup.py /tmp/demo.forgebackup
"""
import json, random, sys, uuid
from datetime import datetime, timedelta, timezone

random.seed(7)
now = datetime.now(timezone.utc).replace(microsecond=0)
iso = lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ")
uid = lambda: str(uuid.uuid4()).upper()

# name, body part, bodyweight, unilateral, rest, start kg, weekly gain, reps
LIFTS = {
    "Barbell Bench Press":    ("chest", False, False, 180, 62.5, 1.0, (5, 8)),
    "Incline Dumbbell Press": ("chest", False, False, 120, 26, 0.5, (8, 12)),
    "Cable Fly":              ("chest", False, False, 90, 15, 0.25, (12, 15)),
    "Overhead Press":         ("shoulders", False, False, 150, 42.5, 0.6, (5, 8)),
    "Lateral Raise":          ("shoulders", False, False, 60, 9, 0.2, (12, 15)),
    "Triceps Pushdown":       ("triceps", False, False, 60, 27.5, 0.5, (10, 12)),
    "Deadlift":               ("back", False, False, 180, 110, 2.0, (3, 5)),
    "Pull-up":                ("back", True, False, 120, 0, 0.5, (6, 10)),
    "Barbell Row":            ("back", False, False, 120, 65, 1.25, (6, 10)),
    "Lat Pulldown":           ("back", False, False, 90, 55, 1, (10, 12)),
    "Face Pull":              ("shoulders", False, False, 60, 20, 0.25, (12, 15)),
    "Hammer Curl":            ("biceps", False, False, 60, 14, 0.25, (10, 12)),
    "Back Squat":             ("quads", False, False, 180, 85, 1.75, (5, 8)),
    "Romanian Deadlift":      ("hamstrings", False, False, 150, 80, 1.25, (8, 10)),
    "Leg Press":              ("quads", False, False, 120, 160, 5, (10, 12)),
    "Lying Leg Curl":         ("hamstrings", False, False, 90, 40, 0.75, (10, 12)),
    "Bulgarian Split Squat":  ("quads", False, True, 90, 16, 0.5, (8, 10)),
}
ROUTINES = [
    ("Push", ["Barbell Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Triceps Pushdown", "Cable Fly"]),
    ("Pull", ["Deadlift", "Pull-up", "Barbell Row", "Lat Pulldown", "Face Pull", "Hammer Curl"]),
    ("Legs", ["Back Squat", "Romanian Deadlift", "Leg Press", "Bulgarian Split Squat", "Lying Leg Curl"]),
    ("Upper", ["Barbell Bench Press", "Barbell Row", "Overhead Press", "Lat Pulldown", "Hammer Curl"]),
]
NOTES = {"Incline Dumbbell Press": "Bench on notch 3", "Triceps Pushdown": "Rope attachment", "Face Pull": "Rope, eye level"}

exercises, ids = [], {}
for name, (part, bw, uni, rest, *_ ) in LIFTS.items():
    ids[name] = uid()
    exercises.append({"id": ids[name], "name": name, "bodyPart": part, "isBodyweight": bw,
                      "isUnilateral": uni, "defaultRestSeconds": rest, "isArchived": False,
                      "createdAt": iso(now - timedelta(days=90))})

routines, routine_ids = [], {}
for order, (rname, lifts) in enumerate(ROUTINES):
    routine_ids[rname] = uid()
    items = []
    for i, lift in enumerate(lifts):
        lo, hi = LIFTS[lift][6]
        item = {"exerciseID": ids[lift], "order": i, "targetSets": 4 if i < 2 else 3,
                "targetRepMin": lo, "targetRepMax": hi}
        if lift in NOTES: item["note"] = NOTES[lift]
        items.append(item)
    routines.append({"id": routine_ids[rname], "name": rname, "isArchived": False,
                     "createdAt": iso(now - timedelta(days=90)), "sortOrder": order, "items": items})

sessions = []
day = (now - timedelta(days=124)).replace(hour=0, minute=0, second=0)
cycle = 0
while day.date() <= now.date():
    # Four or five sessions a week, the odd rest day skipped or doubled.
    if day.weekday() == 6 or random.random() < 0.07:
        day += timedelta(days=1); continue
    rname, lifts = ROUTINES[cycle % 4]
    cycle += 1
    weeks = (day - (now - timedelta(days=124))).days / 7
    start = day + timedelta(hours=random.choice([6, 7, 7, 8]), minutes=random.randint(0, 50))
    t = start
    session_exercises = []
    for order, lift in enumerate(lifts):
        part, bw, uni, rest, base, gain, (lo, hi) = LIFTS[lift]
        weight = round((base + gain * weeks) / 2.5) * 2.5 if not bw else None
        added = round(gain * weeks / 2.5) * 2.5 if bw else None
        sets = []
        for s in range(4 if order < 2 else 3):
            t += timedelta(seconds=rest + random.randint(20, 60))
            reps = max(lo, hi - s - random.randint(0, 1))
            sets.append({"order": s, "weightKg": weight, "addedWeightKg": added or None, "reps": reps,
                         "isWarmup": False, "isComplete": True, "completedAt": iso(t)})
        we = {"exerciseID": ids[lift], "order": order, "targetSets": len(sets), "targetRepMin": lo,
              "targetRepMax": hi, "restSeconds": rest, "sets": sets}
        if lift in NOTES: we["note"] = NOTES[lift]
        session_exercises.append(we)
    sessions.append({"id": uid(), "startedAt": iso(start), "endedAt": iso(t + timedelta(minutes=3)),
                     "sourceRoutineID": routine_ids[rname], "sourceRoutineName": rname,
                     "exercises": session_exercises})
    for r in routines:
        if r["name"] == rname: r["lastPerformedAt"] = iso(t)
    day += timedelta(days=1)

def strip(o):
    if isinstance(o, dict): return {k: strip(v) for k, v in o.items() if v is not None}
    if isinstance(o, list): return [strip(v) for v in o]
    return o

backup = {"version": 1, "exportedAt": iso(now), "customBodyParts": [],
          "preferences": {"weightUnit": "kg", "defaultRestSeconds": 120},
          "exercises": exercises, "routines": routines, "sessions": sessions}
json.dump(strip(backup), open(sys.argv[1], "w"), indent=1)
print(f"{len(sessions)} sessions → {sys.argv[1]}")
