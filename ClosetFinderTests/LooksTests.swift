import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct LooksTests {
    let container = AppModelContainer.preview()
    var context: ModelContext { container.mainContext }

    private func garment(_ name: String) throws -> Garment {
        try #require(try context.fetch(FetchDescriptor<Garment>()).first { $0.name == name })
    }

    private func outfit(_ name: String) throws -> Outfit {
        try #require(try context.fetch(FetchDescriptor<Outfit>()).first { $0.name == name })
    }

    @Test func everyCategoryHasASlot() {
        let covered = Set(OutfitSlot.allCases.flatMap(\.categories))
        #expect(covered == Set(GarmentCategory.allCases))
        #expect(OutfitSlot.slot(for: .coat) == .outer)
        #expect(OutfitSlot.slot(for: .dress) == .fullBody)
        #expect(OutfitSlot.top.maxItems == 2)
        #expect(OutfitSlot.bottom.maxItems == 1)
    }

    @Test func piecesGoFromTopToBottom() throws {
        let weekend = try outfit("Fin de semana")
        #expect(weekend.pieces.map(\.displayName) == ["Chaqueta vaquera", "Camiseta básica blanca", "Vaqueros rectos", "Zapatillas running"])
        #expect(weekend.pieces(in: .feet).map(\.displayName) == ["Zapatillas running"])
    }

    @Test func displayNameAndAvailability() throws {
        let polo = try garment("Polo rojo") // prestada en los datos de ejemplo
        let look = Outfit(garments: [polo])
        context.insert(look)
        #expect(look.displayName == "Look con Polo rojo")
        #expect(look.unavailablePieces.count == 1)
    }

    @Test func wearingALookWearsEveryPiece() throws {
        let office = try outfit("Oficina")
        let shirt = try garment("Camisa de lino")
        let before = shirt.wearCount
        office.markWorn()
        #expect(shirt.wearCount == before + 1)
        #expect(office.lastWornAt != nil)
    }

    @Test func weekStartsOnMondayInSpain() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2
        let thursday = DateComponents(calendar: calendar, year: 2026, month: 10, day: 1).date!
        let days = WeekPlanner.days(around: thursday, calendar: calendar)
        #expect(days.count == 7)
        #expect(calendar.component(.weekday, from: days[0]) == 2)
        #expect(calendar.component(.day, from: days[0]) == 28)
    }

    @Test func onlyOneLookPerDay() throws {
        let office = try outfit("Oficina")
        let summer = try outfit("Verano")
        let day = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        OutfitScheduler.plan(office, on: day, in: context)
        OutfitScheduler.plan(summer, on: day, in: context)
        let plans = try context.fetch(FetchDescriptor<OutfitPlan>()).filter { Calendar.current.isDate($0.day, inSameDayAs: day) }
        #expect(plans.count == 1)
        #expect(plans.first?.outfit === summer)
    }

    @Test func packingListHasNoRepeatsAndIsGroupedByPlace() throws {
        let trip = try #require(try context.fetch(FetchDescriptor<Trip>()).first)
        // «Día de nieve» y «Fin de semana» comparten los vaqueros: se cuentan una vez.
        let names = trip.packingList.map(\.displayName)
        #expect(names.filter { $0 == "Vaqueros rectos" }.count == 1)
        #expect(names.contains("Sudadera verde"))
        #expect(trip.packingListByLocation.flatMap(\.garments).count == trip.packingList.count)
        #expect(trip.dayCount == 3)

        let jeans = try garment("Vaqueros rectos")
        #expect(!trip.isPacked(jeans))
        trip.togglePacked(jeans)
        #expect(trip.isPacked(jeans))
        #expect(trip.packedCount == 2)
        trip.togglePacked(jeans)
        #expect(trip.packedCount == 1)
    }

    @Test func deletingALookKeepsGarmentsAndRemovesPlans() throws {
        let office = try outfit("Oficina")
        let shirt = try garment("Camisa de lino")
        context.delete(office)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<OutfitPlan>()).allSatisfy { $0.outfit != nil })
        #expect(!(shirt.outfits ?? []).contains { $0.name == "Oficina" })
        #expect(try context.fetchCount(FetchDescriptor<Garment>()) == 15)
    }
}
