import Foundation
import SwiftData

/// Estancias y muebles que se eligen en el primer arranque, antes de crearlos.
struct RoomDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var isIncluded: Bool
    var furniture: [LocationKind]

    /// Muebles que se pueden elegir para cada estancia.
    static let furnitureOptions: [LocationKind] = [.wardrobe, .dresser, .shoeRack, .shelving, .box]

    /// Lo más habitual: dormitorio con armario y cómoda, entrada con zapatero. El resto, sin marcar.
    static var defaults: [RoomDraft] {
        [
            RoomDraft(name: String(localized: "Dormitorio"), isIncluded: true, furniture: [.wardrobe, .dresser]),
            RoomDraft(name: String(localized: "Entrada"), isIncluded: true, furniture: [.shoeRack]),
            RoomDraft(name: String(localized: "Trastero"), isIncluded: false, furniture: [.box]),
            RoomDraft(name: String(localized: "Vestidor"), isIncluded: false, furniture: [.wardrobe, .shelving]),
            RoomDraft(name: String(localized: "Habitación de invitados"), isIncluded: false, furniture: [.wardrobe]),
        ]
    }

    mutating func toggle(_ kind: LocationKind) {
        if let index = furniture.firstIndex(of: kind) {
            furniture.remove(at: index)
        } else {
            furniture = Self.furnitureOptions.filter { furniture.contains($0) || $0 == kind }
        }
    }
}

/// Crea las estancias elegidas, sus muebles y los compartimentos de cada mueble.
enum HomeSetup {
    @discardableResult
    static func create(_ rooms: [RoomDraft], in context: ModelContext) -> [StorageLocation] {
        let existingRoots = (try? context.fetch(FetchDescriptor<StorageLocation>()).filter { $0.parent == nil }.count) ?? 0
        let included = rooms.filter { $0.isIncluded && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let created = included.enumerated().map { index, draft in
            let room = StorageLocation(name: draft.name.trimmingCharacters(in: .whitespaces), kind: .room,
                                       sortIndex: existingRoots + index)
            context.insert(room)
            for (furnitureIndex, kind) in draft.furniture.enumerated() {
                let piece = StorageLocation(name: kind.title, kind: kind, sortIndex: furnitureIndex)
                context.insert(piece)
                piece.parent = room
                for (compartmentIndex, item) in kind.template.enumerated() {
                    let compartment = StorageLocation(name: item.name, kind: item.kind, sortIndex: compartmentIndex)
                    context.insert(compartment)
                    compartment.parent = piece
                }
            }
            return room
        }
        try? context.save()
        return created
    }
}
