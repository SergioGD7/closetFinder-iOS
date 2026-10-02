import Foundation

/// Cálculos sobre el uso del armario, compartidos por las estadísticas y el widget.
nonisolated enum WardrobeInsights {
    /// A partir de cuántos días sin ponerse una prenda se considera olvidada.
    static let forgottenAfterDays = 180

    /// Última vez que se usó o, si nunca se ha usado, cuándo se dio de alta.
    static func lastActivity(of garment: Garment) -> Date {
        garment.lastWornAt ?? garment.createdAt
    }

    static func daysSinceWorn(_ garment: Garment, now: Date = .now) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: lastActivity(of: garment), to: now).day ?? 0)
    }

    /// Prendas guardadas ordenadas de la que lleva más tiempo sin usarse a la que menos.
    static func leastRecentlyWorn(_ garments: [Garment]) -> [Garment] {
        garments
            .filter { $0.status == .stored }
            .sorted { lastActivity(of: $0) < lastActivity(of: $1) }
    }

    /// Prendas guardadas que no se usan desde hace `forgottenAfterDays` días o más.
    static func forgotten(_ garments: [Garment], now: Date = .now) -> [Garment] {
        leastRecentlyWorn(garments).filter { daysSinceWorn($0, now: now) >= forgottenAfterDays }
    }

    static func mostWorn(_ garments: [Garment], limit: Int = 5) -> [Garment] {
        Array(garments.filter { $0.wearCount > 0 }.sorted { $0.wearCount > $1.wearCount }.prefix(limit))
    }

    /// «hace 142 días», «sin estrenar», «hoy»
    static func wornDescription(_ garment: Garment, now: Date = .now) -> String {
        guard garment.lastWornAt != nil else { return String(localized: "Sin estrenar") }
        let days = daysSinceWorn(garment, now: now)
        switch days {
        case 0: return String(localized: "Usada hoy")
        case 1: return String(localized: "Usada ayer")
        default: return String(localized: "Hace \(days) días")
        }
    }
}
