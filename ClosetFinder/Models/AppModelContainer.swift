import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([Garment.self, StorageLocation.self, BodyProfile.self])

    /// `-inMemoryStore` arranca con un almacén vacío que no se guarda (útil para pruebas y capturas).
    static let isInMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    static let shared: ModelContainer = make(inMemory: isInMemory)

    static func make(inMemory: Bool) -> ModelContainer {
        // `cloudKitDatabase: .none` por ahora. Para sincronizar con iCloud basta con cambiarlo a
        // `.automatic` y añadir la capacidad iCloud + CloudKit al target: el modelo ya es compatible.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo abrir el almacén de datos: \(error)")
        }
    }

    /// Contenedor en memoria con datos de ejemplo, para las previews de SwiftUI.
    static func preview() -> ModelContainer {
        let container = make(inMemory: true)
        SampleData.insert(into: container.mainContext)
        return container
    }
}
