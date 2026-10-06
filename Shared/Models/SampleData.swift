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
        let bedroom = makeLocation(String(localized: "Dormitorio"), .room, index: 0, parent: nil, in: context)
        let wardrobe = makeLocation(String(localized: "Armario grande"), .wardrobe, index: 0, parent: bedroom, in: context)
        let compartments = Dictionary(uniqueKeysWithValues: LocationKind.wardrobe.template.enumerated().map { index, item in
            (item.name, makeLocation(item.name, item.kind, index: index, parent: wardrobe, in: context))
        })
        let dresser = makeLocation(String(localized: "Cómoda"), .dresser, index: 1, parent: bedroom, in: context)
        let drawers = (1...3).map { makeLocation(String(localized: "Cajón \($0)"), .drawer, index: $0 - 1, parent: dresser, in: context) }

        let hall = makeLocation(String(localized: "Entrada"), .room, index: 1, parent: nil, in: context)
        let shoeRack = makeLocation(String(localized: "Zapatero"), .shoeRack, index: 0, parent: hall, in: context)
        let shoeShelves = (1...3).map { makeLocation(String(localized: "Balda \($0)"), .shelf, index: $0 - 1, parent: shoeRack, in: context) }

        let storage = makeLocation(String(localized: "Trastero"), .room, index: 2, parent: nil, in: context)
        let winterBox = makeLocation(String(localized: "Caja «Invierno»"), .box, index: 0, parent: storage, in: context)
        let snowBox = makeLocation(String(localized: "Caja «Nieve»"), .box, index: 1, parent: storage, in: context)
        let suitcase = makeLocation(String(localized: "Maleta grande"), .suitcase, index: 2, parent: storage, in: context)

        // Persona
        let me = BodyProfile(name: String(localized: "Yo"), sizing: .menswear)
        context.insert(me)
        me.heightCm = 178
        me.chestCm = 98
        me.waistCm = 84
        me.hipCm = 100
        me.inseamCm = 82
        me.footCm = 27

        // Prendas
        let items: [SampleGarment] = [
            .init(String(localized: "Chaqueta vaquera"), .jacket, "M", [.blue], compartments[String(localized: "Balda \(2)")], brand: "Levi's", material: String(localized: "Algodón"),
                  season: .midSeason, chest: 54, length: 66, sleeve: 63, wears: 12, daysAgo: 9, favorite: true, price: 89, bought: 700, care: [.wash30, .noBleach, .noTumbleDry]),
            .init(String(localized: "Camiseta básica blanca"), .tShirt, "L", [.white], drawers[0], material: String(localized: "Algodón"), chest: 55, length: 72, wears: 30, daysAgo: 2, price: 15, bought: 400, care: [.wash40, .ironMedium]),
            .init(String(localized: "Sudadera verde"), .sweater, "L", [.green], drawers[2], season: .autumnWinter, chest: 58, length: 70, sleeve: 64, wears: 8, daysAgo: 20, price: 39, bought: 300),
            .init(String(localized: "Zapatillas running"), .shoes, "43", [.black], shoeShelves[0], brand: "Asics", wears: 40, daysAgo: 1, favorite: true, price: 120, bought: 500),
            .init(String(localized: "Abrigo camel"), .coat, "M", [.brown], compartments[String(localized: "Barra")], material: String(localized: "Lana"), season: .autumnWinter, chest: 57, length: 95, sleeve: 65, wears: 5, daysAgo: 160, price: 220, bought: 800, care: [.noWash, .dryClean]),
            .init(String(localized: "Chino gris marengo"), .trousers, "42", [.gray], compartments[String(localized: "Balda \(3)")], waist: 43, length: 104, inseam: 81, wears: 14, daysAgo: 6, price: 49, bought: 260),
            .init(String(localized: "Plumífero azul marino"), .coat, "L", [.navy], snowBox, season: .autumnWinter, chest: 62, length: 78, wears: 2, daysAgo: 250, price: 159, bought: 1000),
            .init(String(localized: "Americana azul"), .blazer, "50", [.blue], compartments[String(localized: "Barra")], material: String(localized: "Lana fría"), chest: 54, length: 75, sleeve: 64, wears: 3, daysAgo: 95, price: 180, bought: 600, care: [.noWash, .ironLow, .dryClean]),
            .init(String(localized: "Camisa de lino"), .shirt, "M", [.lightBlue], compartments[String(localized: "Barra")], material: String(localized: "Lino"), season: .springSummer, chest: 56, length: 76, sleeve: 64, wears: 6, daysAgo: 40, price: 45, bought: 120, care: [.wash30, .ironHigh]),
            .init(String(localized: "Bañador estampado"), .swimwear, "M", [.multicolor], suitcase, season: .springSummer, wears: 4, daysAgo: 70),
            .init(String(localized: "Jersey de punto burdeos"), .sweater, "M", [.burgundy], winterBox, material: String(localized: "Lana merino"), season: .autumnWinter, chest: 50, length: 66, sleeve: 62, wears: 9, daysAgo: 180),
            .init(String(localized: "Vaqueros rectos"), .trousers, "42", [.navy], compartments[String(localized: "Balda \(3)")], brand: "Levi's", waist: 42.5, length: 106, inseam: 82, wears: 22, daysAgo: 3, price: 49, bought: 900, care: [.wash30, .noTumbleDry]),
            .init(String(localized: "Botas de montaña"), .shoes, "43", [.brown], snowBox, season: .autumnWinter, wears: 3, daysAgo: 240, price: 110, bought: 1100),
            .init(String(localized: "Pantalón corto beige"), .shorts, "M", [.beige], suitcase, season: .springSummer, waist: 44, length: 48, wears: 7, daysAgo: 60),
            .init(String(localized: "Polo rojo"), .tShirt, "M", [.red], compartments[String(localized: "Cajón \(1)")], status: .lent, chest: 52, length: 70, wears: 5, daysAgo: 30),
        ]

        var byName: [String: Garment] = [:]
        for item in items {
            let garment = Garment(name: item.name, category: item.category, size: item.size, colors: item.colors)
            byName[item.name] = garment
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
            garment.wearDates = wearDates(count: item.wears, lastDaysAgo: item.daysAgo)
            garment.isFavorite = item.favorite
            garment.price = item.price
            garment.purchasedAt = item.boughtDaysAgo.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
            garment.care = item.care
        }

        // Looks
        func pieces(_ names: [String.LocalizationValue]) -> [Garment] {
            names.compactMap { byName[String(localized: $0)] }
        }
        func makeOutfit(_ name: String, _ garments: [Garment], favorite: Bool = false, worn: Int = 0) -> Outfit {
            let outfit = Outfit(name: name)
            context.insert(outfit)
            outfit.garments = garments
            outfit.isFavorite = favorite
            outfit.wearCount = worn
            outfit.wearDates = wearDates(count: worn, lastDaysAgo: 3)
            return outfit
        }
        let office = makeOutfit(String(localized: "Oficina"),
                                pieces(["Camisa de lino", "Chino gris marengo", "Americana azul", "Zapatillas running"]), worn: 6)
        let weekend = makeOutfit(String(localized: "Fin de semana"),
                                 pieces(["Camiseta básica blanca", "Vaqueros rectos", "Chaqueta vaquera", "Zapatillas running"]),
                                 favorite: true, worn: 9)
        let snow = makeOutfit(String(localized: "Día de nieve"),
                              pieces(["Jersey de punto burdeos", "Plumífero azul marino", "Vaqueros rectos", "Botas de montaña"]), worn: 2)
        let summer = makeOutfit(String(localized: "Verano"),
                                pieces(["Camisa de lino", "Pantalón corto beige", "Zapatillas running"]), worn: 3)

        // Semana: looks planificados para algunos días de esta semana.
        let week = WeekPlanner.days(around: .now)
        for (index, outfit) in [(0, office), (1, summer), (2, office), (4, weekend), (5, snow)] where index < week.count {
            let plan = OutfitPlan(day: Calendar.current.startOfDay(for: week[index]))
            context.insert(plan)
            plan.outfit = outfit
        }

        // Maleta
        let start = Calendar.current.startOfDay(for: .now.addingTimeInterval(9 * 86_400))
        let trip = Trip(name: String(localized: "Escapada a la sierra"), startDate: start, endDate: start.addingTimeInterval(2 * 86_400))
        context.insert(trip)
        trip.outfits = [snow, weekend]
        trip.extraGarments = pieces(["Sudadera verde"])
        trip.notes = String(localized: "No olvidar guantes y gorro.")
        trip.destination = "Navacerrada"
        trip.latitude = 40.7838
        trip.longitude = -4.0107
        if let boots = byName[String(localized: "Botas de montaña")] { trip.togglePacked(boots) }

        try? context.save()
    }

    /// Fechas repartidas hacia atrás: la última hace `lastDaysAgo` días y el resto cada dos semanas.
    private static func wearDates(count: Int, lastDaysAgo: Int) -> [Date] {
        (0..<count).compactMap { Calendar.current.date(byAdding: .day, value: -(lastDaysAgo + $0 * 14), to: .now) }
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
        var price: Double?
        var boughtDaysAgo: Int?
        var care: [CareInstruction] = []

        init(_ name: String, _ category: GarmentCategory, _ size: String, _ colors: [GarmentColor], _ location: StorageLocation?,
             brand: String = "", material: String = "", season: Season = .allYear, status: GarmentStatus = .stored,
             chest: Double? = nil, waist: Double? = nil, length: Double? = nil, sleeve: Double? = nil, inseam: Double? = nil,
             wears: Int = 0, daysAgo: Int = 0, favorite: Bool = false,
             price: Double? = nil, bought: Int? = nil, care: [CareInstruction] = []) {
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
            self.price = price
            self.boughtDaysAgo = bought
            self.care = care
        }
    }
}
