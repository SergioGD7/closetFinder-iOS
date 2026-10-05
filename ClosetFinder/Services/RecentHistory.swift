import Foundation

/// Búsquedas recientes y prendas vistas hace poco, para la pantalla de Buscar.
/// Se guardan en `UserDefaults` como texto, un elemento por línea, del más reciente al más antiguo.
nonisolated enum RecentHistory {
    static let searchesKey = "recentSearches"
    static let garmentsKey = "recentGarments"
    static let searchLimit = 6
    static let garmentLimit = 10

    static func decode(_ storage: String) -> [String] {
        storage.split(separator: "\n").map(String.init)
    }

    /// Pone el elemento el primero, sin repetirlo y sin pasar del límite.
    static func adding(_ item: String, to storage: String, limit: Int, caseInsensitive: Bool = false) -> String {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return storage }
        let others = decode(storage).filter { existing in
            caseInsensitive ? existing.caseInsensitiveCompare(trimmed) != .orderedSame : existing != trimmed
        }
        return ([trimmed] + others).prefix(limit).joined(separator: "\n")
    }

    static func removing(_ item: String, from storage: String) -> String {
        decode(storage).filter { $0 != item }.joined(separator: "\n")
    }

    static func recordGarment(_ id: UUID, defaults: UserDefaults = .standard) {
        let current = defaults.string(forKey: garmentsKey) ?? ""
        defaults.set(adding(id.uuidString, to: current, limit: garmentLimit), forKey: garmentsKey)
    }
}
