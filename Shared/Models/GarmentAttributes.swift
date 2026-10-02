import Foundation

/// Tipo de prenda. Se guarda como `String` en SwiftData para poder filtrar y sincronizar sin problemas.
nonisolated enum GarmentCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case tShirt, shirt, sweater, jacket, coat, blazer, trousers, shorts, skirt, dress, shoes, underwear, swimwear, accessories

    var id: Self { self }

    /// Nombre en plural, para listas y filtros.
    var title: String {
        switch self {
        case .tShirt: "Camisetas"
        case .shirt: "Camisas"
        case .sweater: "Jerséis y sudaderas"
        case .jacket: "Chaquetas"
        case .coat: "Abrigos"
        case .blazer: "Americanas"
        case .trousers: "Pantalones"
        case .shorts: "Pantalones cortos"
        case .skirt: "Faldas"
        case .dress: "Vestidos"
        case .shoes: "Calzado"
        case .underwear: "Ropa interior"
        case .swimwear: "Baño"
        case .accessories: "Accesorios"
        }
    }

    /// Nombre en singular, para generar nombres como «Camiseta blanca».
    var singular: String {
        switch self {
        case .tShirt: "Camiseta"
        case .shirt: "Camisa"
        case .sweater: "Jersey"
        case .jacket: "Chaqueta"
        case .coat: "Abrigo"
        case .blazer: "Americana"
        case .trousers: "Pantalón"
        case .shorts: "Pantalón corto"
        case .skirt: "Falda"
        case .dress: "Vestido"
        case .shoes: "Calzado"
        case .underwear: "Ropa interior"
        case .swimwear: "Bañador"
        case .accessories: "Accesorio"
        }
    }

    var isFeminine: Bool {
        switch self {
        case .tShirt, .shirt, .jacket, .blazer, .skirt, .underwear: true
        default: false
        }
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
        case .none: ["Única"]
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
        case .chestWidth: "Pecho (axila a axila)"
        case .waistWidth: "Cintura (en plano)"
        case .length: "Largo"
        case .sleeve: "Manga"
        case .inseam: "Entrepierna"
        }
    }

    var shortTitle: String {
        switch self {
        case .chestWidth: "Pecho"
        case .waistWidth: "Cintura"
        case .length: "Largo"
        case .sleeve: "Manga"
        case .inseam: "Entrepierna"
        }
    }
}

nonisolated enum Season: String, CaseIterable, Codable, Identifiable, Sendable {
    case allYear, springSummer, autumnWinter, midSeason

    var id: Self { self }

    var title: String {
        switch self {
        case .allYear: "Todo el año"
        case .springSummer: "Primavera · Verano"
        case .autumnWinter: "Otoño · Invierno"
        case .midSeason: "Entretiempo"
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
        case .stored: "Guardada"
        case .inUse: "En uso"
        case .laundry: "Lavando"
        case .lent: "Prestada"
        case .toDonate: "Para donar"
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
        case .menswear: "Tallaje de hombre"
        case .womenswear: "Tallaje de mujer"
        }
    }
}
