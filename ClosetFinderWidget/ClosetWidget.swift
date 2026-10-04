import AppIntents
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@main
struct ClosetFinderWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClosetWidget()
    }
}

/// Widget configurable: al editarlo se elige qué mostrar (prendas sin ponerte, el look de hoy,
/// favoritas, prestadas, una categoría…). Cada prenda dice dónde está.
struct ClosetWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ClosetWidget", intent: ClosetWidgetIntent.self, provider: ClosetProvider()) { entry in
            ClosetWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Closet Finder")
        .description("Prendas sin ponerte, el look de hoy, favoritas, prestadas o una categoría, con dónde está cada una.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Configuración

/// Qué mostrar: un solo parámetro con los tipos de lista y, después, cada categoría.
/// (Un parámetro de categoría aparte, visible solo a veces, no compila en Xcode 26.)
nonisolated enum WidgetContent: String, AppEnum {
    case forgotten, todayLook, favorites, recent, lent, laundry, toDonate
    case tShirt, shirt, sweater, jacket, coat, blazer, trousers, shorts, skirt, dress, shoes, underwear, swimwear, accessories

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contenido"
    static let caseDisplayRepresentations: [WidgetContent: DisplayRepresentation] = [
        .forgotten: "Sin ponerte",
        .todayLook: "Look de hoy",
        .favorites: "Favoritas",
        .recent: "Añadidas recientemente",
        .lent: "Prestadas",
        .laundry: "Lavando",
        .toDonate: "Para donar",
        .tShirt: "Camisetas", .shirt: "Camisas", .sweater: "Jerséis y sudaderas", .jacket: "Chaquetas",
        .coat: "Abrigos", .blazer: "Americanas", .trousers: "Pantalones", .shorts: "Pantalones cortos",
        .skirt: "Faldas", .dress: "Vestidos", .shoes: "Calzado", .underwear: "Ropa interior",
        .swimwear: "Baño", .accessories: "Accesorios",
    ]

    /// La categoría, si se ha elegido una.
    var category: GarmentCategory? { GarmentCategory(rawValue: rawValue) }

    var kind: ClosetWidgetKind {
        category != nil ? .category : ClosetWidgetKind(rawValue: rawValue) ?? .forgotten
    }
}

struct ClosetWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Qué mostrar"
    static let description = IntentDescription("Elige qué prendas enseña el widget.")

    @Parameter(title: "Mostrar", default: .forgotten)
    var content: WidgetContent
}

// MARK: Datos

nonisolated struct WidgetItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let place: String
    let detail: String
    let category: GarmentCategory
    let color: GarmentColor
    let thumbnail: Data?
    let hasCutout: Bool

    init(_ garment: Garment, kind: ClosetWidgetKind) {
        id = garment.uuid
        name = garment.displayName
        place = garment.location?.shortPath ?? String(localized: "Sin ubicación")
        detail = ClosetWidgetResolver.detail(for: garment, kind: kind)
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

nonisolated struct ClosetEntry: TimelineEntry, Sendable {
    let date: Date
    let kind: ClosetWidgetKind
    /// Título: el tipo elegido, el nombre de la categoría o el del look de hoy.
    let title: String
    let items: [WidgetItem]
    var outfitID: UUID?

    static let sample = ClosetEntry(date: .now, kind: .forgotten, title: ClosetWidgetKind.forgotten.title, items: [
        WidgetItem(name: String(localized: "Plumífero azul marino"), place: String(localized: "Trastero · Caja «Nieve»"),
                   detail: String(localized: "Hace \(250) días"), category: .coat, color: .navy),
        WidgetItem(name: String(localized: "Botas de montaña"), place: String(localized: "Trastero · Caja «Nieve»"),
                   detail: String(localized: "Hace \(240) días"), category: .shoes, color: .brown),
        WidgetItem(name: String(localized: "Jersey de punto burdeos"), place: String(localized: "Trastero · Caja «Invierno»"),
                   detail: String(localized: "Hace \(180) días"), category: .sweater, color: .burgundy),
    ])
}

nonisolated struct ClosetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClosetEntry { .sample }

    func snapshot(for configuration: ClosetWidgetIntent, in context: Context) async -> ClosetEntry {
        context.isPreview ? .sample : Self.load(configuration)
    }

    func timeline(for configuration: ClosetWidgetIntent, in context: Context) async -> Timeline<ClosetEntry> {
        // A medianoche cambia el look de hoy; el resto también se refresca al salir de la app.
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: .now.addingTimeInterval(86_400))
        let next = min(midnight, Date.now.addingTimeInterval(6 * 3600))
        return Timeline(entries: [Self.load(configuration)], policy: .after(next))
    }

    static func load(_ configuration: ClosetWidgetIntent) -> ClosetEntry {
        let kind = configuration.content.kind
        let category = configuration.content.category
        let context = ModelContext(AppModelContainer.shared)
        let garments = (try? context.fetch(FetchDescriptor<Garment>())) ?? []
        let plans = kind == .todayLook ? ((try? context.fetch(FetchDescriptor<OutfitPlan>())) ?? []) : []
        let selected = ClosetWidgetResolver.garments(for: kind, category: category, in: garments, plans: plans)

        var title = category?.title ?? kind.title
        var outfitID: UUID?
        if kind == .todayLook, let outfit = ClosetWidgetResolver.todayOutfit(in: plans) {
            title = outfit.displayName
            outfitID = outfit.uuid
        }
        return ClosetEntry(date: .now, kind: kind, title: title,
                           items: selected.prefix(4).map { WidgetItem($0, kind: kind) }, outfitID: outfitID)
    }
}

// MARK: Vistas

struct ClosetWidgetView: View {
    let entry: ClosetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer()
                Text(entry.kind.emptyMessage)
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
        HStack(spacing: 5) {
            Image(systemName: entry.kind.symbol)
            Text(entry.kind == .todayLook && !entry.items.isEmpty ? String(localized: "Hoy: \(entry.title)") : entry.title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.brand)
    }

    private func small(_ item: WidgetItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            Spacer(minLength: 2)
            Thumbnail(item: item)
                .frame(width: 56, height: 56)
            Text(item.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Label(item.place, systemImage: "mappin")
                .font(.caption2)
                .foregroundStyle(Color.brand)
                .lineLimit(1)
            Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.garment(item.id).url)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .top, spacing: 10) {
                ForEach(entry.items.prefix(entry.kind == .todayLook ? 4 : 3)) { item in
                    Link(destination: DeepLink.garment(item.id).url) {
                        VStack(alignment: .leading, spacing: 3) {
                            Thumbnail(item: item)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                            Text(item.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(item.place)
                                .font(.caption2)
                                .foregroundStyle(Color.brand)
                                .lineLimit(1)
                            if entry.kind != .todayLook {
                                Text(item.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct Thumbnail: View {
    let item: WidgetItem

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
    ClosetWidget()
} timeline: {
    ClosetEntry.sample
}
