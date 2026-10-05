import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct WardrobeValueTests {
    let container = AppModelContainer.preview()
    var context: ModelContext { container.mainContext }

    private func garment(_ name: String) throws -> Garment {
        try #require(try context.fetch(FetchDescriptor<Garment>()).first { $0.name == name })
    }

    @Test func costPerWearAndPayoff() throws {
        let jeans = try garment("Vaqueros rectos") // 49 € y 22 puestas
        #expect(jeans.costPerWear == 49.0 / 22)
        #expect(WardrobeValue.Payoff.of(jeans) == .fair)

        let new = Garment(name: "Sin estrenar")
        context.insert(new)
        new.price = 30
        #expect(new.costPerWear == 30)
        #expect(WardrobeValue.Payoff.of(new) == .poor)
        new.wearCount = 40
        #expect(WardrobeValue.Payoff.of(new) == .good)
    }

    @Test func totalsAndSpendingByYear() throws {
        let garments = try context.fetch(FetchDescriptor<Garment>())
        let priced = WardrobeValue.priced(garments)
        #expect(priced.count == 11)
        #expect(WardrobeValue.total(priced) == 89 + 15 + 39 + 120 + 220 + 49 + 159 + 180 + 45 + 49 + 110)
        let byYear = WardrobeValue.spendingByYear(garments)
        #expect(byYear.map(\.amount).reduce(0, +) == WardrobeValue.total(priced))
        #expect(byYear.map(\.year) == byYear.map(\.year).sorted())
        // La más amortizada va primero.
        #expect(WardrobeValue.byCostPerWear(garments).first?.name == "Camiseta básica blanca")
    }

    @Test func wearingALookRecordsTheDate() throws {
        let outfit = try #require(try context.fetch(FetchDescriptor<Outfit>()).first { $0.name == "Oficina" })
        let shirt = try garment("Camisa de lino")
        let day = DateComponents(calendar: .current, year: 2026, month: 3, day: 14).date!
        let before = shirt.wearDates.count
        outfit.markWorn(on: day)
        #expect(shirt.wearDates.count == before + 1)
        #expect(outfit.wearDates.contains(day))
        // Anotar un día pasado no retrasa la última vez.
        #expect(shirt.lastWornAt! > day)
    }

    @Test func yearInReviewCountsOnlyThatYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        func date(_ year: Int, _ month: Int) -> Date { DateComponents(calendar: calendar, year: year, month: month, day: 10).date! }

        let shirt = Garment(name: "Camisa")
        let jeans = Garment(name: "Vaqueros", category: .trousers, colors: [.navy])
        let coat = Garment(name: "Abrigo", category: .coat, colors: [.black])
        for item in [shirt, jeans, coat] {
            context.insert(item)
            item.createdAt = date(2024, 1)
        }
        shirt.colors = [.white]
        let look = Outfit(name: "Diario", garments: [shirt, jeans])
        context.insert(look)
        look.markWorn(on: date(2025, 5))
        look.markWorn(on: date(2025, 6))
        jeans.markWorn(on: date(2025, 7))
        look.markWorn(on: date(2024, 2))
        coat.price = 100
        coat.purchasedAt = date(2025, 11)

        let review = YearInReview(year: 2025, garments: [shirt, jeans, coat], outfits: [look], calendar: calendar)
        #expect(review.looksWorn == 2)
        #expect(review.mostWornOutfit?.outfit === look)
        #expect(review.starGarment?.garment === jeans)
        #expect(review.starGarment?.count == 3)
        #expect(review.garmentsWorn == 2)
        #expect(review.notWorn == 1)
        #expect(review.topColors == [.navy, .white])
        #expect(review.spent == 100)
        #expect(review.newGarments == 0)
        #expect(YearInReview(year: 2023, garments: [shirt], outfits: [], calendar: calendar).garmentCount == 0)
    }

    @Test func gapsFindLooksWithMissingParts() throws {
        let shirt = Garment(name: "Camisa", category: .shirt)
        let shoes = Garment(name: "Zapatos", category: .shoes)
        let dress = Garment(name: "Vestido", category: .dress)
        let jeans = Garment(name: "Vaqueros", category: .trousers)
        for item in [shirt, shoes, dress, jeans] { context.insert(item) }
        let noShoes = Outfit(name: "Sin zapatos", garments: [shirt, jeans])
        let dressOnly = Outfit(name: "Vestido solo", garments: [dress])
        let topOnly = Outfit(name: "Solo camisa", garments: [shirt, shoes])
        let complete = Outfit(name: "Completo", garments: [shirt, jeans, shoes])
        for outfit in [noShoes, dressOnly, topOnly, complete] { context.insert(outfit) }

        #expect(WardrobeGaps.missingSlots(in: complete).isEmpty)
        #expect(WardrobeGaps.missingSlots(in: dressOnly) == [.feet])
        #expect(WardrobeGaps.missingSlots(in: topOnly) == [.bottom])
        let gaps = WardrobeGaps.gaps(in: [noShoes, dressOnly, topOnly, complete])
        #expect(gaps.first?.slot == .feet)
        #expect(gaps.first?.outfits.count == 2)
        #expect(gaps.map(\.slot) == [.feet, .bottom])
    }
}
