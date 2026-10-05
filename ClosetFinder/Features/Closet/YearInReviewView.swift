import SwiftData
import SwiftUI

/// «Tu año en ropa»: el look más repetido, la prenda estrella, tus colores y lo que no te has
/// puesto. Se puede compartir como imagen.
struct YearInReviewView: View {
    @Query private var garments: [Garment]
    @Query private var outfits: [Outfit]

    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var shareImage: UIImage?

    var body: some View {
        let review = YearInReview(year: year, garments: garments, outfits: outfits)
        ScrollView {
            YearInReviewCard(review: review)
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Tu \(String(year)) en ropa"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                let years = YearInReview.years(garments: garments, outfits: outfits)
                if years.count > 1 {
                    Menu {
                        Picker("Año", selection: $year) {
                            ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
                        }
                    } label: {
                        Label("Año", systemImage: "calendar")
                    }
                }
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview(String(localized: "Tu \(String(year)) en ropa"), image: Image(uiImage: shareImage))) {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: year) {
            shareImage = ShareImageRenderer.render(YearInReviewCard(review: review).padding(16), width: 400)
        }
    }
}

/// La tarjeta del resumen anual. La misma vista se usa en pantalla y en la imagen que se comparte.
struct YearInReviewCard: View {
    let review: YearInReview

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: String(review.year))
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor.gradient)
                Text("Tu año en ropa")
                    .font(.title2.bold())
            }

            if !review.hasActivity {
                Text("Aún no hay nada que contar de este año. Usa «Llevar hoy» en tus looks y aquí verás lo que más te pones.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("\(review.looksWorn)", String(localized: "Looks puestos"))
                    tile("\(review.garmentsWorn)/\(review.garmentCount)", String(localized: "Prendas que te has puesto"))
                    tile("\(review.newGarments)", String(localized: "Prendas nuevas"))
                    tile(WardrobeValue.format(review.spent), String(localized: "Gastado en ropa"))
                }

                if let star = review.starGarment {
                    highlight(title: String(localized: "Tu prenda estrella"), name: star.garment.displayName,
                              detail: star.count == 1 ? String(localized: "1 puesta") : String(localized: "\(star.count) puestas")) {
                        GarmentImage(garment: star.garment, inset: 0.1)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                if let look = review.mostWornOutfit {
                    highlight(title: String(localized: "El look que más has repetido"), name: look.outfit.displayName,
                              detail: look.count == 1 ? String(localized: "1 vez") : String(localized: "\(look.count) veces")) {
                        OutfitFigure(garments: look.outfit.pieces, spacing: 1)
                            .padding(6)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                if !review.topColors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tus colores").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            ForEach(review.topColors) { color in
                                HStack(spacing: 6) {
                                    ColorSwatch(color: color, size: 22)
                                    Text(color.title).font(.subheadline.weight(.medium))
                                }
                            }
                        }
                    }
                }
                if review.notWorn > 0 {
                    Label(review.notWorn == 1 ? String(localized: "1 prenda se ha quedado en el armario todo el año")
                          : String(localized: "\(review.notWorn) prendas se han quedado en el armario todo el año"),
                          systemImage: "moon.zzz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Label("Closet Finder", systemImage: "hanger")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func tile(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func highlight<Picture: View>(title: String, name: String, detail: String,
                                          @ViewBuilder picture: () -> Picture) -> some View {
        HStack(spacing: 14) {
            picture().frame(width: 64, height: 80)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(name).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// Convierte una vista en imagen para compartirla.
enum ShareImageRenderer {
    static func render<Content: View>(_ content: Content, width: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: content
            .frame(width: width)
            .background(Color(.systemGroupedBackground)))
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview {
    NavigationStack {
        YearInReviewView()
    }
    .modelContainer(AppModelContainer.preview())
}
