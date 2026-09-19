import Foundation
import SwiftData

/// Builds the app's SwiftData containers.
///
/// The store lives in the app's own Application Support directory. It was in an
/// App Group so an M3 widget could read the same database, but App Groups
/// require a paid Apple Developer Program membership — with a free personal
/// team the entitlement cannot be provisioned and code signing fails outright,
/// so the app never reaches the device. Sharing with a widget will need either
/// a paid account or an exported snapshot.
enum PersistenceController {
    static let storeName = "Forge.store"

    /// The on-disk location of the store, creating the directory if needed.
    static func storeURL() throws -> URL {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: storeName)
    }

    /// The main on-disk container. A failure here means the schema itself is
    /// unopenable — there is no safe way to continue, so we trap.
    static func makeSharedContainer() -> ModelContainer {
        let schema = Schema(forgeSchemaModels)
        do {
            let configuration = try ModelConfiguration(schema: schema, url: storeURL())
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
