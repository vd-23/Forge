import SwiftUI
import SwiftData

/// Settings for the automatic backup: pick a folder outside the app once,
/// and Forge keeps a daily copy there. The picker itself belongs to the
/// screen — SwiftUI shows only one `fileImporter` per view hierarchy.
struct AutoBackupSection: View {
    @Environment(\.modelContext) private var context
    @State private var backup = AutoBackup.shared
    let chooseFolder: () -> Void

    var body: some View {
        Section {
            if let folder = backup.folderName {
                LabeledContent("Folder", value: folder)
                LabeledContent("Last backup") {
                    if let last = backup.lastBackupAt {
                        Text(last, format: .relative(presentation: .named))
                    } else {
                        Text("Not yet")
                    }
                }
                if let lastError = backup.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                Button("Back up now", systemImage: "arrow.clockwise") {
                    backup.runQuietly(context: context)
                    if backup.lastError == nil { Haptics.success() }
                }
                Button("Change folder", systemImage: "folder") { chooseFolder() }
                Button("Turn off", role: .destructive) { backup.clearFolder() }
            } else {
                Button("Choose a folder", systemImage: "folder.badge.plus") { chooseFolder() }
            }
        } header: {
            SectionLabel("Automatic backup").textCase(nil)
        } footer: {
            Text(backup.isOn
                ? "Saved after every workout and whenever you leave the app. The last \(AutoBackup.defaultKeep) days are kept."
                : "Pick a folder in iCloud Drive so your data survives deleting the app or resetting the phone.")
        }
    }
}
