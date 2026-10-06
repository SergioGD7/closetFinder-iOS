import Foundation

/// Lo que conviene llevar según la época del viaje.
nonisolated enum PackingLayer: String, CaseIterable, Identifiable, Sendable {
    case coat, warmLayer, lightJacket, light, swimwear

    var id: Self { self }

    var title: String {
        switch self {
        case .coat: String(localized: "Abrigo")
        case .warmLayer: String(localized: "Jersey o sudadera")
        case .lightJacket: String(localized: "Chaqueta ligera")
        case .light: String(localized: "Ropa fresca")
        case .swimwear: String(localized: "Bañador")
        }
    }

    var symbol: String {
        switch self {
        case .coat: "snowflake"
        case .warmLayer: "tshirt"
        case .lightJacket: "hanger"
        case .light: "sun.max"
        case .swimwear: "beach.umbrella"
        }
    }

    /// Categorías que cubren esta necesidad.
    var categories: [GarmentCategory] {
        switch self {
        case .coat: [.coat]
        case .warmLayer: [.sweater]
        case .lightJacket: [.jacket, .blazer]
        case .light: [.tShirt, .shorts, .dress, .skirt]
        case .swimwear: [.swimwear]
        }
    }
}

/// Consejos para una maleta: cuántos looks, qué capas y qué looks tuyos encajan con la época.
nonisolated enum PackingAdvisor {

    struct LayerAdvice: Identifiable {
        let layer: PackingLayer
        /// Ya hay algo en la maleta que lo cubre.
        let isCovered: Bool
        /// Una prenda tuya que lo cubriría.
        let suggestion: Garment?
        var id: PackingLayer { layer }
    }

    struct Advice {
        let lookCount: Int
        let layers: [LayerAdvice]
        let outfits: [Outfit]
    }

    /// Un look por día; a partir de una semana, con siete y una lavadora basta.
    static func lookCount(forDays days: Int) -> Int { min(max(days, 1), 7) }

    /// Época del viaje por el mes de salida. En el hemisferio sur se invierte; sin coordenadas,
    /// se supone el norte.
    static func season(start: Date, latitude: Double?, calendar: Calendar = .current) -> Season {
        var month = calendar.component(.month, from: start)
        if let latitude, latitude < 0 { month = (month + 5) % 12 + 1 }
        return switch month {
        case 11, 12, 1, 2: .autumnWinter
        case 6, 7, 8, 9: .springSummer
        default: .midSeason
        }
    }

    static func layers(for season: Season) -> [PackingLayer] {
        switch season {
        case .autumnWinter: [.coat, .warmLayer]
        case .springSummer: [.light, .swimwear]
        case .midSeason, .allYear: [.lightJacket, .warmLayer]
        }
    }

    static func fits(_ garment: Garment, _ season: Season) -> Bool {
        garment.season == .allYear || garment.season == season || garment.season == .midSeason
    }

    static func isAvailable(_ garment: Garment) -> Bool {
        garment.status == .stored || garment.status == .inUse
    }

    static func advice(for trip: Trip, season: Season, closet: [Garment], outfits: [Outfit]) -> Advice {
        let packed = trip.packingList
        let packedIDs = Set(packed.map(\.uuid))
        let layers = layers(for: season).map { layer in
            let isCovered = packed.contains { layer.categories.contains($0.category) }
            let candidates = closet.filter { garment in
                layer.categories.contains(garment.category) && isAvailable(garment)
                    && !packedIDs.contains(garment.uuid) && fits(garment, season)
            }
            let suggestion = isCovered ? nil : candidates.sorted { lhs, rhs in
                lhs.isFavorite != rhs.isFavorite ? lhs.isFavorite : lhs.wearCount > rhs.wearCount
            }.first
            return LayerAdvice(layer: layer, isCovered: isCovered, suggestion: suggestion)
        }

        let wanted = lookCount(forDays: trip.dayCount)
        let current = trip.outfits ?? []
        let missing = max(0, wanted - current.count)
        var scored: [(outfit: Outfit, score: Int)] = []
        for outfit in outfits {
            let isInTrip = current.contains { $0 === outfit }
            guard !isInTrip, !outfit.pieces.isEmpty, outfit.unavailablePieces.isEmpty else { continue }
            let value = score(outfit, for: season)
            if value > 0 { scored.append((outfit, value)) }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.outfit.wearCount > rhs.outfit.wearCount
        }
        return Advice(lookCount: wanted, layers: layers, outfits: scored.prefix(missing).map(\.outfit))
    }

    /// Cuánto encaja un look con la época. Negativo o cero: mejor no llevarlo.
    static func score(_ outfit: Outfit, for season: Season) -> Int {
        let categories = Set(outfit.pieces.map(\.category))
        var score = 0
        for garment in outfit.pieces {
            score += fits(garment, season) ? 1 : -2
        }
        let warm: Set<GarmentCategory> = [.coat, .sweater]
        let cool: Set<GarmentCategory> = [.shorts, .swimwear]
        switch season {
        case .autumnWinter:
            if !categories.isDisjoint(with: cool) { score -= 3 }
            if !categories.isDisjoint(with: warm.union([.jacket])) { score += 2 }
        case .springSummer:
            if !categories.isDisjoint(with: warm) { score -= 3 }
            if !categories.isDisjoint(with: [.shorts, .tShirt, .dress, .skirt]) { score += 1 }
        case .midSeason, .allYear:
            if categories.contains(.coat) { score -= 1 }
            if !categories.isDisjoint(with: [.jacket, .blazer, .sweater]) { score += 1 }
            if categories.contains(.swimwear) { score -= 2 }
        }
        return score
    }
}
