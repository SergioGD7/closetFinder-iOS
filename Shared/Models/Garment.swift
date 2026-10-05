import Foundation
import SwiftData

/// Una prenda del inventario.
///
/// Todas las propiedades tienen valor por defecto y las relaciones son opcionales: son los
/// requisitos de CloudKit, así la sincronización con iCloud se podrá activar sin migraciones.
@Model
nonisolated final class Garment {
    var uuid: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = GarmentCategory.tShirt.rawValue
    var size: String = ""
    var colorsRaw: [String] = []
    var seasonRaw: String = Season.allYear.rawValue
    var statusRaw: String = GarmentStatus.stored.rawValue
    var brand: String = ""
    var material: String = ""
    var notes: String = ""

    /// Foto a resolución completa (máx. 1600 px). PNG con transparencia si se recortó el fondo.
    @Attribute(.externalStorage) var photo: Data?
    /// Miniatura para listas y rejillas (máx. 480 px).
    @Attribute(.externalStorage) var thumbnail: Data?
    var hasCutout: Bool = false
    /// Se incrementa cada vez que cambia la foto, para invalidar la caché de imágenes.
    var imageRevision: Int = 0

    // Medidas de la prenda en plano, en centímetros.
    var chestWidthCm: Double?
    var waistWidthCm: Double?
    var lengthCm: Double?
    var sleeveCm: Double?
    var inseamCm: Double?

    var location: StorageLocation?
    var owner: BodyProfile?
    /// Looks y maletas en los que aparece (relaciones inversas de `Outfit` y `Trip`).
    var outfits: [Outfit]? = []
    var trips: [Trip]? = []

    var isFavorite: Bool = false
    var wearCount: Int = 0
    var lastWornAt: Date?
    /// Días en que se puso, para las estadísticas de cada año. Las prendas anteriores a este
    /// campo pueden tener más usos (`wearCount`) que fechas.
    var wearDates: [Date] = []
    var createdAt: Date = Date.now

    /// Precio de compra, en la moneda del usuario.
    var price: Double?
    var purchasedAt: Date?
    /// Instrucciones de lavado (`CareInstruction`).
    var careRaw: [String] = []

    init(name: String = "", category: GarmentCategory = .tShirt, size: String = "", colors: [GarmentColor] = []) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.size = size
        self.colorsRaw = colors.map(\.rawValue)
    }

    var category: GarmentCategory {
        get { GarmentCategory(rawValue: categoryRaw) ?? .tShirt }
        set { categoryRaw = newValue.rawValue }
    }

    var colors: [GarmentColor] {
        get { colorsRaw.compactMap(GarmentColor.init(rawValue:)) }
        set { colorsRaw = newValue.map(\.rawValue) }
    }

    var season: Season {
        get { Season(rawValue: seasonRaw) ?? .allYear }
        set { seasonRaw = newValue.rawValue }
    }

    var status: GarmentStatus {
        get { GarmentStatus(rawValue: statusRaw) ?? .stored }
        set { statusRaw = newValue.rawValue }
    }

    var primaryColor: GarmentColor { colors.first ?? .gray }

    var care: [CareInstruction] {
        get { CareInstruction.sorted(careRaw.compactMap(CareInstruction.init(rawValue:))) }
        set { careRaw = CareInstruction.sorted(newValue).map(\.rawValue) }
    }

    /// Precio dividido entre las veces que te la has puesto (o el precio entero si aún no).
    var costPerWear: Double? {
        guard let price else { return nil }
        return price / Double(max(wearCount, 1))
    }

    /// El nombre que escribió el usuario o uno generado: «Camiseta blanca», «Jersey verde».
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Garment.generatedName(category: category, colors: colors) : trimmed
    }

    static func generatedName(category: GarmentCategory, colors: [GarmentColor]) -> String {
        guard let color = colors.first else { return category.singular }
        // El orden y la concordancia dependen del idioma: «Camiseta blanca», «White T-shirt».
        let noun = category.singular
        let adjective = color.adjective(feminine: category.isFeminine)
        return String(localized: "garment.generatedName", defaultValue: "\(noun) \(adjective)")
    }

    var locationPath: String { location?.path ?? String(localized: "Sin ubicación") }

    func measurement(_ measurement: GarmentMeasurement) -> Double? {
        switch measurement {
        case .chestWidth: chestWidthCm
        case .waistWidth: waistWidthCm
        case .length: lengthCm
        case .sleeve: sleeveCm
        case .inseam: inseamCm
        }
    }

    func setMeasurement(_ measurement: GarmentMeasurement, to value: Double?) {
        switch measurement {
        case .chestWidth: chestWidthCm = value
        case .waistWidth: waistWidthCm = value
        case .length: lengthCm = value
        case .sleeve: sleeveCm = value
        case .inseam: inseamCm = value
        }
    }

    var hasMeasurements: Bool { GarmentMeasurement.allCases.contains { measurement($0) != nil } }

    func markWorn(on date: Date = .now) {
        wearCount += 1
        lastWornAt = max(lastWornAt ?? date, date)
        wearDates.append(date)
    }
}
