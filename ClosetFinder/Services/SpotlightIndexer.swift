import CoreSpotlight
import SwiftData
import UniformTypeIdentifiers

/// Indexa las prendas en Spotlight para encontrarlas desde la búsqueda del sistema.
/// Al tocar un resultado se abre la app en el detalle de la prenda (ver `RootView`).
enum SpotlightIndexer {
    static let domain = "garment"

    static var isEnabled: Bool { !AppModelContainer.isInMemory }

    static func index(_ garments: [Garment]) {
        guard isEnabled, !garments.isEmpty else { return }
        CSSearchableIndex.default().indexSearchableItems(garments.map(item(for:)), completionHandler: nil)
    }

    static func index(_ garment: Garment) { index([garment]) }

    static func remove(_ garments: [Garment]) {
        guard isEnabled, !garments.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: garments.map(\.uuid.uuidString), completionHandler: nil)
    }

    static func reindexAll(in context: ModelContext) {
        guard let garments = try? context.fetch(FetchDescriptor<Garment>()) else { return }
        index(garments)
    }

    private static func item(for garment: Garment) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = garment.displayName
        attributes.contentDescription = [garment.size.isEmpty ? nil : "Talla \(garment.size)", garment.locationPath]
            .compactMap { $0 }
            .joined(separator: " · ")
        attributes.thumbnailData = garment.thumbnail
        attributes.keywords = [garment.category.title, garment.category.singular, garment.brand]
            + garment.colors.map(\.masculine)
            + (garment.location?.pathComponents ?? [])
        return CSSearchableItem(uniqueIdentifier: garment.uuid.uuidString, domainIdentifier: domain, attributeSet: attributes)
    }
}
