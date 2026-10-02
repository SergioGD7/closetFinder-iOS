import SwiftUI

/// Tarjeta de la rejilla del Armario: foto, talla y dónde está.
struct GarmentCard: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1 / 1.06, contentMode: .fit)
                .overlay { GarmentImage(garment: garment) }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if !garment.size.isEmpty {
                        Text(garment.size)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .frame(minWidth: 30, minHeight: 28)
                            .glassBackground(in: Capsule())
                            .padding(8)
                    }
                }
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        if garment.isFavorite {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                        }
                        if garment.status != .stored {
                            Label(garment.status.title, systemImage: garment.status.symbol)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, garment.isFavorite || garment.status != .stored ? 8 : 0)
                    .frame(minHeight: 26)
                    .background {
                        if garment.isFavorite || garment.status != .stored {
                            Capsule().fill(.regularMaterial)
                        }
                    }
                    .padding(8)
                }

            Text(garment.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 2)

            HStack(spacing: 3) {
                Image(systemName: garment.location == nil ? "questionmark.folder" : "mappin")
                    .foregroundStyle(garment.location == nil ? Color.secondary : Color.accentColor)
                Text(garment.location?.shortPath ?? "Sin ubicación")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 2)
            .padding(.top, -3)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el detalle de la prenda")
    }
}
