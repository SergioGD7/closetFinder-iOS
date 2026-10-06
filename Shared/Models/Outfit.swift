import Foundation
import SwiftData

/// Parte del cuerpo que ocupa cada prenda dentro de un look.
nonisolated enum OutfitSlot: String, CaseIterable, Identifiable, Sendable {
    case outer, top, fullBody, bottom, feet, accessories

    var id: Self { self }

    var title: String {
        switch self {
        case .outer: String(localized: "Abrigo o chaqueta")
        case .top: String(localized: "Parte de arriba")
        case .fullBody: String(localized: "Cuerpo entero")
        case .bottom: String(localized: "Parte de abajo")
        case .feet: String(localized: "Calzado")
        case .accessories: String(localized: "Accesorios")
        }
    }

    /// Categoría cuya ilustración representa esta parte del cuerpo.
    var representativeCategory: GarmentCategory {
        switch self {
        case .outer: .jacket
        case .top: .tShirt
        case .fullBody: .dress
        case .bottom: .trousers
        case .feet: .shoes
        case .accessories: .accessories
        }
    }

    static func slot(for category: GarmentCategory) -> OutfitSlot {
        switch category {
        case .jacket, .coat, .blazer: .outer
        case .tShirt, .shirt, .sweater: .top
        case .dress: .fullBody
        case .trousers, .shorts, .skirt, .swimwear: .bottom
        case .shoes: .feet
        case .underwear, .accessories: .accessories
        }
    }

    var categories: [GarmentCategory] {
        GarmentCategory.allCases.filter { Self.slot(for: $0) == self }
    }
}

/// Un look: una combinación de prendas guardada para ponérsela junta.
@Model
nonisolated final class Outfit {
    var uuid: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    var wearCount: Int = 0
    var lastWornAt: Date?
    var wearDates: [Date] = []
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Garment.outfits)
    var garments: [Garment]? = []

    @Relationship(deleteRule: .cascade, inverse: \OutfitPlan.outfit)
    var plans: [OutfitPlan]? = []

    var trips: [Trip]? = []

    init(name: String = "", garments: [Garment] = []) {
        self.name = name
        self.garments = garments
    }

    /// Prendas ordenadas de arriba abajo, como se ve una persona vestida.
    var pieces: [Garment] { Self.sortedBySlot(garments ?? []) }

    /// Ordena prendas por parte del cuerpo: abrigo, arriba, cuerpo entero, abajo, calzado y accesorios.
    static func sortedBySlot(_ garments: [Garment]) -> [Garment] {
        garments.sorted { lhs, rhs in
            let l = OutfitSlot.allCases.firstIndex(of: OutfitSlot.slot(for: lhs.category)) ?? 0
            let r = OutfitSlot.allCases.firstIndex(of: OutfitSlot.slot(for: rhs.category)) ?? 0
            return l != r ? l < r : lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    func pieces(in slot: OutfitSlot) -> [Garment] {
        pieces.filter { OutfitSlot.slot(for: $0.category) == slot }
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        guard let first = pieces.first else { return String(localized: "Look sin prendas") }
        return String(localized: "Look con \(first.displayName)")
    }

    /// Prendas que ahora mismo no se pueden coger: prestadas, lavándose o para donar.
    var unavailablePieces: [Garment] {
        pieces.filter { $0.status == .lent || $0.status == .laundry || $0.status == .toDonate }
    }

    func markWorn(on date: Date = .now) {
        wearCount += 1
        lastWornAt = max(lastWornAt ?? date, date)
        wearDates.append(date)
        for garment in garments ?? [] { garment.markWorn(on: date) }
    }
}

/// Un look planificado para un día concreto.
@Model
nonisolated final class OutfitPlan {
    var uuid: UUID = UUID()
    /// Inicio del día (medianoche) en el calendario del usuario.
    var day: Date = Date.now
    var createdAt: Date = Date.now
    var outfit: Outfit?

    init(day: Date) {
        self.day = day
    }
}

/// Un viaje con su maleta: looks y prendas sueltas que llevar, y qué está ya metido.
@Model
nonisolated final class Trip {
    var uuid: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var notes: String = ""
    /// Ciudad o lugar del viaje y sus coordenadas, para saber la época en el destino (hemisferio).
    var destination: String = ""
    var latitude: Double?
    var longitude: Double?
    /// Prendas ya metidas en la maleta (UUID de cada prenda).
    var packedGarmentIDs: [String] = []
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Outfit.trips)
    var outfits: [Outfit]? = []

    @Relationship(deleteRule: .nullify, inverse: \Garment.trips)
    var extraGarments: [Garment]? = []

    init(name: String, startDate: Date, endDate: Date) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Número de días del viaje, contando el de salida y el de vuelta.
    var dayCount: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                           to: calendar.startOfDay(for: endDate)).day ?? 0
        return max(days, 0) + 1
    }

    var sortedOutfits: [Outfit] {
        (outfits ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Todo lo que hay que llevar, sin repetir: las prendas de los looks y las sueltas.
    var packingList: [Garment] {
        var seen = Set<UUID>()
        var result: [Garment] = []
        for garment in sortedOutfits.flatMap(\.pieces) + (extraGarments ?? []) where seen.insert(garment.uuid).inserted {
            result.append(garment)
        }
        return result
    }

    /// Lista de equipaje agrupada por dónde está cada prenda, para recogerlo todo de una vez.
    var packingListByLocation: [(place: String, garments: [Garment])] {
        let groups = Dictionary(grouping: packingList) { $0.location?.path ?? String(localized: "Sin ubicación") }
        return groups
            .map { (place: $0.key, garments: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.place.localizedStandardCompare($1.place) == .orderedAscending }
    }

    func isPacked(_ garment: Garment) -> Bool {
        packedGarmentIDs.contains(garment.uuid.uuidString)
    }

    func togglePacked(_ garment: Garment) {
        let id = garment.uuid.uuidString
        if let index = packedGarmentIDs.firstIndex(of: id) {
            packedGarmentIDs.remove(at: index)
        } else {
            packedGarmentIDs.append(id)
        }
    }

    var packedCount: Int { packingList.filter(isPacked).count }

    var isUpcoming: Bool { Calendar.current.startOfDay(for: endDate) >= Calendar.current.startOfDay(for: .now) }
}

/// Cálculos de la semana para el planificador.
nonisolated enum WeekPlanner {
    /// Los siete días de la semana que contiene `date`, empezando por el primer día de la
    /// semana del calendario del usuario (lunes en España).
    static func days(around date: Date, calendar: Calendar = .current) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    static func plan(for day: Date, in plans: [OutfitPlan], calendar: Calendar = .current) -> OutfitPlan? {
        plans.first { calendar.isDate($0.day, inSameDayAs: day) }
    }
}
