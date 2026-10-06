import Foundation
import Observation
import SwiftData

/// Writes a backup to a folder the user picked — iCloud Drive, say — so their
/// data outlives the app. Deleting an app deletes everything in its container,
/// and with free signing the app expires weekly; this is the copy that
/// survives that.
///
/// One file per day ("Forge 2026-10-06.forgebackup"), overwritten through the
/// day, keeping the newest `keep` days.
@Observable
@MainActor
final class AutoBackup {
    static let shared = AutoBackup()
    static let defaultKeep = 30

    private enum Key {
        static let bookmark = "autoBackup.folderBookmark"
        static let lastAt = "autoBackup.lastAt"
    }

    private let defaults: UserDefaults
    /// The chosen folder, or nil when none is set. Injected so tests can use a
    /// plain temporary directory.
    private let folderAccess: () -> URL?

    private(set) var lastBackupAt: Date?
    private(set) var lastError: String?
    private(set) var folderName: String?

    init(defaults: UserDefaults = Preferences.defaults, folderAccess: (() -> URL?)? = nil) {
        self.defaults = defaults
        self.folderAccess = folderAccess ?? { Self.resolveBookmark(in: defaults) }
        lastBackupAt = defaults.object(forKey: Key.lastAt) as? Date
        folderName = self.folderAccess()?.lastPathComponent
    }

    var isOn: Bool { folderName != nil }

    // MARK: Folder

    /// Remembers a folder from the document picker. The bookmark keeps access
    /// across launches without asking again.
    func setFolder(_ url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData()
        defaults.set(bookmark, forKey: Key.bookmark)
        folderName = url.lastPathComponent
        lastError = nil
    }

    func clearFolder() {
        defaults.removeObject(forKey: Key.bookmark)
        folderName = nil
        lastError = nil
    }

    private static func resolveBookmark(in defaults: UserDefaults) -> URL? {
        guard let data = defaults.data(forKey: Key.bookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Key.bookmark) }
        }
        return url
    }

    // MARK: Running

    /// Backs up now if a folder is set. Errors are kept for Settings to show
    /// rather than thrown at whatever triggered the backup.
    func runQuietly(context: ModelContext) {
        do {
            try run(context: context)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func run(context: ModelContext, now: Date = .now) throws {
        guard let folder = folderAccess() else { return }
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

        let data = try BackupCoder.export(from: context, defaults: defaults)
        try Self.write(data, to: folder, now: now)
        lastBackupAt = now
        lastError = nil
        defaults.set(now, forKey: Key.lastAt)
    }

    // MARK: Files

    static func fileName(for date: Date) -> String {
        "Forge \(Date.ISO8601FormatStyle(timeZone: .current).year().month().day().format(date)).\(BackupCoder.fileExtension)"
    }

    /// Writes today's file and prunes the oldest beyond `keep`. Only files this
    /// writes are ever removed. Coordinated, so iCloud Drive sees a clean write.
    @discardableResult
    static func write(_ data: Data, to folder: URL, now: Date, keep: Int = defaultKeep) throws -> URL {
        let url = folder.appending(path: fileName(for: now))
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }

        let fm = FileManager.default
        let ours = try fm.contentsOfDirectory(atPath: folder.path())
            .filter { $0.hasPrefix("Forge ") && $0.hasSuffix(".\(BackupCoder.fileExtension)") }
            .sorted()
        for name in ours.dropLast(max(keep, 1)) {
            try? fm.removeItem(at: folder.appending(path: name))
        }
        return url
    }
}
