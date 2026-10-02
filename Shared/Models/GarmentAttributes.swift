import Foundation

/// Tipo de prenda. Se guarda como `String` en SwiftData para poder filtrar y sincronizar sin problemas.
nonisolated enum GarmentCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case tShirt, shirt, sweater, jacket, coat, blazer, trousers, shorts, skirt, dress, shoes, underwear, swimwear, accessories

    var id: Self { self }

    /// Nombre en plural, para listas y filtros.
    var title: String {
        switch self {
        case .tShirt: String(localized: "Camisetas")
        case .shirt: String(localized: "Camisas")
        case .sweater: String(localized: "Jerséis y sudaderas")
        case .jacket: String(localized: "Chaquetas")
        case .coat: String(localized: "Abrigos")
        case .blazer: String(localized: "Americanas")
        case .trousers: String(localized: "Pantalones")
        case .shorts: String(localized: "Pantalones cortos")
        case .skirt: String(localized: "Faldas")
        case .dress: String(localized: "Vestidos")
        case .shoes: String(localized: "Calzado")
        case .underwear: String(localized: "Ropa interior")
        case .swimwear: String(localized: "Baño")
        case .accessories: String(localized: "Accesorios")
        }
    }

    /// Nombre en singular, para generar nombres como «Camiseta blanca».
    var singular: String {
        switch self {
        case .tShirt: String(localized: "category.singular.tShirt", defaultValue: "Camiseta")
        case .shirt: String(localized: "category.singular.shirt", defaultValue: "Camisa")
        case .sweater: String(localized: "category.singular.sweater", defaultValue: "Jersey")
        case .jacket: String(localized: "category.singular.jacket", defaultValue: "Chaqueta")
        case .coat: String(localized: "category.singular.coat", defaultValue: "Abrigo")
        case .blazer: String(localized: "category.singular.blazer", defaultValue: "Americana")
        case .trousers: String(localized: "category.singular.trousers", defaultValue: "Pantalón")
        case .shorts: String(localized: "category.singular.shorts", defaultValue: "Pantalón corto")
        case .skirt: String(localized: "category.singular.skirt", defaultValue: "Falda")
        case .dress: String(localized: "category.singular.dress", defaultValue: "Vestido")
        case .shoes: String(localized: "category.singular.shoes", defaultValue: "Calzado")
        case .underwear: String(localized: "category.singular.underwear", defaultValue: "Ropa interior")
        case .swimwear: String(localized: "category.singular.swimwear", defaultValue: "Bañador")
        case .accessories: String(localized: "category.singular.accessories", defaultValue: "Accesorio")
        }
    }

    /// Género gramatical del singular en el idioma de la app («f» o «m»), para que el color
    /// concuerde: «Camiseta blanca», «Jersey blanco».
    var isFeminine: Bool {
        let gender: String = switch self {
        case .tShirt: String(localized: "category.gender.tShirt", defaultValue: "f")
        case .shirt: String(localized: "category.gender.shirt", defaultValue: "f")
        case .sweater: String(localized: "category.gender.sweater", defaultValue: "m")
        case .jacket: String(localized: "category.gender.jacket", defaultValue: "f")
        case .coat: String(localized: "category.gender.coat", defaultValue: "m")
        case .blazer: String(localized: "category.gender.blazer", defaultValue: "f")
        case .trousers: String(localized: "category.gender.trousers", defaultValue: "m")
        case .shorts: String(localized: "category.gender.shorts", defaultValue: "m")
        case .skirt: String(localized: "category.gender.skirt", defaultValue: "f")
        case .dress: String(localized: "category.gender.dress", defaultValue: "m")
        case .shoes: String(localized: "category.gender.shoes", defaultValue: "m")
        case .underwear: String(localized: "category.gender.underwear", defaultValue: "f")
        case .swimwear: String(localized: "category.gender.swimwear", defaultValue: "m")
        case .accessories: String(localized: "category.gender.accessories", defaultValue: "m")
        }
        return gender == "f"
    }

    /// Zona del cuerpo que determina qué medida corporal se compara con la prenda.
    var bodyZone: BodyZone {
        switch self {
        case .tShirt, .shirt, .sweater, .jacket, .coat, .blazer, .dress: .upper
        case .trousers, .shorts, .skirt, .swimwear, .underwear: .lower
        case .shoes: .feet
        case .accessories: .none
        }
    }

    /// Prendas de abrigo: necesitan más holgura para que «queden bien».
    var isOuterwear: Bool { self == .jacket || self == .coat || self == .blazer }

    var relevantMeasurements: [GarmentMeasurement] {
        switch self {
        case .tShirt: [.chestWidth, .length]
        case .shirt, .sweater, .jacket, .coat, .blazer: [.chestWidth, .length, .sleeve]
        case .dress: [.chestWidth, .waistWidth, .length]
        case .trousers: [.waistWidth, .inseam, .length]
        case .shorts, .skirt, .swimwear: [.waistWidth, .length]
        case .shoes, .underwear, .accessories: []
        }
    }

    var sizeSuggestions: [String] {
        switch bodyZone {
        case .upper: ["XS", "S", "M", "L", "XL", "XXL"]
        case .lower where self == .trousers: ["38", "40", "42", "44", "46", "48"]
        case .lower: ["XS", "S", "M", "L", "XL"]
        case .feet: ["39", "40", "41", "42", "43", "44", "45"]
        case .none: [String(localized: "Única")]
        }
    }
}

nonisolated enum BodyZone: Sendable {
    case upper, lower, feet, none
}

/// Medidas que se toman a la prenda extendida en plano.
nonisolated enum GarmentMeasurement: String, CaseIterable, Identifiable, Sendable {
    case chestWidth, waistWidth, length, sleeve, inseam

    var id: Self { self }

    var title: String {
        switch self {
        case .chestWidth: String(localized: "Pecho (axila a axila)")
        case .waistWidth: String(localized: "Cintura (en plano)")
        case .length: String(localized: "Largo")
        case .sleeve: String(localized: "Manga")
        case .inseam: String(localized: "Entrepierna")
        }
    }

    var shortTitle: String {
        switch self {
        case .chestWidth: String(localized: "Pecho")
        case .waistWidth: String(localized: "Cintura")
        case .length: String(localized: "Largo")
        case .sleeve: String(localized: "Manga")
        case .inseam: String(localized: "Entrepierna")
        }
    }
}

nonisolated enum Season: String, CaseIterable, Codable, Identifiable, Sendable {
    case allYear, springSummer, autumnWinter, midSeason

    var id: Self { self }

    var title: String {
        switch self {
        case .allYear: String(localized: "Todo el año")
        case .springSummer: String(localized: "Primavera · Verano")
        case .autumnWinter: String(localized: "Otoño · Invierno")
        case .midSeason: String(localized: "Entretiempo")
        }
    }

    var symbol: String {
        switch self {
        case .allYear: "calendar"
        case .springSummer: "sun.max"
        case .autumnWinter: "snowflake"
        case .midSeason: "leaf"
        }
    }
}

nonisolated enum GarmentStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case stored, inUse, laundry, lent, toDonate

    var id: Self { self }

    var title: String {
        switch self {
        case .stored: String(localized: "Guardada")
        case .inUse: String(localized: "En uso")
        case .laundry: String(localized: "Lavando")
        case .lent: String(localized: "Prestada")
        case .toDonate: String(localized: "Para donar")
        }
    }

    var symbol: String {
        switch self {
        case .stored: "checkmark.circle"
        case .inUse: "figure.walk"
        case .laundry: "washer"
        case .lent: "hand.raised"
        case .toDonate: "gift"
        }
    }
}

/// Tablas de tallas a usar para una persona.
nonisolated enum SizingProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case menswear, womenswear

    var id: Self { self }

    var title: String {
        switch self {
        case .menswear: String(localized: "Tallaje de hombre")
        case .womenswear: String(localized: "Tallaje de mujer")
        }
    }
}
