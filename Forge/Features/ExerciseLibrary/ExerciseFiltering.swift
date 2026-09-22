import Foundation

/// Search + body-part pill filtering for the exercise library.
enum ExerciseFiltering {
    static func filter(_ exercises: [Exercise], search: String, bodyPart: BodyPart?) -> [Exercise] {
        exercises.filter { exercise in
            (bodyPart == nil || exercise.primaryBodyPart == bodyPart)
                && (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search))
        }
    }

    /// The body parts that have at least one exercise, by display name, so the
    /// pill row never offers a filter that would show nothing.
    static func bodyParts(in exercises: [Exercise]) -> [BodyPart] {
        Array(Set(exercises.map(\.primaryBodyPart)))
            .sorted { $0.displayName < $1.displayName }
    }
}
