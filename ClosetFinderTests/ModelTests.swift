import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct ModelTests {
    let container = AppModelContainer.make(inMemory: true)
    var context: ModelContext { container.mainContext }

    private func location(_ name: String, _ kind: LocationKind, in parent: StorageLocation? = nil) -> StorageLocation {
        let location = StorageLocation(name: name, kind: kind)
        context.insert(location)
        location.parent = parent
        return location
    }

    @Test func locationPathAndCounts() throws {
        let bedroom = location("Dormitorio", .room)
        let wardrobe = location("Armario grande", .wardrobe, in: bedroom)
        let shelf = location("Balda 2", .shelf, in: wardrobe)
        let garment = Garment(name: "Chaqueta vaquera", category: .jacket)
        context.insert(garment)
        garment.location = shelf
        try context.save()

        #expect(shelf.path == "Dormitorio › Armario grande › Balda 2")
        #expect(shelf.shortPath == "Armario grande · Balda 2")
        #expect(shelf.parentPath == "Dormitorio › Armario grande")
        #expect(bedroom.totalGarmentCount == 1)
        #expect(wardrobe.allGarments.count == 1)
        #expect(shelf.isDescendant(of: bedroom))
        #expect(!bedroom.isDescendant(of: shelf))
        #expect(shelf.schematicFurniture === wardrobe)
    }

    @Test func deletingLocationKeepsGarments() throws {
        let room = location("Trastero", .room)
        let box = location("Caja «Nieve»", .box, in: room)
        let garment = Garment(name: "Botas", category: .shoes)
        context.insert(garment)
        garment.location = box
        try context.save()

        context.delete(room)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 0)
        #expect(try context.fetch(FetchDescriptor<Garment>()).first?.location == nil)
    }

    @Test func templateSummary() {
        #expect(LocationKind.wardrobe.templateSummary == "Barra · 4 baldas · 2 cajones")
        #expect(LocationKind.dresser.templateSummary == "3 cajones")
        #expect(LocationKind.box.templateSummary == nil)
    }

    @Test func generatedNamesAgreeInGender() {
        #expect(Garment.generatedName(category: .tShirt, colors: [.white]) == "Camiseta blanca")
        #expect(Garment.generatedName(category: .sweater, colors: [.white]) == "Jersey blanco")
        #expect(Garment.generatedName(category: .coat, colors: [.navy]) == "Abrigo azul marino")
        #expect(Garment.generatedName(category: .skirt, colors: []) == "Falda")
    }

    @Test func editorSavesMeasurementsWithComma() throws {
        let model = GarmentEditorModel()
        model.category = .jacket
        model.measurements[.chestWidth] = "54,5"
        model.measurements[.length] = "abc"
        let garment = model.save(in: context, editing: nil)
        #expect(garment.chestWidthCm == 54.5)
        #expect(garment.lengthCm == nil)
        #expect(garment.displayName == "Chaqueta")
    }

    @Test func burstKeepsLocationAndOwner() {
        let shelf = location("Cajón 3", .drawer)
        let model = GarmentEditorModel(location: shelf)
        model.season = .autumnWinter
        model.size = "L"
        model.colors = [.green]
        model.prepareNextInBurst()
        #expect(model.location === shelf)
        #expect(model.season == .autumnWinter)
        #expect(model.size.isEmpty)
        #expect(model.colors.isEmpty)
        #expect(model.burstCount == 1)
    }
}
