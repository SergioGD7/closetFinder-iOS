import Foundation
import SwiftData

/// Importación de muchas fotos de golpe. Cada foto pasa por el mismo procesado que una prenda
/// suelta (recorte, color y categoría), de cuatro en cuatro para no agotar la memoria.
@Observable
final class BatchImportModel {
    typealias DataLoader = @Sendable () async -> Data?
    typealias Processor = @Sendable (Data) async -> ProcessedImage?

    static let maxPhotos = 50
    static let maxConcurrent = 4

    struct Item: Identifiable {
        enum State {
            case waiting, processing, ready, failed
        }

        let id = UUID()
        var state: State = .waiting
        var image: ProcessedImage?
        var category: GarmentCategory?
        var colors: [GarmentColor] = []
        /// La categoría la ha confirmado el usuario.
        var isReviewed = false

        /// Lista, pero la app no sabe qué prenda es: hay que elegir la categoría.
        var needsReview: Bool { state == .ready && category == nil }
        var canBeAdded: Bool { state == .ready && category != nil }
    }

    var items: [Item] = []
    var location: StorageLocation?
    var owner: BodyProfile?
    var season: Season = .allYear

    var remainingSlots: Int { max(0, Self.maxPhotos - items.count) }
    var addable: [Item] { items.filter(\.canBeAdded) }
    var reviewCount: Int { items.filter(\.needsReview).count }
    var pendingCount: Int { items.filter { $0.state == .waiting || $0.state == .processing }.count }
    var failedCount: Int { items.filter { $0.state == .failed }.count }
    var isProcessing: Bool { pendingCount > 0 }

    /// «24 fotos · 21 listas · 2 por revisar · 1 en curso»
    var summary: String {
        var parts = [items.count == 1 ? String(localized: "1 foto") : String(localized: "\(items.count) fotos")]
        let ready = addable.count
        if ready > 0 { parts.append(ready == 1 ? String(localized: "1 lista") : String(localized: "\(ready) listas")) }
        if reviewCount > 0 { parts.append(String(localized: "\(reviewCount) por revisar")) }
        if pendingCount > 0 { parts.append(String(localized: "\(pendingCount) en curso")) }
        if failedCount > 0 { parts.append(String(localized: "\(failedCount) sin leer")) }
        return parts.joined(separator: " · ")
    }

    /// Procesa las fotos nuevas. Vuelve cuando han terminado todas.
    func process(_ loaders: [DataLoader], with processor: @escaping Processor = { await ImageProcessor.process($0) }) async {
        let accepted = Array(loaders.prefix(remainingSlots))
        let newItems = accepted.map { _ in Item() }
        items += newItems
        let jobs = Array(zip(newItems.map(\.id), accepted))

        await withTaskGroup(of: (UUID, ProcessedImage?).self) { group in
            var running = 0
            for (id, loader) in jobs {
                if running >= Self.maxConcurrent, let (doneID, result) = await group.next() {
                    finish(doneID, with: result)
                    running -= 1
                }
                update(id) { $0.state = .processing }
                group.addTask {
                    guard let data = await loader() else { return (id, nil) }
                    return (id, await processor(data))
                }
                running += 1
            }
            for await (doneID, result) in group {
                finish(doneID, with: result)
            }
        }
    }

    private func finish(_ id: UUID, with result: ProcessedImage?) {
        update(id) { item in
            guard let result else {
                item.state = .failed
                return
            }
            item.image = result
            item.category = result.category
            item.colors = result.colors
            item.state = .ready
        }
    }

    private func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    func review(_ id: UUID, category: GarmentCategory, colors: [GarmentColor]) {
        update(id) { item in
            item.category = category
            item.colors = colors
            item.isReviewed = true
        }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Crea una prenda por cada foto lista y las devuelve. Las que faltan por revisar se quedan fuera.
    @discardableResult
    func save(in context: ModelContext) -> [Garment] {
        let garments = addable.compactMap { item -> Garment? in
            guard let image = item.image, let category = item.category else { return nil }
            let garment = Garment(category: category, colors: item.colors)
            context.insert(garment)
            garment.photo = image.photo
            garment.thumbnail = image.thumbnail
            garment.hasCutout = image.isCutout
            garment.location = location
            garment.owner = owner
            garment.season = season
            return garment
        }
        try? context.save()
        return garments
    }
}
