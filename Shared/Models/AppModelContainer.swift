import Foundation
import SwiftData

/// Almacén de datos compartido entre la app y el widget (a través de un App Group).
nonisolated enum AppModelContainer {
    static let appGroup = "group.com.sergiogonzalez.ClosetFinder"
    static let schema = Schema([Garment.self, StorageLocation.self, BodyProfile.self])

    /// `-inMemoryStore` arranca con un almacén vacío que no se guarda (útil para pruebas y capturas).
    static let isInMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    static let shared: ModelContainer = make(inMemory: isInMemory)

    /// El almacén vive en el contenedor del App Group para que el widget pueda leerlo. Si el
    /// App Group no está disponible (por ejemplo, en una compilación sin firmar), se usa la
    /// ubicación por defecto de SwiftData.
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "ClosetFinder.store")
    }

    static func make(inMemory: Bool) -> ModelContainer {
        // `cloudKitDatabase: .none` por ahora. Para sincronizar con iCloud basta con cambiarlo a
        // `.automatic` y añadir la capacidad iCloud + CloudKit al target: el modelo ya es compatible.
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let storeURL {
            migrateDefaultStore(to: storeURL)
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo abrir el almacén de datos: \(error)")
        }
    }

    /// Las versiones anteriores guardaban el almacén en `Application Support/default.store`.
    /// Si existe y el nuevo no, se copia (con sus ficheros `-shm` y `-wal`) al App Group.
    private static func migrateDefaultStore(to destination: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)),
              let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }
        let legacy = support.appending(path: "default.store")
        guard fileManager.fileExists(atPath: legacy.path(percentEncoded: false)) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(filePath: legacy.path(percentEncoded: false) + suffix)
            let target = URL(filePath: destination.path(percentEncoded: false) + suffix)
            try? fileManager.copyItem(at: source, to: target)
        }
    }

    /// Contenedor en memoria con datos de ejemplo, para las previews de SwiftUI.
    @MainActor
    static func preview() -> ModelContainer {
        let container = make(inMemory: true)
        SampleData.insert(into: container.mainContext)
        return container
    }
}
