import SwiftData
import SwiftUI

/// «Según la época del viaje»: qué capas llevar (con una prenda tuya para cada una) y looks que
/// encajan, con un botón para añadirlos a la maleta. La época sale de las fechas y del hemisferio
/// del destino.
struct TripAdviceSection: View {
    @Bindable var trip: Trip
    var onEditDestination: () -> Void

    @Query private var garments: [Garment]
    @Query(sort: \Outfit.createdAt) private var outfits: [Outfit]
    @State private var addedFeedback = 0

    var body: some View {
        let season = PackingAdvisor.season(start: trip.startDate, latitude: trip.latitude)
        let advice = PackingAdvisor.advice(for: trip, season: season, closet: garments, outfits: outfits)
        Section {
            seasonRow(season)
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
            Text("Según la época del viaje")
        } footer: {
            Text(lookText(advice))
        }
        .sensoryFeedback(.success, trigger: addedFeedback)
    }

    private func seasonRow(_ season: Season) -> some View {
        HStack(spacing: 12) {
            Image(systemName: season.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(season.title).font(.body.weight(.semibold))
                if trip.destination.isEmpty {
                    Button("Añade el destino si es en el otro hemisferio", action: onEditDestination)
                        .font(.caption)
                } else {
                    Text(trip.destination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

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

    private func lookText(_ advice: PackingAdvisor.Advice) -> String {
        let days = trip.dayCount
        if days > advice.lookCount {
            return String(localized: "Son \(days) días: con \(advice.lookCount) looks y una lavadora vas bien.")
        }
        return days == 1 ? String(localized: "Es 1 día: con un look vas bien.") : String(localized: "Son \(days) días: lleva \(advice.lookCount) looks.")
    }
}
