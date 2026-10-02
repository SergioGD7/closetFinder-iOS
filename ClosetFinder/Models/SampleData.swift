import Foundation
import SwiftData

/// Armario de ejemplo para probar la app sin tener que dar de alta nada.
enum SampleData {

    static func insertIfEmpty(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Garment>())) ?? 0
        let locations = (try? context.fetchCount(FetchDescriptor<StorageLocation>())) ?? 0
        guard count == 0, locations == 0 else { return }
        insert(into: context)
    }

    static func insert(into context: ModelContext) {
        // Ubicaciones
        let bedroom = makeLocation("Dormitorio", .room, index: 0, parent: nil, in: context)
        let wardrobe = makeLocation("Armario grande", .wardrobe, index: 0, parent: bedroom, in: context)
        let compartments = Dictionary(uniqueKeysWithValues: LocationKind.wardrobe.template.enumerated().map { index, item in
            (item.name, makeLocation(item.name, item.kind, index: index, parent: wardrobe, in: context))
        })
        let dresser = makeLocation("Cómoda", .dresser, index: 1, parent: bedroom, in: context)
        let drawers = (1...3).map { makeLocation("Cajón \($0)", .drawer, index: $0 - 1, parent: dresser, in: context) }

        let hall = makeLocation("Entrada", .room, index: 1, parent: nil, in: context)
        let shoeRack = makeLocation("Zapatero", .shoeRack, index: 0, parent: hall, in: context)
        let shoeShelves = (1...3).map { makeLocation("Balda \($0)", .shelf, index: $0 - 1, parent: shoeRack, in: context) }

        let storage = makeLocation("Trastero", .room, index: 2, parent: nil, in: context)
        let winterBox = makeLocation("Caja «Invierno»", .box, index: 0, parent: storage, in: context)
        let snowBox = makeLocation("Caja «Nieve»", .box, index: 1, parent: storage, in: context)
        let suitcase = makeLocation("Maleta grande", .suitcase, index: 2, parent: storage, in: context)

        // Persona
        let me = BodyProfile(name: "Yo", sizing: .menswear)
        context.insert(me)
        me.heightCm = 178
        me.chestCm = 98
        me.waistCm = 84
        me.hipCm = 100
        me.inseamCm = 82
        me.footCm = 27

        // Prendas
        let items: [SampleGarment] = [
            .init("Chaqueta vaquera", .jacket, "M", [.blue], compartments["Balda 2"], brand: "Levi's", material: "Algodón",
                  season: .midSeason, chest: 54, length: 66, sleeve: 63, wears: 12, daysAgo: 9, favorite: true),
            .init("Camiseta básica blanca", .tShirt, "L", [.white], drawers[0], material: "Algodón", chest: 55, length: 72, wears: 30, daysAgo: 2),
            .init("Sudadera verde", .sweater, "L", [.green], drawers[2], season: .autumnWinter, chest: 58, length: 70, sleeve: 64, wears: 8, daysAgo: 20),
            .init("Zapatillas running", .shoes, "43", [.black], shoeShelves[0], brand: "Asics", wears: 40, daysAgo: 1, favorite: true),
            .init("Abrigo camel", .coat, "M", [.brown], compartments["Barra"], material: "Lana", season: .autumnWinter, chest: 57, length: 95, sleeve: 65, wears: 5, daysAgo: 160),
            .init("Chino gris marengo", .trousers, "42", [.gray], compartments["Balda 3"], waist: 43, length: 104, inseam: 81, wears: 14, daysAgo: 6),
            .init("Plumífero azul marino", .coat, "L", [.navy], snowBox, season: .autumnWinter, chest: 62, length: 78, wears: 2, daysAgo: 250),
            .init("Americana azul", .blazer, "50", [.blue], compartments["Barra"], material: "Lana fría", chest: 54, length: 75, sleeve: 64, wears: 3, daysAgo: 95),
            .init("Camisa de lino", .shirt, "M", [.lightBlue], compartments["Barra"], material: "Lino", season: .springSummer, chest: 56, length: 76, sleeve: 64, wears: 6, daysAgo: 40),
            .init("Bañador estampado", .swimwear, "M", [.multicolor], suitcase, season: .springSummer, wears: 4, daysAgo: 70),
            .init("Jersey de punto burdeos", .sweater, "M", [.burgundy], winterBox, material: "Lana merino", season: .autumnWinter, chest: 50, length: 66, sleeve: 62, wears: 9, daysAgo: 180),
            .init("Vaqueros rectos", .trousers, "42", [.navy], compartments["Balda 3"], brand: "Levi's", waist: 42.5, length: 106, inseam: 82, wears: 22, daysAgo: 3),
            .init("Botas de montaña", .shoes, "43", [.brown], snowBox, season: .autumnWinter, wears: 3, daysAgo: 240),
            .init("Pantalón corto beige", .shorts, "M", [.beige], suitcase, season: .springSummer, waist: 44, length: 48, wears: 7, daysAgo: 60),
            .init("Polo rojo", .tShirt, "M", [.red], compartments["Cajón 1"], status: .lent, chest: 52, length: 70, wears: 5, daysAgo: 30),
        ]

        for item in items {
            let garment = Garment(name: item.name, category: item.category, size: item.size, colors: item.colors)
            context.insert(garment)
            garment.location = item.location
            garment.owner = me
            garment.brand = item.brand
            garment.material = item.material
            garment.season = item.season
            garment.status = item.status
            garment.chestWidthCm = item.chest
            garment.waistWidthCm = item.waist
            garment.lengthCm = item.length
            garment.sleeveCm = item.sleeve
            garment.inseamCm = item.inseam
            garment.wearCount = item.wears
            garment.lastWornAt = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: .now)
            garment.isFavorite = item.favorite
        }
        try? context.save()
    }

    private static func makeLocation(_ name: String, _ kind: LocationKind, index: Int,
                                     parent: StorageLocation?, in context: ModelContext) -> StorageLocation {
        let location = StorageLocation(name: name, kind: kind, sortIndex: index)
        context.insert(location)
        location.parent = parent
        return location
    }

    private struct SampleGarment {
        let name: String
        let category: GarmentCategory
        let size: String
        let colors: [GarmentColor]
        let location: StorageLocation?
        var brand = ""
        var material = ""
        var season = Season.allYear
        var status = GarmentStatus.stored
        var chest: Double?
        var waist: Double?
        var length: Double?
        var sleeve: Double?
        var inseam: Double?
        var wears = 0
        var daysAgo = 0
        var favorite = false

        init(_ name: String, _ category: GarmentCategory, _ size: String, _ colors: [GarmentColor], _ location: StorageLocation?,
             brand: String = "", material: String = "", season: Season = .allYear, status: GarmentStatus = .stored,
             chest: Double? = nil, waist: Double? = nil, length: Double? = nil, sleeve: Double? = nil, inseam: Double? = nil,
             wears: Int = 0, daysAgo: Int = 0, favorite: Bool = false) {
            self.name = name
            self.category = category
            self.size = size
            self.colors = colors
            self.location = location
            self.brand = brand
            self.material = material
            self.season = season
            self.status = status
            self.chest = chest
            self.waist = waist
            self.length = length
            self.sleeve = sleeve
            self.inseam = inseam
            self.wears = wears
            self.daysAgo = daysAgo
            self.favorite = favorite
        }
    }
}
