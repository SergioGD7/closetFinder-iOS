import Foundation
import MapKit

/// Busca en el mapa el destino de un viaje, para saber en qué hemisferio está.
nonisolated enum TripPlace {
    struct Place: Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// Coordenadas de un lugar escrito por el usuario («Lisboa», «Navacerrada»).
    static func locate(_ query: String) async -> Place? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let coordinate = item.placemark.coordinate
        return Place(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
