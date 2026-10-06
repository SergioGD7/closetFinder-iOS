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
        #expect(restored.owner?.name == "Alex")
        #expect(restored.photo == Data([1, 2, 3]))
        #expect(restored.chestWidthCm == 54)
        #expect(restored.colors == [.blue])

        // Looks, semana y maletas (versión 2)
        #expect(summary.outfits == 4)
        #expect(summary.trips == 1)
        let trip = try #require(try target.fetch(FetchDescriptor<Trip>()).first)
        #expect(trip.sortedOutfits.count == 2)
        #expect(trip.packedCount == 1)
        #expect(try target.fetchCount(FetchDescriptor<OutfitPlan>()) == 5)
        let weekend = try #require(try target.fetch(FetchDescriptor<Outfit>()).first { $0.name == "Fin de semana" })
        #expect(weekend.pieces.map(\.displayName).contains("Chaqueta vaquera"))
    }

    @Test func keepsPricesCareWearDatesAndDestination() throws {
        // Versión 3: precio, cuidados, días de uso y destino de la maleta.
        let sourceContainer = AppModelContainer.preview()
        let source = sourceContainer.mainContext
        let jacket = try #require(try source.fetch(FetchDescriptor<Garment>()).first { $0.name == "Chaqueta vaquera" })
        let data = try BackupService.makeArchive(from: source).encoded()
        let targetContainer = AppModelContainer.make(inMemory: true)
        let target = targetContainer.mainContext
        try BackupService.restore(BackupArchive.decode(data), into: target)

        let restored = try #require(try target.fetch(FetchDescriptor<Garment>()).first { $0.uuid == jacket.uuid })
        #expect(restored.price == 89)
        #expect(restored.purchasedAt == jacket.purchasedAt)
        #expect(restored.care == [.wash30, .noBleach, .noTumbleDry])
        #expect(restored.wearDates.count == jacket.wearDates.count)
        let trip = try #require(try target.fetch(FetchDescriptor<Trip>()).first)
        #expect(trip.destination == "Navacerrada")
        #expect(trip.latitude == 40.7838)
        let office = try #require(try target.fetch(FetchDescriptor<Outfit>()).first { $0.name == "Oficina" })
        #expect(office.wearDates.count == 6)
    }

    @Test func readsVersionOneBackups() throws {
        // Una copia antigua no tiene looks ni maletas: se restaura igual.
        let sourceContainer = AppModelContainer.preview()
        var archive = try BackupService.makeArchive(from: sourceContainer.mainContext)
        archive.version = 1
        archive.outfits = nil
        archive.plans = nil
        archive.trips = nil
        let decoded = try BackupArchive.decode(archive.encoded())
        let targetContainer = AppModelContainer.make(inMemory: true)
        let summary = try BackupService.restore(decoded, into: targetContainer.mainContext)
        #expect(summary.garments == archive.garments.count)
        #expect(summary.outfits == 0)
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
        #expect(second.outfits == 0)
        #expect(second.skipped == archive.garments.count + archive.locations.count + archive.profiles.count
                + (archive.outfits?.count ?? 0) + (archive.trips?.count ?? 0))
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
