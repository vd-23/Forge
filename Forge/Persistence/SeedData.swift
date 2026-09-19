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
