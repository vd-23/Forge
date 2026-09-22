import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup and restore. Export writes a `.forgebackup` JSON file and hands it
/// to the share sheet; import reads one back and replaces everything.
struct DataView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var controller

    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var result: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Button("Export backup", systemImage: "square.and.arrow.up", action: export)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share last export", systemImage: "paperplane")
                    }
                }
            } header: {
                SectionLabel("Export").textCase(nil)
            } footer: {
                Text("Everything — exercises, routines, history, body parts and settings — as one JSON file.")
            }

            Section {
                Button("Import backup", systemImage: "square.and.arrow.down") { importing = true }
                    .disabled(controller.hasActiveSession)
            } header: {
                SectionLabel("Import").textCase(nil)
            } footer: {
                Text(controller.hasActiveSession
                    ? "Finish or discard the running workout first."
                    : "Replaces everything on this device with the file's contents. Export first if you want a way back.")
            }
        }
        .forgeForm()
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .forgeBackup]) { outcome in
            switch outcome {
            case let .success(url): pendingImport = url
            case let .failure(err): error = err.localizedDescription
            }
        }
        .alert("Replace all data?", isPresented: Binding(
            get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }
        ), presenting: pendingImport) { url in
            Button("Replace", role: .destructive) { restore(from: url) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { url in
            Text("Everything currently in Forge will be deleted and replaced with \(url.lastPathComponent).")
        }
        .alert("Done", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK") { result = nil }
        } message: {
            Text(result ?? "")
        }
        .alert("Couldn't do that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func export() {
        do {
            let data = try BackupCoder.export(from: context)
            let stamp = Date.now.formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Forge \(stamp)")
                .appendingPathExtension(BackupCoder.fileExtension)
            try data.write(to: url, options: .atomic)
            exportURL = url
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore(from url: URL) {
        pendingImport = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let summary = try BackupCoder.restore(data, into: context)
            Haptics.success()
            result = "Restored \(summary.exercises) exercises, \(summary.routines) routines and \(summary.sessions) workouts."
        } catch BackupCoder.Error.unsupportedVersion(let version) {
            error = "This backup is from a newer Forge (format \(version))."
        } catch BackupCoder.Error.malformed {
            error = "That file isn't a Forge backup."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension UTType {
    static let forgeBackup = UTType(exportedAs: "com.forge.gym.backup", conformingTo: .json)
}
