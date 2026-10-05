import SwiftData
import SwiftUI

/// «Según el destino»: el tiempo previsto, qué capas llevar (con una prenda tuya para cada una)
/// y looks que encajan, con un botón para añadirlos a la maleta.
struct TripAdviceSection: View {
    @Bindable var trip: Trip
    var onEditDestination: () -> Void

    @Query private var garments: [Garment]
    @Query(sort: \Outfit.createdAt) private var outfits: [Outfit]
    @Environment(\.colorScheme) private var colorScheme

    enum WeatherState {
        case noDestination, tooFar, loading, loaded, unavailable
    }

    @State private var forecast: TripForecast?
    @State private var state: WeatherState = .noDestination
    @State private var attribution: TripWeather.Attribution?
    @State private var addedFeedback = 0

    private var effectiveForecast: TripForecast {
        forecast ?? TripForecast.seasonal(start: trip.startDate, latitude: trip.latitude)
    }

    /// Cambia cuando hay que volver a pedir el tiempo.
    private var weatherKey: String {
        "\(trip.latitude ?? 0),\(trip.longitude ?? 0),\(trip.startDate.timeIntervalSince1970),\(trip.endDate.timeIntervalSince1970)"
    }

    var body: some View {
        let forecast = effectiveForecast
        let advice = PackingAdvisor.advice(for: trip, forecast: forecast, closet: garments, outfits: outfits)
        Section {
            weatherRow(forecast)
            ForEach(advice.layers) { item in
                layerRow(item)
            }
            ForEach(advice.outfits) { outfit in
                HStack {
                    OutfitRow(outfit: outfit)
                    Button {
                        trip.outfits = (trip.outfits ?? []) + [outfit]
                        addedFeedback += 1
                    } label: {
                        Label("Añadir a la maleta", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Según el destino")
        } footer: {
            footer(forecast, advice: advice)
        }
        .task(id: weatherKey) { await loadWeather() }
        .sensoryFeedback(.success, trigger: addedFeedback)
    }

    // MARK: Tiempo

    @ViewBuilder
    private func weatherRow(_ forecast: TripForecast) -> some View {
        if trip.destination.isEmpty {
            Button(action: onEditDestination) {
                Label("Añade el destino para ver el tiempo previsto", systemImage: "mappin.and.ellipse")
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: forecast.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.destination).font(.body.weight(.semibold))
                    Text(weatherText(forecast))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if state == .loading { ProgressView() }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func weatherText(_ forecast: TripForecast) -> String {
        guard forecast.source == .forecast, let low = forecast.low, let high = forecast.high else {
            return String(localized: "Época: \(forecast.season.title)")
        }
        let range = "\(Self.temperature(low)) – \(Self.temperature(high))"
        var parts = [range]
        if forecast.rainyDays > 0 {
            parts.append(forecast.rainyDays == 1 ? String(localized: "1 día de lluvia") : String(localized: "\(forecast.rainyDays) días de lluvia"))
        }
        if forecast.snowyDays > 0 {
            parts.append(forecast.snowyDays == 1 ? String(localized: "1 día de nieve") : String(localized: "\(forecast.snowyDays) días de nieve"))
        }
        return parts.joined(separator: " · ")
    }

    /// «12 °C» o «54 °F» según la región.
    static func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    // MARK: Capas

    private func layerRow(_ item: PackingAdvisor.LayerAdvice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.layer.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.layer.title).font(.subheadline.weight(.semibold))
                Group {
                    if item.isCovered {
                        Text("Ya va en la maleta")
                    } else if let suggestion = item.suggestion {
                        Text(verbatim: "\(suggestion.displayName) · \(suggestion.location?.shortPath ?? String(localized: "Sin ubicación"))")
                    } else {
                        Text("No tienes ninguna prenda así disponible")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if item.isCovered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityLabel(String(localized: "Ya va en la maleta"))
            } else if let suggestion = item.suggestion {
                Button {
                    trip.extraGarments = (trip.extraGarments ?? []) + [suggestion]
                    addedFeedback += 1
                } label: {
                    Label("Añadir \(suggestion.displayName)", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: Pie

    @ViewBuilder
    private func footer(_ forecast: TripForecast, advice: PackingAdvisor.Advice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lookText(advice))
            switch state {
            case .tooFar:
                Text("La previsión aparece diez días antes del viaje. Mientras, te orientamos por la época del año.")
            case .unavailable:
                Text("No se ha podido consultar el tiempo. Te orientamos por la época del año.")
            default:
                EmptyView()
            }
            if forecast.source == .forecast, let attribution {
                HStack(spacing: 8) {
                    AsyncImage(url: colorScheme == .dark ? attribution.darkMark : attribution.lightMark) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(height: 12)
                    Link("Fuentes de datos", destination: attribution.legalPage)
                }
            }
        }
    }

    private func lookText(_ advice: PackingAdvisor.Advice) -> String {
        let days = trip.dayCount
        if days > advice.lookCount {
            return String(localized: "Son \(days) días: con \(advice.lookCount) looks y una lavadora vas bien.")
        }
        return days == 1 ? String(localized: "Es 1 día: con un look vas bien.") : String(localized: "Son \(days) días: lleva \(advice.lookCount) looks.")
    }

    private func loadWeather() async {
        guard let latitude = trip.latitude, let longitude = trip.longitude else {
            forecast = nil
            state = .noDestination
            return
        }
        guard TripWeather.isWithinForecastRange(start: trip.startDate, end: trip.endDate) else {
            forecast = nil
            state = .tooFar
            return
        }
        state = .loading
        if let result = await TripWeather.forecast(latitude: latitude, longitude: longitude, start: trip.startDate, end: trip.endDate) {
            forecast = result
            attribution = await TripWeather.attribution()
            state = .loaded
        } else {
            forecast = nil
            state = .unavailable
        }
    }
}
