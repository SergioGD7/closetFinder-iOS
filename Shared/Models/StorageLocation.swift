import Foundation
import SwiftData

/// Un sitio donde se guarda ropa. Forma un árbol: Estancia › Mueble › Compartimento, con la
/// profundidad que haga falta (una caja dentro de un armario dentro del trastero).
@Model
nonisolated final class StorageLocation {
    var uuid: UUID = UUID()
    var name: String = ""
    var kindRaw: String = LocationKind.room.rawValue
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    var parent: StorageLocation?

    @Relationship(deleteRule: .cascade, inverse: \StorageLocation.parent)
    var children: [StorageLocation]? = []

    @Relationship(deleteRule: .nullify, inverse: \Garment.location)
    var garments: [Garment]? = []

    init(name: String, kind: LocationKind, sortIndex: Int = 0) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
    }

    var kind: LocationKind {
        get { LocationKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var sortedChildren: [StorageLocation] {
        (children ?? []).sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    /// Antecesores desde la raíz. Limitado para no colgarse si hubiera un ciclo por datos corruptos.
    var ancestors: [StorageLocation] {
        var result: [StorageLocation] = []
        var current = parent
        while let location = current, result.count < 32 {
            result.insert(location, at: 0)
            current = location.parent
        }
        return result
    }

    var pathComponents: [String] { (ancestors + [self]).map(\.name) }

    /// «Dormitorio › Armario grande › Balda 2»
    var path: String { pathComponents.joined(separator: " › ") }

    /// «Armario grande · Balda 2», para tarjetas donde no cabe la ruta completa.
    var shortPath: String { pathComponents.suffix(2).joined(separator: " · ") }

    /// Ruta de los antecesores, sin el propio nombre.
    var parentPath: String? {
        let names = ancestors.map(\.name)
        return names.isEmpty ? nil : names.joined(separator: " › ")
    }

    var depth: Int { ancestors.count }

    var descendants: [StorageLocation] {
        sortedChildren.flatMap { [$0] + $0.descendants }
    }

    func isDescendant(of other: StorageLocation) -> Bool {
        ancestors.contains { $0 === other }
    }

    var directGarments: [Garment] { garments ?? [] }

    /// Prendas aquí y en todos los compartimentos interiores.
    var allGarments: [Garment] { directGarments + sortedChildren.flatMap(\.allGarments) }

    var totalGarmentCount: Int {
        directGarments.count + (children ?? []).reduce(0) { $0 + $1.totalGarmentCount }
    }

    /// «Barra · 4 baldas · 2 cajones»
    var contentsSummary: String? {
        let kids = children ?? []
        guard !kids.isEmpty else { return nil }
        return LocationKind.summary(of: kids.map(\.kind))
    }

    var compartments: [StorageLocation] { sortedChildren.filter { $0.kind.isCompartment } }

    /// El mueble que hay que dibujar para situar esta ubicación: su padre si es un compartimento,
    /// o ella misma si tiene compartimentos.
    var schematicFurniture: StorageLocation? {
        if kind.isCompartment, let parent, !parent.compartments.isEmpty { return parent }
        if !compartments.isEmpty { return self }
        return nil
    }

    var nextChildSortIndex: Int { ((children ?? []).map(\.sortIndex).max() ?? -1) + 1 }
}
