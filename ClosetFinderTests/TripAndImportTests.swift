import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

/// Maleta según el destino, importación en lote, primer arranque y recientes.
@MainActor
struct TripAndImportTests {
    let container = AppModelContainer.preview()
    var context: ModelContext { container.mainContext }

    private var trip: Trip { get throws { try #require(try context.fetch(FetchDescriptor<Trip>()).first) } }

    // MARK: Maleta según el destino

    @Test func seasonDependsOnMonthAndHemisphere() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let january = DateComponents(calendar: calendar, year: 2027, month: 1, day: 15).date!
        let april = DateComponents(calendar: calendar, year: 2027, month: 4, day: 15).date!
        let july = DateComponents(calendar: calendar, year: 2027, month: 7, day: 15).date!
        #expect(PackingAdvisor.season(start: january, latitude: 40, calendar: calendar) == .autumnWinter)
        #expect(PackingAdvisor.season(start: january, latitude: -34, calendar: calendar) == .springSummer)
        #expect(PackingAdvisor.season(start: july, latitude: nil, calendar: calendar) == .springSummer)
        #expect(PackingAdvisor.season(start: july, latitude: -34, calendar: calendar) == .autumnWinter)
        #expect(PackingAdvisor.season(start: april, latitude: nil, calendar: calendar) == .midSeason)
    }

    @Test func layersFollowTheSeason() {
        #expect(PackingAdvisor.layers(for: .autumnWinter) == [.coat, .warmLayer])
        #expect(PackingAdvisor.layers(for: .midSeason) == [.lightJacket, .warmLayer])
        #expect(PackingAdvisor.layers(for: .springSummer) == [.light, .swimwear])
    }

    @Test func adviceSuggestsWhatIsMissingAndFittingLooks() throws {
        let trip = try trip // «Día de nieve» y «Fin de semana», 3 días
        let garments = try context.fetch(FetchDescriptor<Garment>())
        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        let advice = PackingAdvisor.advice(for: trip, season: .autumnWinter, closet: garments, outfits: outfits)

        #expect(advice.lookCount == 3)
        // El plumífero (en «Día de nieve») ya cubre el abrigo y el jersey burdeos, la capa de abrigo.
        #expect(advice.layers.allSatisfy { $0.isCovered })
        // Falta un look: «Verano» no encaja con el frío; «Oficina» sí.
        #expect(advice.outfits.map(\.name) == ["Oficina"])

        let summer = PackingAdvisor.advice(for: trip, season: .springSummer, closet: garments, outfits: outfits)
        let swim = try #require(summer.layers.first { $0.layer == .swimwear })
        #expect(!swim.isCovered)
        #expect(swim.suggestion?.name == "Bañador estampado")
        let summerLook = try #require(outfits.first { $0.name == "Verano" })
        #expect(PackingAdvisor.score(summerLook, for: .springSummer) > 0)
    }

    @Test func longTripsNeedAtMostSevenLooks() {
        #expect(PackingAdvisor.lookCount(forDays: 3) == 3)
        #expect(PackingAdvisor.lookCount(forDays: 12) == 7)
        #expect(PackingAdvisor.lookCount(forDays: 0) == 1)
    }

    // MARK: Importación en lote

    nonisolated private static func sample(_ category: GarmentCategory?) -> ProcessedImage {
        ProcessedImage(photo: Data([1]), thumbnail: Data([2]), isCutout: true, colors: [.blue], category: category)
    }

    @Test func batchImportProcessesReviewsAndSaves() async throws {
        let model = BatchImportModel()
        let categories: [GarmentCategory?] = [.tShirt, nil, .shoes, nil, .coat, .dress]
        let loaders: [BatchImportModel.DataLoader] = categories.indices.map { index in
            { Data([UInt8(index)]) }
        }
        // Una foto que no se puede leer.
        let failing: BatchImportModel.DataLoader = { nil }
        await model.process(loaders + [failing]) { data in
            Self.sample(categories[Int(data[0])])
        }
        #expect(model.items.count == 7)
        #expect(!model.isProcessing)
        #expect(model.addable.count == 4)
        #expect(model.reviewCount == 2)
        #expect(model.failedCount == 1)

        let unknown = try #require(model.items.first { $0.needsReview })
        model.review(unknown.id, category: .skirt, colors: [.black])
        let failed = try #require(model.items.first { $0.state == .failed })
        model.remove(failed.id)
        #expect(model.addable.count == 5)
        #expect(model.items.count == 6)

        let location = StorageLocation(name: "Cajón", kind: .drawer)
        context.insert(location)
        model.location = location
        model.season = .springSummer
        let before = try context.fetchCount(FetchDescriptor<Garment>())
        let saved = model.save(in: context)
        #expect(saved.count == 5)
        #expect(try context.fetchCount(FetchDescriptor<Garment>()) == before + 5)
        #expect(saved.allSatisfy { $0.location === location && $0.season == .springSummer && $0.hasCutout })
        #expect(saved.contains { $0.category == .skirt && $0.colors == [.black] })
    }

    @Test func batchImportStopsAtFiftyPhotos() async {
        let model = BatchImportModel()
        let loaders: [BatchImportModel.DataLoader] = (0..<60).map { _ in { Data([0]) } }
        await model.process(loaders) { _ in Self.sample(.tShirt) }
        #expect(model.items.count == BatchImportModel.maxPhotos)
        #expect(model.remainingSlots == 0)
    }

    // MARK: Primer arranque

    @Test func homeSetupCreatesRoomsFurnitureAndCompartments() throws {
        let empty = AppModelContainer.make(inMemory: true)
        var rooms = RoomDraft.defaults
        #expect(rooms.filter(\.isIncluded).count == 2)
        rooms[1].toggle(.box) // Entrada: zapatero y caja
        rooms[0].toggle(.dresser) // Dormitorio: solo armario
        HomeSetup.create(rooms, in: empty.mainContext)

        let all = try empty.mainContext.fetch(FetchDescriptor<StorageLocation>())
        let roots = all.filter { $0.parent == nil }.sorted { $0.sortIndex < $1.sortIndex }
        #expect(roots.map(\.name) == ["Dormitorio", "Entrada"])
        #expect(roots[0].sortedChildren.map(\.kind) == [.wardrobe])
        #expect(roots[0].sortedChildren[0].children?.count == LocationKind.wardrobe.template.count)
        #expect(roots[1].sortedChildren.map(\.kind) == [.shoeRack, .box])
        #expect(rooms[1].furniture == [.shoeRack, .box])
    }

    // MARK: Recientes

    @Test func recentHistoryKeepsTheLatestWithoutRepeats() {
        var storage = ""
        for query in ["chaqueta", "Vaqueros", "abrigo", "vaqueros"] {
            storage = RecentHistory.adding(query, to: storage, limit: 3, caseInsensitive: true)
        }
        #expect(RecentHistory.decode(storage) == ["vaqueros", "abrigo", "chaqueta"])
        storage = RecentHistory.adding("bufanda", to: storage, limit: 3)
        #expect(RecentHistory.decode(storage) == ["bufanda", "vaqueros", "abrigo"])
        #expect(RecentHistory.decode(RecentHistory.removing("vaqueros", from: storage)) == ["bufanda", "abrigo"])
        #expect(RecentHistory.adding("   ", to: storage, limit: 3) == storage)

        let defaults = UserDefaults(suiteName: "RecentHistoryTests")!
        defaults.removePersistentDomain(forName: "RecentHistoryTests")
        let id = UUID()
        RecentHistory.recordGarment(id, defaults: defaults)
        RecentHistory.recordGarment(UUID(), defaults: defaults)
        RecentHistory.recordGarment(id, defaults: defaults)
        #expect(RecentHistory.decode(defaults.string(forKey: RecentHistory.garmentsKey) ?? "").first == id.uuidString)
        #expect(RecentHistory.decode(defaults.string(forKey: RecentHistory.garmentsKey) ?? "").count == 2)
    }
}
