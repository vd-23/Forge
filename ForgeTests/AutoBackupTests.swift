import Testing
import Foundation
import SwiftData
@testable import Forge

@Suite @MainActor
struct AutoBackupTests {
    let folder: URL
    let defaults = UserDefaults(suiteName: "AutoBackupTests-\(UUID().uuidString)")!
    let container = PersistenceController.makeInMemoryContainer()

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "AutoBackupTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400) }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path()).sorted()
    }

    @Test func writesOneFilePerDayNamedByDate() throws {
        let url = try AutoBackup.write(Data("a".utf8), to: folder, now: day(0))
        #expect(url.lastPathComponent.hasPrefix("Forge "))
        #expect(url.pathExtension == BackupCoder.fileExtension)
        #expect(try Data(contentsOf: url) == Data("a".utf8))
    }

    @Test func aSecondBackupTheSameDayReplacesTheFirst() throws {
        _ = try AutoBackup.write(Data("a".utf8), to: folder, now: day(0))
        let url = try AutoBackup.write(Data("b".utf8), to: folder, now: day(0).addingTimeInterval(3600))
        #expect(try files().count == 1)
        #expect(try Data(contentsOf: url) == Data("b".utf8))
    }

    @Test func onlyTheNewestDaysAreKept() throws {
        for n in 0..<5 { _ = try AutoBackup.write(Data("\(n)".utf8), to: folder, now: day(n), keep: 3) }
        let kept = try files()
        #expect(kept.count == 3)
        #expect(kept.last == AutoBackup.fileName(for: day(4)))
        #expect(!kept.contains(AutoBackup.fileName(for: day(0))))
    }

    @Test func otherFilesInTheFolderAreLeftAlone() throws {
        let mine = folder.appending(path: "notes.txt")
        try Data("x".utf8).write(to: mine)
        for n in 0..<3 { _ = try AutoBackup.write(Data(), to: folder, now: day(n), keep: 1) }
        #expect(FileManager.default.fileExists(atPath: mine.path()))
    }

    @Test func aWrittenBackupRestoresTheData() throws {
        let ctx = container.mainContext
        ctx.insert(Routine(name: "Push"))
        try ctx.save()

        let backup = AutoBackup(defaults: defaults, folderAccess: { folder })
        try backup.run(context: ctx, now: day(0))

        let written = try Data(contentsOf: folder.appending(path: AutoBackup.fileName(for: day(0))))
        #expect(try BackupCoder.decode(written).routines.map(\.name) == ["Push"])
        #expect(backup.lastBackupAt == day(0))
    }

    @Test func withoutAFolderNothingIsWritten() throws {
        let backup = AutoBackup(defaults: defaults, folderAccess: { nil })
        try backup.run(context: container.mainContext, now: day(0))
        #expect(try files().isEmpty)
        #expect(backup.lastBackupAt == nil)
    }
}
