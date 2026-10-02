import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct BackupTests {

    @Test func roundTripKeepsEverything() throws {
        let source = AppModelContainer.preview().mainContext
        let original = try source.fetch(FetchDescriptor<Garment>())
        let jacket = try #require(original.first { $0.name == "Chaqueta vaquera" })
        jacket.photo = Data([1, 2, 3])

        let data = try BackupService.makeArchive(from: source).encoded()
        let target = AppModelContainer.make(inMemory: true).mainContext
        let summary = try BackupService.restore(BackupArchive.decode(data), into: target)

        #expect(summary.garments == original.count)
        #expect(summary.locations == (try source.fetchCount(FetchDescriptor<StorageLocation>())))
        #expect(summary.profiles == 1)
        #expect(summary.skipped == 0)

        let restored = try #require(try target.fetch(FetchDescriptor<Garment>()).first { $0.uuid == jacket.uuid })
        #expect(restored.location?.path == "Dormitorio › Armario grande › Balda 2")
        #expect(restored.owner?.name == "Yo")
        #expect(restored.photo == Data([1, 2, 3]))
        #expect(restored.chestWidthCm == 54)
        #expect(restored.colors == [.blue])
    }

    @Test func restoringTwiceDoesNotDuplicate() throws {
        let source = AppModelContainer.preview().mainContext
        let archive = try BackupService.makeArchive(from: source)
        let target = AppModelContainer.make(inMemory: true).mainContext
        try BackupService.restore(archive, into: target)
        let second = try BackupService.restore(archive, into: target)

        #expect(second.garments == 0)
        #expect(second.locations == 0)
        #expect(second.skipped == archive.garments.count + archive.locations.count + archive.profiles.count)
        #expect(try target.fetchCount(FetchDescriptor<Garment>()) == archive.garments.count)
    }

    @Test func rejectsNewerVersions() throws {
        var archive = BackupArchive()
        archive.version = BackupArchive.currentVersion + 1
        let target = AppModelContainer.make(inMemory: true).mainContext
        #expect(throws: BackupService.BackupError.self) {
            try BackupService.restore(archive, into: target)
        }
    }
}
