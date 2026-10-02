import Foundation
import SwiftData

/// Almacén de datos compartido entre la app y el widget (a través de un App Group).
///
/// La app sincroniza el almacén con la base de datos privada de iCloud del usuario: si borra
/// la app y la vuelve a instalar con el mismo Apple ID, sus datos vuelven solos. El widget
/// solo lee el mismo fichero, sin sincronizar.
nonisolated enum AppModelContainer {
    static let appGroup = "group.com.sergiogonzalez.ClosetFinder"
    static let cloudKitContainer = "iCloud.com.sergiogonzalez.ClosetFinder"
    static let schema = Schema([Garment.self, StorageLocation.self, BodyProfile.self])

    /// `-inMemoryStore` arranca con un almacén vacío que no se guarda (útil para pruebas y capturas).
    static let isInMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    static var isAppExtension: Bool { Bundle.main.bundleURL.pathExtension == "appex" }

    private static let setup: (container: ModelContainer, syncsWithICloud: Bool) =
        open(inMemory: isInMemory, syncWithICloud: !isAppExtension)

    static var shared: ModelContainer { setup.container }

    /// `false` si el almacén se abrió solo en local (sin cuenta de desarrollador al compilar,
    /// en el widget o en memoria).
    static var syncsWithICloud: Bool { setup.syncsWithICloud }

    /// El almacén vive en el contenedor del App Group para que el widget pueda leerlo. Si el
    /// App Group no está disponible (por ejemplo, en una compilación sin firmar), se usa la
    /// ubicación por defecto de SwiftData.
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "ClosetFinder.store")
    }

    static func make(inMemory: Bool) -> ModelContainer {
        open(inMemory: inMemory, syncWithICloud: false).container
    }

    private static func open(inMemory: Bool, syncWithICloud: Bool) -> (container: ModelContainer, syncsWithICloud: Bool) {
        if inMemory {
            return (container(ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)), false)
        }
        if let storeURL { migrateDefaultStore(to: storeURL) }

        if syncWithICloud,
           let synced = try? ModelContainer(for: schema, configurations: [configuration(cloudKit: .private(cloudKitContainer))]) {
            return (synced, true)
        }
        return (container(configuration(cloudKit: .none)), false)
    }

    private static func configuration(cloudKit: ModelConfiguration.CloudKitDatabase) -> ModelConfiguration {
        if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKit)
        } else {
            ModelConfiguration(schema: schema, cloudKitDatabase: cloudKit)
        }
    }

    private static func container(_ configuration: ModelConfiguration) -> ModelContainer {
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
