import Foundation

/// Qué puede mostrar el widget. Se elige al editar el widget en la pantalla de inicio.
nonisolated enum ClosetWidgetKind: String, CaseIterable, Sendable {
    case forgotten, todayLook, favorites, recent, lent, laundry, toDonate, category

    var title: String {
        switch self {
        case .forgotten: String(localized: "Sin ponerte")
        case .todayLook: String(localized: "Look de hoy")
        case .favorites: String(localized: "Favoritas")
        case .recent: String(localized: "Añadidas recientemente")
        case .lent: String(localized: "Prestadas")
        case .laundry: String(localized: "Lavando")
        case .toDonate: String(localized: "Para donar")
        case .category: String(localized: "Una categoría")
        }
    }

    var symbol: String {
        switch self {
        case .forgotten: "moon.zzz.fill"
        case .todayLook: "tshirt.fill"
        case .favorites: "heart.fill"
        case .recent: "sparkles"
        case .lent: "hand.raised.fill"
        case .laundry: "washer.fill"
        case .toDonate: "gift.fill"
        case .category: "hanger"
        }
    }

    var emptyMessage: String {
        switch self {
        case .forgotten: String(localized: "Añade prendas y aquí verás las que llevas tiempo sin ponerte.")
        case .todayLook: String(localized: "No hay ningún look planificado para hoy.")
        case .favorites: String(localized: "Marca prendas como favoritas para verlas aquí.")
        case .recent: String(localized: "Añade prendas para verlas aquí.")
        case .lent: String(localized: "No tienes nada prestado.")
        case .laundry: String(localized: "No hay nada lavándose.")
        case .toDonate: String(localized: "No hay nada para donar.")
        case .category: String(localized: "No tienes prendas de esta categoría.")
        }
    }
}

/// Elige las prendas que enseña el widget. Separado de WidgetKit para poder probarlo.
nonisolated enum ClosetWidgetResolver {

    static func todayOutfit(in plans: [OutfitPlan], now: Date = .now, calendar: Calendar = .current) -> Outfit? {
        WeekPlanner.plan(for: now, in: plans, calendar: calendar)?.outfit
    }

    static func garments(for kind: ClosetWidgetKind, category: GarmentCategory? = nil,
                         in garments: [Garment], plans: [OutfitPlan] = [], now: Date = .now) -> [Garment] {
        switch kind {
        case .forgotten:
            return WardrobeInsights.leastRecentlyWorn(garments)
        case .todayLook:
            return todayOutfit(in: plans, now: now)?.pieces ?? []
        case .favorites:
            return garments.filter(\.isFavorite).sorted { $0.displayName < $1.displayName }
        case .recent:
            return garments.sorted { $0.createdAt > $1.createdAt }
        case .lent:
            return garments.filter { $0.status == .lent }
        case .laundry:
            return garments.filter { $0.status == .laundry }
        case .toDonate:
            return garments.filter { $0.status == .toDonate }
        case .category:
            guard let category else { return [] }
            return garments.filter { $0.category == category }.sorted { $0.displayName < $1.displayName }
        }
    }

    /// Texto bajo cada prenda según lo que muestre el widget.
    static func detail(for garment: Garment, kind: ClosetWidgetKind, now: Date = .now) -> String {
        switch kind {
        case .forgotten:
            return WardrobeInsights.wornDescription(garment, now: now)
        case .lent, .laundry, .toDonate:
            return garment.status.title
        case .todayLook, .favorites, .recent, .category:
            return garment.size.isEmpty ? garment.category.singular : String(localized: "Talla \(garment.size)")
        }
    }
}
