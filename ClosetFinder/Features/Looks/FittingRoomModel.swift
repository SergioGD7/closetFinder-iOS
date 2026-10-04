import Foundation
import SwiftData

/// Qué filas muestra el probador.
enum FittingLayout: String, CaseIterable, Identifiable {
    case basic, layered, dress, complete

    var id: Self { self }

    var slots: [OutfitSlot] {
        switch self {
        case .basic: [.top, .bottom, .feet]
        case .layered: [.outer, .top, .bottom, .feet]
        case .dress: [.outer, .fullBody, .feet]
        case .complete: [.outer, .top, .bottom, .feet, .accessories]
        }
    }

    var title: String {
        switch self {
        case .basic: String(localized: "Arriba, abajo y calzado")
        case .layered: String(localized: "Con abrigo")
        case .dress: String(localized: "Vestido")
        case .complete: String(localized: "Completo, con accesorios")
        }
    }

    /// El diseño que mejor encaja con un look ya guardado.
    static func best(for garments: [Garment]) -> FittingLayout {
        let slots = Set(garments.map { OutfitSlot.slot(for: $0.category) })
        if slots.contains(.fullBody) { return .dress }
        if slots.contains(.accessories) { return .complete }
        if slots.contains(.outer) { return .layered }
        return .basic
    }
}

/// Estado del probador: qué prenda está elegida en cada fila y qué filas están fijadas.
@Observable
final class FittingRoomModel {
    /// Identificador de la opción «ninguna» en las filas opcionales (abrigo y accesorios).
    static let noneID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var layout: FittingLayout
    /// Prenda elegida en cada parte del cuerpo (`noneID` si se deja vacía).
    var selection: [OutfitSlot: UUID] = [:]
    var pinned: Set<OutfitSlot> = []
    private(set) var options: [OutfitSlot: [Garment]] = [:]

    init(garments: [Garment], outfit: Outfit? = nil, preselected: [Garment] = []) {
        let chosen = outfit?.pieces ?? preselected
        layout = FittingLayout.best(for: chosen)
        // Lo prestado, lavándose o para donar no se ofrece: no te lo puedes poner.
        let available = garments.filter { $0.status == .stored || $0.status == .inUse || chosen.contains($0) }
        for slot in OutfitSlot.allCases {
            options[slot] = available
                .filter { OutfitSlot.slot(for: $0.category) == slot }
                .sorted { ($0.isFavorite ? 0 : 1, $0.displayName) < ($1.isFavorite ? 0 : 1, $1.displayName) }
        }
        for slot in OutfitSlot.allCases {
            if let garment = chosen.first(where: { OutfitSlot.slot(for: $0.category) == slot }) {
                selection[slot] = garment.uuid
            } else if Self.isOptional(slot) {
                selection[slot] = Self.noneID
            } else {
                selection[slot] = options[slot]?.first?.uuid
            }
        }
        // Lo que viene de un look o de una prenda concreta queda fijado.
        pinned = Set(chosen.map { OutfitSlot.slot(for: $0.category) })
    }

    static func isOptional(_ slot: OutfitSlot) -> Bool { slot == .outer || slot == .accessories }

    /// Opciones de una fila, en orden: «ninguna» primero si la fila es opcional.
    func items(for slot: OutfitSlot) -> [UUID] {
        let garments = (options[slot] ?? []).map(\.uuid)
        return Self.isOptional(slot) ? [Self.noneID] + garments : garments
    }

    func garment(_ id: UUID?, in slot: OutfitSlot) -> Garment? {
        guard let id, id != Self.noneID else { return nil }
        return options[slot]?.first { $0.uuid == id }
    }

    func selectedGarment(in slot: OutfitSlot) -> Garment? { garment(selection[slot], in: slot) }

    /// Prendas del look tal y como está ahora en el probador.
    var selectedGarments: [Garment] {
        layout.slots.compactMap(selectedGarment(in:))
    }

    var canSave: Bool { !selectedGarments.isEmpty }

    func togglePin(_ slot: OutfitSlot) {
        if pinned.contains(slot) { pinned.remove(slot) } else { pinned.insert(slot) }
    }

    /// Elige al azar en las filas sin fijar. Nunca repite la prenda que ya estaba, si hay otra.
    func shuffle<G: RandomNumberGenerator>(using generator: inout G) {
        for slot in layout.slots where !pinned.contains(slot) {
            let candidates = items(for: slot).filter { $0 != selection[slot] }
            if let pick = candidates.randomElement(using: &generator) {
                selection[slot] = pick
            }
        }
    }

    func shuffle() {
        var generator = SystemRandomNumberGenerator()
        shuffle(using: &generator)
    }

    /// Nombre propuesto al guardar: «Look con Chaqueta vaquera».
    var suggestedName: String {
        guard let first = selectedGarments.first else { return "" }
        return String(localized: "Look con \(first.displayName)")
    }
}
