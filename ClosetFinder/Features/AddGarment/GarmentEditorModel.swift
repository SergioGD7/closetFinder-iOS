import Foundation
import SwiftData

/// Borrador de una prenda mientras se crea o edita. Solo toca SwiftData al guardar.
@Observable
final class GarmentEditorModel {
    var name = ""
    var category: GarmentCategory = .tShirt
    var size = ""
    var colors: [GarmentColor] = []
    var season: Season = .allYear
    var status: GarmentStatus = .stored
    var brand = ""
    var material = ""
    var notes = ""
    var location: StorageLocation?
    var owner: BodyProfile?
    /// Texto tal y como lo escribe el usuario («54», «54,5»).
    var measurements: [GarmentMeasurement: String] = [:]

    var photo: Data?
    var thumbnail: Data?
    var hasCutout = false
    private var photoChanged = false

    var isProcessing = false
    var suggestedCategory: GarmentCategory?
    var detectedColors: [GarmentColor] = []
    /// Si el usuario ya eligió categoría o colores, las sugerencias no los pisan.
    var categoryWasChosen = false
    var colorsWereChosen = false

    var burstMode = false
    var burstCount = 0

    init(garment: Garment? = nil, location: StorageLocation? = nil, owner: BodyProfile? = nil) {
        if let garment {
            name = garment.name
            category = garment.category
            size = garment.size
            colors = garment.colors
            season = garment.season
            status = garment.status
            brand = garment.brand
            material = garment.material
            notes = garment.notes
            self.location = garment.location
            self.owner = garment.owner
            for measurement in GarmentMeasurement.allCases {
                if let value = garment.measurement(measurement) {
                    measurements[measurement] = SizeConverter.format(value)
                }
            }
            photo = garment.photo
            thumbnail = garment.thumbnail
            hasCutout = garment.hasCutout
            categoryWasChosen = true
            colorsWereChosen = !garment.colors.isEmpty
        } else {
            self.location = location
            self.owner = owner
        }
    }

    var generatedName: String { Garment.generatedName(category: category, colors: colors) }

    var hasPhoto: Bool { photo != nil }

    // MARK: Foto

    func processPhoto(_ data: Data) async {
        isProcessing = true
        defer { isProcessing = false }
        guard let result = await ImageProcessor.process(data) else { return }
        photo = result.photo
        thumbnail = result.thumbnail
        hasCutout = result.isCutout
        photoChanged = true

        detectedColors = result.colors
        if !colorsWereChosen, !result.colors.isEmpty { colors = result.colors }
        suggestedCategory = result.category
        if !categoryWasChosen, let detected = result.category { category = detected }
    }

    func removePhoto() {
        photo = nil
        thumbnail = nil
        hasCutout = false
        photoChanged = true
    }

    func toggleColor(_ color: GarmentColor) {
        colorsWereChosen = true
        if let index = colors.firstIndex(of: color) {
            colors.remove(at: index)
        } else {
            colors.append(color)
        }
    }

    // MARK: Guardar

    /// Crea o actualiza la prenda y la devuelve.
    @discardableResult
    func save(in context: ModelContext, editing existing: Garment?) -> Garment {
        let garment: Garment
        if let existing {
            garment = existing
        } else {
            garment = Garment()
            context.insert(garment)
        }
        garment.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        garment.category = category
        garment.size = size.trimmingCharacters(in: .whitespaces)
        garment.colors = colors
        garment.season = season
        garment.status = status
        garment.brand = brand.trimmingCharacters(in: .whitespaces)
        garment.material = material.trimmingCharacters(in: .whitespaces)
        garment.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        garment.location = location
        garment.owner = owner
        for measurement in GarmentMeasurement.allCases {
            garment.setMeasurement(measurement, to: Self.parseCentimeters(measurements[measurement]))
        }
        if photoChanged {
            garment.photo = photo
            garment.thumbnail = thumbnail
            garment.hasCutout = hasCutout
            garment.imageRevision += 1
        }
        return garment
    }

    /// Deja el formulario listo para la siguiente prenda de la ráfaga: conserva dónde se
    /// guarda, de quién es, la temporada y la categoría; borra todo lo demás.
    func prepareNextInBurst() {
        burstCount += 1
        name = ""
        size = ""
        colors = []
        brand = ""
        material = ""
        notes = ""
        measurements = [:]
        status = .stored
        photo = nil
        thumbnail = nil
        hasCutout = false
        photoChanged = false
        suggestedCategory = nil
        detectedColors = []
        categoryWasChosen = false
        colorsWereChosen = false
    }

    static func parseCentimeters(_ text: String?) -> Double? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }
}
