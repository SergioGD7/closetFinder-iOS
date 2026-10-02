import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct BackupTests {

    @Test func roundTripKeepsEverything() throws {
        let sourceContainer = AppModelContainer.preview()
        let source = sourceContainer.mainContext
        let original = try source.fetch(FetchDescriptor<Garment>())
        let jacket = try #require(original.first { $0.name == "Chaqueta vaquera" })
        jacket.photo = Data([1, 2, 3])

        let data = try BackupService.makeArchive(from: source).encoded()
        // El contenedor tiene que seguir vivo mientras se use su contexto.
        let targetContainer = AppModelContainer.make(inMemory: true)
        let target = targetContainer.mainContext
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
        let sourceContainer = AppModelContainer.preview()
        let source = sourceContainer.mainContext
        let archive = try BackupService.makeArchive(from: source)
        // El contenedor tiene que seguir vivo mientras se use su contexto.
        let targetContainer = AppModelContainer.make(inMemory: true)
        let target = targetContainer.mainContext
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
        // El contenedor tiene que seguir vivo mientras se use su contexto.
        let targetContainer = AppModelContainer.make(inMemory: true)
        let target = targetContainer.mainContext
        #expect(throws: BackupService.BackupError.self) {
            try BackupService.restore(archive, into: target)
        }
    }
}
