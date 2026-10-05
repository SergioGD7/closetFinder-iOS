import CoreLocation
import Foundation
import MapKit
import WeatherKit

/// Tiempo previsto en el destino de un viaje (WeatherKit) y búsqueda del destino en el mapa.
nonisolated enum TripWeather {
    /// WeatherKit da la previsión diaria de los próximos diez días.
    static let forecastDays = 10

    struct Attribution: Sendable {
        let lightMark: URL
        let darkMark: URL
        let legalPage: URL
    }

    struct Place: Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// El viaje empieza dentro del plazo de la previsión y aún no ha terminado.
    static func isWithinForecastRange(start: Date, end: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard let limit = calendar.date(byAdding: .day, value: forecastDays - 1, to: today) else { return false }
        return calendar.startOfDay(for: start) <= limit && calendar.startOfDay(for: end) >= today
    }

    /// Mínima, máxima y días de lluvia o nieve. `nil` si no hay previsión (sin conexión, o en
    /// una compilación sin el permiso de WeatherKit, como en el simulador sin firmar).
    static func forecast(latitude: Double, longitude: Double, start: Date, end: Date,
                         calendar: Calendar = .current) async -> TripForecast? {
        let today = calendar.startOfDay(for: .now)
        let from = max(calendar.startOfDay(for: start), today)
        guard let limit = calendar.date(byAdding: .day, value: forecastDays, to: today),
              let endOfTrip = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))
        else { return nil }
        let to = min(endOfTrip, limit)
        guard from < to else { return nil }

        do {
            let days = try await WeatherService.shared.weather(
                for: CLLocation(latitude: latitude, longitude: longitude),
                including: .daily(startDate: from, endDate: to))
            let list = Array(days)
            guard !list.isEmpty else { return nil }
            let lows = list.map { $0.lowTemperature.converted(to: .celsius).value }
            let highs = list.map { $0.highTemperature.converted(to: .celsius).value }
            let wet = list.filter { $0.precipitationChance >= 0.4 }
            let rainy = wet.filter { $0.precipitation == .rain || $0.precipitation == .mixed || $0.precipitation == .hail }.count
            let snowy = wet.filter { $0.precipitation == .snow || $0.precipitation == .sleet }.count
            let symbols = Dictionary(grouping: list.map(\.symbolName), by: { $0 })
            let symbol = symbols.max { $0.value.count < $1.value.count }?.key ?? "cloud.sun"
            return TripForecast(source: .forecast, low: lows.min(), high: highs.max(),
                                rainyDays: rainy, snowyDays: snowy, symbol: symbol)
        } catch {
            return nil
        }
    }

    /// La marca de Apple Weather y el enlace a las fuentes de datos, obligatorios al mostrar la previsión.
    static func attribution() async -> Attribution? {
        guard let attribution = try? await WeatherService.shared.attribution else { return nil }
        return Attribution(lightMark: attribution.combinedMarkLightURL, darkMark: attribution.combinedMarkDarkURL,
                           legalPage: attribution.legalPageURL)
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
