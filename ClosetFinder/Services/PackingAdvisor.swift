import Foundation

/// El tiempo de un viaje: la previsión real (WeatherKit) o, si aún no la hay, la época del año.
nonisolated struct TripForecast: Equatable, Sendable {
    enum Source: Sendable {
        /// Previsión de WeatherKit para los días del viaje.
        case forecast
        /// Estimación por la época del año y el hemisferio.
        case season
    }

    var source: Source
    /// Mínima y máxima del viaje, en °C.
    var low: Double?
    var high: Double?
    var rainyDays = 0
    var snowyDays = 0
    var season: Season
    var symbol: String

    init(source: Source, low: Double? = nil, high: Double? = nil, rainyDays: Int = 0, snowyDays: Int = 0,
         season: Season? = nil, symbol: String = "cloud.sun") {
        self.source = source
        self.low = low
        self.high = high
        self.rainyDays = rainyDays
        self.snowyDays = snowyDays
        self.symbol = symbol
        if let season {
            self.season = season
        } else if let low, let high {
            let average = (low + high) / 2
            self.season = average < 12 ? .autumnWinter : (average > 22 ? .springSummer : .midSeason)
        } else {
            self.season = .midSeason
        }
    }

    /// Estimación por el mes de salida. Sin coordenadas, se supone el hemisferio norte.
    static func seasonal(start: Date, latitude: Double?, calendar: Calendar = .current) -> TripForecast {
        var month = calendar.component(.month, from: start)
        if let latitude, latitude < 0 { month = (month + 5) % 12 + 1 }
        let season: Season = switch month {
        case 11, 12, 1, 2: .autumnWinter
        case 6, 7, 8, 9: .springSummer
        default: .midSeason
        }
        let symbol = switch season {
        case .autumnWinter: "snowflake"
        case .springSummer: "sun.max"
        default: "cloud.sun"
        }
        return TripForecast(source: .season, season: season, symbol: symbol)
    }
}

/// Lo que conviene llevar según el tiempo.
nonisolated enum PackingLayer: String, CaseIterable, Identifiable, Sendable {
    case coat, warmLayer, lightJacket, rain, light, swimwear

    var id: Self { self }

    var title: String {
        switch self {
        case .coat: String(localized: "Abrigo")
        case .warmLayer: String(localized: "Jersey o sudadera")
        case .lightJacket: String(localized: "Chaqueta ligera")
        case .rain: String(localized: "Algo para la lluvia")
        case .light: String(localized: "Ropa fresca")
        case .swimwear: String(localized: "Bañador")
        }
    }

    var symbol: String {
        switch self {
        case .coat: "snowflake"
        case .warmLayer: "thermometer.low"
        case .lightJacket: "wind"
        case .rain: "cloud.rain"
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
        case .rain: [.coat, .jacket]
        case .light: [.tShirt, .shorts, .dress, .skirt]
        case .swimwear: [.swimwear]
        }
    }
}

/// Consejos para una maleta: cuántos looks, qué capas y qué looks tuyos encajan con el tiempo.
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

    static func layers(for forecast: TripForecast) -> [PackingLayer] {
        var result: [PackingLayer] = []
        if let low = forecast.low, let high = forecast.high {
            let needsCoat = low < 8 || forecast.snowyDays > 0
            if needsCoat { result.append(.coat) }
            if low < 14 { result.append(.warmLayer) }
            if !needsCoat, low < 18 { result.append(.lightJacket) }
            if forecast.rainyDays > 0 { result.append(.rain) }
            if high >= 24 { result.append(.light) }
            if high >= 27 { result.append(.swimwear) }
        } else {
            switch forecast.season {
            case .autumnWinter: result = [.coat, .warmLayer]
            case .springSummer: result = [.light, .swimwear]
            case .midSeason, .allYear: result = [.lightJacket, .warmLayer]
            }
        }
        return result
    }

    static func fits(_ garment: Garment, _ season: Season) -> Bool {
        garment.season == .allYear || garment.season == season || garment.season == .midSeason
    }

    static func isAvailable(_ garment: Garment) -> Bool {
        garment.status == .stored || garment.status == .inUse
    }

    static func advice(for trip: Trip, forecast: TripForecast, closet: [Garment], outfits: [Outfit]) -> Advice {
        let packed = trip.packingList
        let packedIDs = Set(packed.map(\.uuid))
        let layers = layers(for: forecast).map { layer in
            let isCovered = packed.contains { layer.categories.contains($0.category) }
            let candidates = closet.filter { garment in
                layer.categories.contains(garment.category) && isAvailable(garment)
                    && !packedIDs.contains(garment.uuid) && fits(garment, forecast.season)
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
            let value = score(outfit, for: forecast)
            if value > 0 { scored.append((outfit, value)) }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.outfit.wearCount > rhs.outfit.wearCount
        }
        return Advice(lookCount: wanted, layers: layers, outfits: scored.prefix(missing).map(\.outfit))
    }

    /// Cuánto encaja un look con el tiempo. Negativo o cero: mejor no llevarlo.
    static func score(_ outfit: Outfit, for forecast: TripForecast) -> Int {
        let categories = Set(outfit.pieces.map(\.category))
        var score = 0
        for garment in outfit.pieces {
            score += fits(garment, forecast.season) ? 1 : -2
        }
        let warm: Set<GarmentCategory> = [.coat, .sweater]
        let cool: Set<GarmentCategory> = [.shorts, .swimwear]
        switch forecast.season {
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
        if forecast.rainyDays > 0, !categories.isDisjoint(with: [.jacket, .coat]) { score += 1 }
        return score
    }
}
