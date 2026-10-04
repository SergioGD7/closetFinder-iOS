import Foundation
import SwiftData
import Testing
@testable import ClosetFinder

/// Generador determinista para probar el dado.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@MainActor
struct FittingRoomTests {
    let container = AppModelContainer.preview()
    var context: ModelContext { container.mainContext }
    var garments: [Garment] { (try? context.fetch(FetchDescriptor<Garment>())) ?? [] }

    private func outfit(_ name: String) throws -> Outfit {
        try #require(try context.fetch(FetchDescriptor<Outfit>()).first { $0.name == name })
    }

    @Test func startsFromAnExistingLook() throws {
        let weekend = try outfit("Fin de semana")
        let model = FittingRoomModel(garments: garments, outfit: weekend)
        #expect(model.layout == .layered) // lleva chaqueta
        #expect(Set(model.selectedGarments.map(\.displayName)) == Set(weekend.pieces.map(\.displayName)))
        #expect(model.pinned == Set(weekend.pieces.map { OutfitSlot.slot(for: $0.category) }))
    }

    @Test func optionalRowsCanBeEmpty() {
        let model = FittingRoomModel(garments: garments)
        #expect(model.items(for: .outer).first == FittingRoomModel.noneID)
        #expect(model.items(for: .top).first != FittingRoomModel.noneID)
        model.layout = .layered
        model.selection[.outer] = FittingRoomModel.noneID
        #expect(!model.selectedGarments.contains { OutfitSlot.slot(for: $0.category) == .outer })
    }

    @Test func unavailableGarmentsAreNotOffered() {
        let model = FittingRoomModel(garments: garments)
        let tops = model.items(for: .top).compactMap { model.garment($0, in: .top)?.displayName }
        #expect(!tops.contains("Polo rojo")) // prestada
    }

    @Test func shuffleKeepsPinnedRowsAndChangesTheOthers() {
        let model = FittingRoomModel(garments: garments)
        model.layout = .basic
        model.pinned = [.bottom]
        let before = model.selection
        var generator = SeededGenerator(state: 42)
        model.shuffle(using: &generator)
        #expect(model.selection[.bottom] == before[.bottom])
        #expect(model.selection[.top] != before[.top])
        #expect(model.selection[.feet] != before[.feet])
        #expect(model.selectedGarments.count == 3)
    }

    @Test func preselectedGarmentIsPinned() throws {
        let jacket = try #require(garments.first { $0.name == "Chaqueta vaquera" })
        let model = FittingRoomModel(garments: garments, preselected: [jacket])
        #expect(model.layout == .layered)
        #expect(model.selectedGarment(in: .outer) === jacket)
        #expect(model.pinned.contains(.outer))
        #expect(model.suggestedName == "Look con Chaqueta vaquera")
    }

    @Test func dressLayoutHasNoSeparateTopOrBottom() {
        #expect(FittingLayout.dress.slots == [.outer, .fullBody, .feet])
        #expect(FittingLayout.best(for: []) == .basic)
    }
}

@MainActor
struct WidgetResolverTests {
    let container = AppModelContainer.preview()
    var context: ModelContext { container.mainContext }
    var garments: [Garment] { (try? context.fetch(FetchDescriptor<Garment>())) ?? [] }

    @Test func eachKindPicksItsGarments() throws {
        let lent = ClosetWidgetResolver.garments(for: .lent, in: garments).map(\.displayName)
        #expect(lent == ["Polo rojo"])
        let favorites = ClosetWidgetResolver.garments(for: .favorites, in: garments).map(\.displayName)
        #expect(Set(favorites) == ["Chaqueta vaquera", "Zapatillas running"])
        let shoes = ClosetWidgetResolver.garments(for: .category, category: .shoes, in: garments).map(\.displayName)
        #expect(shoes == ["Botas de montaña", "Zapatillas running"])
        #expect(ClosetWidgetResolver.garments(for: .category, in: garments).isEmpty)
        #expect(ClosetWidgetResolver.garments(for: .toDonate, in: garments).isEmpty)
    }

    @Test func todayLookComesFromTheWeekPlan() throws {
        let plans = try context.fetch(FetchDescriptor<OutfitPlan>())
        let office = try #require(try context.fetch(FetchDescriptor<Outfit>()).first { $0.name == "Oficina" })
        let tomorrow = Calendar.current.date(byAdding: .day, value: 400, to: .now)!
        OutfitScheduler.plan(office, on: tomorrow, in: context)
        let updated = try context.fetch(FetchDescriptor<OutfitPlan>())
        #expect(updated.count == plans.count + 1)
        let pieces = ClosetWidgetResolver.garments(for: .todayLook, in: garments, plans: updated, now: tomorrow)
        #expect(Set(pieces.map(\.displayName)) == Set(office.pieces.map(\.displayName)))
    }

    @Test func detailDependsOnTheKind() throws {
        let polo = try #require(garments.first { $0.name == "Polo rojo" })
        #expect(ClosetWidgetResolver.detail(for: polo, kind: .lent) == "Prestada")
        #expect(ClosetWidgetResolver.detail(for: polo, kind: .favorites) == "Talla M")
    }
}
