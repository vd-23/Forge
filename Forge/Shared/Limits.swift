import Foundation
import SwiftUI

/// Hard bounds enforced at every input boundary. Numbers are clamped rather
/// than rejected: typing 5000 kg mid-set shouldn't throw an alert in your
/// face, it should just become the maximum.
enum Limits {
    static let maxNameLength = 60
    static let maxNotesLength = 2_000
    static let maxWeightKg: Double = 1_000
    static let maxReps = 500
    static let maxRPE: Double = 10
    static let maxSetsPerExercise = 30
    static let maxExercisesPerWorkout = 40
    static let maxItemsPerRoutine = 40
    static let maxRoutines = 100
    static let maxExercises = 500

    /// Trimmed, control characters collapsed, capped. `nil` when nothing is left.
    static func cleanName(_ raw: String, max: Int = maxNameLength) -> String? {
        let collapsed = raw
            .components(separatedBy: .controlCharacters.union(.newlines))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(max))
    }

    /// Non-positive or non-numeric means "not entered".
    static func clampWeightKg(_ value: Double) -> Double? {
        guard !value.isNaN, value > 0 else { return nil }
        return min(value, maxWeightKg)
    }

    static func clampReps(_ value: Int) -> Int {
        min(max(value, 0), maxReps)
    }
}

/// How much disk the store is using. Purely informational until it crosses
/// the budget, at which point Settings warns and suggests an export.
struct StoreHealth {
    /// Well under anything iOS would flinch at, but far more than a decade of
    /// daily logging produces — a ceiling that only a bug would hit.
    static let budgetBytes: Int64 = 200 * 1_024 * 1_024

    let bytes: Int64

    var isOverBudget: Bool { bytes > Self.budgetBytes }

    var label: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// SQLite keeps a WAL and SHM beside the main file; all three count.
    static func measure(storeURL: URL) -> StoreHealth {
        let paths = [storeURL.path, storeURL.path + "-wal", storeURL.path + "-shm"]
        let total = paths.reduce(Int64(0)) { sum, path in
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
            return sum + size
        }
        return StoreHealth(bytes: total)
    }
}

extension View {
    /// Stops a text field growing past `max` characters as the user types.
    func limitedLength(_ text: Binding<String>, max: Int = Limits.maxNameLength) -> some View {
        onChange(of: text.wrappedValue) { _, value in
            if value.count > max { text.wrappedValue = String(value.prefix(max)) }
        }
    }
}
