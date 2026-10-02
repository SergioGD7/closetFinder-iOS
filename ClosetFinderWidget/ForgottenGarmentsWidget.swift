import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@main
struct ClosetFinderWidgetBundle: WidgetBundle {
    var body: some Widget {
        ForgottenGarmentsWidget()
    }
}

/// «Sin ponerte»: las prendas guardadas que llevas más tiempo sin usar, con dónde están.
struct ForgottenGarmentsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ForgottenGarments", provider: ForgottenProvider()) { entry in
            ForgottenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Sin ponerte")
        .description("Las prendas que llevas más tiempo sin usar y dónde están guardadas.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Datos

nonisolated struct ForgottenItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let place: String
    let detail: String
    let category: GarmentCategory
    let color: GarmentColor
    let thumbnail: Data?
    let hasCutout: Bool

    init(_ garment: Garment) {
        id = garment.uuid
        name = garment.displayName
        place = garment.location?.shortPath ?? String(localized: "Sin ubicación")
        detail = WardrobeInsights.wornDescription(garment)
        category = garment.category
        color = garment.primaryColor
        thumbnail = garment.thumbnail
        hasCutout = garment.hasCutout
    }

    init(name: String, place: String, detail: String, category: GarmentCategory, color: GarmentColor) {
        id = UUID()
        self.name = name
        self.place = place
        self.detail = detail
        self.category = category
        self.color = color
        thumbnail = nil
        hasCutout = false
    }
}

nonisolated struct ForgottenEntry: TimelineEntry, Sendable {
    let date: Date
    let items: [ForgottenItem]

    static let sample = ForgottenEntry(date: .now, items: [
        ForgottenItem(name: String(localized: "Plumífero azul marino"), place: String(localized: "Trastero · Caja «Nieve»"), detail: String(localized: "Hace \(250) días"), category: .coat, color: .navy),
        ForgottenItem(name: String(localized: "Botas de montaña"), place: String(localized: "Trastero · Caja «Nieve»"), detail: String(localized: "Hace \(240) días"), category: .shoes, color: .brown),
        ForgottenItem(name: String(localized: "Jersey de punto burdeos"), place: String(localized: "Trastero · Caja «Invierno»"), detail: String(localized: "Hace \(180) días"), category: .sweater, color: .burgundy),
    ])
}

nonisolated struct ForgottenProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForgottenEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (ForgottenEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForgottenEntry>) -> Void) {
        // La app pide refrescar al pasar a segundo plano; esto es solo por si acaso.
        let next = Date.now.addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [Self.load()], policy: .after(next)))
    }

    static func load() -> ForgottenEntry {
        let context = ModelContext(AppModelContainer.shared)
        let garments = (try? context.fetch(FetchDescriptor<Garment>())) ?? []
        let items = WardrobeInsights.leastRecentlyWorn(garments).prefix(3).map(ForgottenItem.init)
        return ForgottenEntry(date: .now, items: Array(items))
    }
}

// MARK: Vistas

struct ForgottenWidgetView: View {
    let entry: ForgottenEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer()
                Text("Añade prendas y aquí verás las que llevas tiempo sin ponerte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if family == .systemSmall, let item = entry.items.first {
            small(item)
        } else {
            medium
        }
    }

    private var header: some View {
        Label("Sin ponerte", systemImage: "moon.zzz.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand)
    }

    private func small(_ item: ForgottenItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                header
                Spacer(minLength: 0)
            }
            Spacer(minLength: 2)
            Thumbnail(item: item)
                .frame(width: 54, height: 54)
            Text(item.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Text(item.place)
                .font(.caption2)
                .foregroundStyle(Color.brand)
                .lineLimit(1)
            Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.garment(item.id).url)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .top, spacing: 10) {
                ForEach(entry.items) { item in
                    Link(destination: DeepLink.garment(item.id).url) {
                        VStack(alignment: .leading, spacing: 3) {
                            Thumbnail(item: item)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                            Text(item.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(item.place)
                                .font(.caption2)
                                .foregroundStyle(Color.brand)
                                .lineLimit(1)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct Thumbnail: View {
    let item: ForgottenItem

    var body: some View {
        ZStack {
            item.color.tint
            if let data = item.thumbnail, let image = UIImage(data: data) {
                if item.hasCutout {
                    Image(uiImage: image).resizable().scaledToFit().padding(5)
                } else {
                    Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }
                }
            } else {
                GarmentArtwork(category: item.category, color: item.color).padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview(as: .systemMedium) {
    ForgottenGarmentsWidget()
} timeline: {
    ForgottenEntry.sample
}
