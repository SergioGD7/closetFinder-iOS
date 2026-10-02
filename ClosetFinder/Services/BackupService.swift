import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Fichero `.closetfinder`, declarado en el Info.plist de la app.
    nonisolated static let closetFinderBackup = UTType(exportedAs: "com.sergiogonzalez.closetfinder.backup")
}

/// Copia de seguridad completa (ubicaciones, personas, prendas y fotos) en un solo fichero.
/// Para quien no usa iCloud, o para guardar una copia aparte en Archivos o en el ordenador.
nonisolated struct BackupArchive: Codable, Sendable {
    static let currentVersion = 1

    var version = BackupArchive.currentVersion
    var createdAt = Date.now
    var locations: [LocationRecord] = []
    var profiles: [ProfileRecord] = []
    var garments: [GarmentRecord] = []

    struct LocationRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var kind: String
        var sortIndex: Int
        var createdAt: Date
        var parentID: UUID?
    }

    struct ProfileRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var sizing: String
        var heightCm, chestCm, waistCm, hipCm, inseamCm, footCm: Double?
        var createdAt: Date
    }

    struct GarmentRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var category: String
        var size: String
        var colors: [String]
        var season: String
        var status: String
        var brand: String
        var material: String
        var notes: String
        var photo: Data?
        var thumbnail: Data?
        var hasCutout: Bool
        var chestWidthCm, waistWidthCm, lengthCm, sleeveCm, inseamCm: Double?
        var isFavorite: Bool
        var wearCount: Int
        var lastWornAt: Date?
        var createdAt: Date
        var locationID: UUID?
        var ownerID: UUID?
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary // las fotos van como datos binarios, sin base64
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        try PropertyListDecoder().decode(BackupArchive.self, from: data)
    }
}

enum BackupService {

    struct RestoreSummary: Equatable {
        var garments = 0
        var locations = 0
        var profiles = 0
        var skipped = 0
    }

    enum BackupError: LocalizedError {
        case newerVersion

        var errorDescription: String? {
            switch self {
            case .newerVersion: "Esta copia se hizo con una versión más nueva de Closet Finder. Actualiza la app para restaurarla."
            }
        }
    }

    static func makeArchive(from context: ModelContext) throws -> BackupArchive {
        var archive = BackupArchive()
        archive.locations = try context.fetch(FetchDescriptor<StorageLocation>()).map {
            .init(id: $0.uuid, name: $0.name, kind: $0.kindRaw, sortIndex: $0.sortIndex,
                  createdAt: $0.createdAt, parentID: $0.parent?.uuid)
        }
        archive.profiles = try context.fetch(FetchDescriptor<BodyProfile>()).map {
            .init(id: $0.uuid, name: $0.name, sizing: $0.sizingRaw, heightCm: $0.heightCm, chestCm: $0.chestCm,
                  waistCm: $0.waistCm, hipCm: $0.hipCm, inseamCm: $0.inseamCm, footCm: $0.footCm, createdAt: $0.createdAt)
        }
        archive.garments = try context.fetch(FetchDescriptor<Garment>()).map {
            .init(id: $0.uuid, name: $0.name, category: $0.categoryRaw, size: $0.size, colors: $0.colorsRaw,
                  season: $0.seasonRaw, status: $0.statusRaw, brand: $0.brand, material: $0.material, notes: $0.notes,
                  photo: $0.photo, thumbnail: $0.thumbnail, hasCutout: $0.hasCutout,
                  chestWidthCm: $0.chestWidthCm, waistWidthCm: $0.waistWidthCm, lengthCm: $0.lengthCm,
                  sleeveCm: $0.sleeveCm, inseamCm: $0.inseamCm, isFavorite: $0.isFavorite, wearCount: $0.wearCount,
                  lastWornAt: $0.lastWornAt, createdAt: $0.createdAt, locationID: $0.location?.uuid, ownerID: $0.owner?.uuid)
        }
        return archive
    }

    /// Añade lo que hay en la copia sin duplicar: lo que ya existe (mismo identificador) se deja
    /// como está. Así se puede restaurar encima de un armario a medias sin perder nada.
    @discardableResult
    static func restore(_ archive: BackupArchive, into context: ModelContext) throws -> RestoreSummary {
        guard archive.version <= BackupArchive.currentVersion else { throw BackupError.newerVersion }
        var summary = RestoreSummary()

        var locations = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StorageLocation>()).map { ($0.uuid, $0) })
        var newLocations: [BackupArchive.LocationRecord] = []
        for record in archive.locations {
            guard locations[record.id] == nil else { summary.skipped += 1; continue }
            let location = StorageLocation(name: record.name, kind: LocationKind(rawValue: record.kind) ?? .other, sortIndex: record.sortIndex)
            context.insert(location)
            location.uuid = record.id
            location.createdAt = record.createdAt
            locations[record.id] = location
            newLocations.append(record)
            summary.locations += 1
        }
        // Los padres se enlazan cuando ya existen todas las ubicaciones.
        for record in newLocations {
            locations[record.id]?.parent = record.parentID.flatMap { locations[$0] }
        }

        var profiles = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<BodyProfile>()).map { ($0.uuid, $0) })
        for record in archive.profiles {
            guard profiles[record.id] == nil else { summary.skipped += 1; continue }
            let profile = BodyProfile(name: record.name, sizing: SizingProfile(rawValue: record.sizing) ?? .menswear)
            context.insert(profile)
            profile.uuid = record.id
            profile.heightCm = record.heightCm
            profile.chestCm = record.chestCm
            profile.waistCm = record.waistCm
            profile.hipCm = record.hipCm
            profile.inseamCm = record.inseamCm
            profile.footCm = record.footCm
            profile.createdAt = record.createdAt
            profiles[record.id] = profile
            summary.profiles += 1
        }

        let existingGarments = Set(try context.fetch(FetchDescriptor<Garment>()).map(\.uuid))
        for record in archive.garments {
            guard !existingGarments.contains(record.id) else { summary.skipped += 1; continue }
            let garment = Garment()
            context.insert(garment)
            garment.uuid = record.id
            garment.name = record.name
            garment.categoryRaw = record.category
            garment.size = record.size
            garment.colorsRaw = record.colors
            garment.seasonRaw = record.season
            garment.statusRaw = record.status
            garment.brand = record.brand
            garment.material = record.material
            garment.notes = record.notes
            garment.photo = record.photo
            garment.thumbnail = record.thumbnail
            garment.hasCutout = record.hasCutout
            garment.chestWidthCm = record.chestWidthCm
            garment.waistWidthCm = record.waistWidthCm
            garment.lengthCm = record.lengthCm
            garment.sleeveCm = record.sleeveCm
            garment.inseamCm = record.inseamCm
            garment.isFavorite = record.isFavorite
            garment.wearCount = record.wearCount
            garment.lastWornAt = record.lastWornAt
            garment.createdAt = record.createdAt
            garment.location = record.locationID.flatMap { locations[$0] }
            garment.owner = record.ownerID.flatMap { profiles[$0] }
            summary.garments += 1
        }
        try context.save()
        return summary
    }

    static func suggestedFilename(on date: Date = .now) -> String {
        "Closet Finder \(date.formatted(.iso8601.year().month().day()))"
    }
}

/// Envoltorio para `fileExporter`.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.closetFinderBackup]

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
