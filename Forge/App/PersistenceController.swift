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
