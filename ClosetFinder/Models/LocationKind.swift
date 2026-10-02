import SwiftUI

/// Qué es una ubicación: una estancia, un mueble o un compartimento dentro de un mueble.
nonisolated enum LocationKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case room, wardrobe, dresser, shoeRack, shelving, box, suitcase, rail, shelf, drawer, other

    var id: Self { self }

    var title: String {
        switch self {
        case .room: "Estancia"
        case .wardrobe: "Armario"
        case .dresser: "Cómoda"
        case .shoeRack: "Zapatero"
        case .shelving: "Estantería"
        case .box: "Caja"
        case .suitcase: "Maleta"
        case .rail: "Barra"
        case .shelf: "Balda"
        case .drawer: "Cajón"
        case .other: "Otro"
        }
    }

    var plural: String {
        switch self {
        case .room: "estancias"
        case .wardrobe: "armarios"
        case .dresser: "cómodas"
        case .shoeRack: "zapateros"
        case .shelving: "estanterías"
        case .box: "cajas"
        case .suitcase: "maletas"
        case .rail: "barras"
        case .shelf: "baldas"
        case .drawer: "cajones"
        case .other: "otros"
        }
    }

    var symbol: String {
        switch self {
        case .room: "door.left.hand.closed"
        case .wardrobe: "cabinet"
        case .dresser: "archivebox"
        case .shoeRack: "shoe.2"
        case .shelving: "books.vertical"
        case .box: "shippingbox"
        case .suitcase: "suitcase"
        case .rail: "hanger"
        case .shelf: "rectangle.split.1x2"
        case .drawer: "tray"
        case .other: "square.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .room: Color(red: 0.36, green: 0.40, blue: 0.48)
        case .wardrobe: Color(red: 0.31, green: 0.36, blue: 0.84)
        case .dresser: Color(red: 0.88, green: 0.53, blue: 0.23)
        case .shoeRack: Color(red: 0.18, green: 0.65, blue: 0.60)
        case .shelving: Color(red: 0.55, green: 0.42, blue: 0.75)
        case .box: Color(red: 0.60, green: 0.45, blue: 0.32)
        case .suitcase: Color(red: 0.42, green: 0.43, blue: 0.48)
        case .rail: Color(red: 0.31, green: 0.36, blue: 0.84)
        case .shelf: Color(red: 0.25, green: 0.55, blue: 0.85)
        case .drawer: Color(red: 0.88, green: 0.53, blue: 0.23)
        case .other: Color(red: 0.55, green: 0.56, blue: 0.60)
        }
    }

    /// Compartimentos: piezas internas de un mueble que se dibujan en el esquema.
    var isCompartment: Bool { self == .rail || self == .shelf || self == .drawer }

    /// Compartimentos típicos que se crean al añadir este mueble.
    var template: [(kind: LocationKind, name: String)] {
        switch self {
        case .wardrobe:
            [(.rail, "Barra")] + (1...4).map { (.shelf, "Balda \($0)") } + (1...2).map { (.drawer, "Cajón \($0)") }
        case .dresser:
            (1...3).map { (.drawer, "Cajón \($0)") }
        case .shoeRack:
            (1...3).map { (.shelf, "Balda \($0)") }
        case .shelving:
            (1...4).map { (.shelf, "Balda \($0)") }
        default:
            []
        }
    }

    var templateSummary: String? {
        let template = template
        guard !template.isEmpty else { return nil }
        return LocationKind.summary(of: template.map(\.kind))
    }

    /// «Barra · 4 baldas · 2 cajones»
    static func summary(of kinds: [LocationKind]) -> String {
        var counts: [LocationKind: Int] = [:]
        for kind in kinds { counts[kind, default: 0] += 1 }
        return LocationKind.allCases.compactMap { kind in
            guard let count = counts[kind] else { return nil }
            return count == 1 ? kind.title : "\(count) \(kind.plural)"
        }
        .joined(separator: " · ")
    }

    /// Tipos sugeridos al crear una ubicación dentro de otra.
    static func suggestedKinds(inside parent: StorageLocation?) -> [LocationKind] {
        guard let parent else { return [.room] }
        switch parent.kind {
        case .room: return [.wardrobe, .dresser, .shoeRack, .shelving, .box, .suitcase, .other]
        case .wardrobe, .shelving, .shoeRack, .dresser: return [.shelf, .drawer, .rail, .box, .other]
        default: return [.box, .drawer, .shelf, .other]
        }
    }
}
