import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

/// Lo que ha pasado con la sincronización de iCloud: importaciones (bajar cambios), exportaciones
/// (subirlos) y errores. SwiftData sincroniza con `NSPersistentCloudKitContainer`, que avisa de
/// cada paso con `eventChangedNotification`; aquí se escuchan para enseñarlo en Ajustes y para
/// saber, al reinstalar, cuándo ha terminado de llegar el armario.
@Observable
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()

    enum Kind: Sendable {
        case setup, `import`, export
    }

    /// Lo que interesa de un evento, sin el objeto de Core Data (que no es `Sendable`).
    struct Event: Sendable {
        let kind: Kind
        let isFinished: Bool
        let succeeded: Bool
        let endDate: Date?
        let errorDescription: String?
    }

    private(set) var isImporting = false
    private(set) var isExporting = false
    private(set) var lastImport: Date?
    private(set) var lastExport: Date?
    /// Último error al subir o bajar cambios. Se borra en cuanto una sincronización sale bien.
    private(set) var lastError: String?
    /// Cuántas importaciones han terminado desde que arrancó la app.
    private(set) var finishedImports = 0

    private var observer: NSObjectProtocol?

    /// Empieza a escuchar. Hay que llamarlo antes de abrir el almacén para no perder la primera
    /// importación, que en una reinstalación es la que trae el armario.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { notification in
            guard let event = Self.event(from: notification) else { return }
            MainActor.assumeIsolated { CloudSyncMonitor.shared.handle(event) }
        }
    }

    nonisolated static func event(from notification: Notification) -> Event? {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return nil }
        let kind: Kind = switch event.type {
        case .import: .import
        case .export: .export
        default: .setup
        }
        return Event(kind: kind, isFinished: event.endDate != nil, succeeded: event.succeeded,
                     endDate: event.endDate, errorDescription: event.error.map(describe))
    }

    func handle(_ event: Event) {
        switch event.kind {
        case .import: isImporting = !event.isFinished
        case .export: isExporting = !event.isFinished
        case .setup: break
        }
        guard event.isFinished else { return }
        if event.succeeded {
            if event.kind == .import {
                lastImport = event.endDate ?? .now
                finishedImports += 1
            }
            if event.kind == .export { lastExport = event.endDate ?? .now }
            lastError = nil
        } else {
            if event.kind == .import { finishedImports += 1 }
            lastError = event.errorDescription ?? String(localized: "Error desconocido de iCloud")
        }
    }

    /// El texto de un error de CloudKit, con el detalle de cada registro si falló solo una parte.
    nonisolated static func describe(_ error: Error) -> String {
        if let ckError = error as? CKError, ckError.code == .partialFailure,
           let first = ckError.partialErrorsByItemID?.values.first {
            return (first as NSError).localizedDescription
        }
        return (error as NSError).localizedDescription
    }
}

/// Qué hacer en el primer arranque tras instalar (o reinstalar) la app.
nonisolated enum FirstLaunchDecision: Equatable, Sendable {
    /// Ya hay datos en el dispositivo: no hace falta nada.
    case skip
    /// Hay armario en iCloud: esperar a que llegue antes de nada.
    case restore(patience: Duration)
    /// No hay nada que recuperar: primer arranque guiado.
    case onboarding

    enum CloudData: Sendable {
        case present, absent, unknown
    }

    static func decide(hasLocalData: Bool, syncsWithICloud: Bool, accountAvailable: Bool,
                       cloudData: CloudData) -> FirstLaunchDecision {
        if hasLocalData { return .skip }
        guard syncsWithICloud, accountAvailable else { return .onboarding }
        switch cloudData {
        case .present: return .restore(patience: .seconds(90))
        // Sin conexión no se sabe: se espera un poco por si llega algo.
        case .unknown: return .restore(patience: .seconds(15))
        case .absent: return .onboarding
        }
    }
}

/// Consultas directas a iCloud, sin pasar por SwiftData.
nonisolated enum ICloudLookup {
    /// Zona donde SwiftData (Core Data) guarda los registros en la base de datos privada.
    static let zoneName = "com.apple.coredata.cloudkit.zone"

    static func accountAvailable() async -> Bool {
        (try? await CKContainer(identifier: AppModelContainer.cloudKitContainer).accountStatus()) == .available
    }

    /// Si la base de datos privada tiene la zona de la app: el usuario ya guardó datos alguna vez.
    static func cloudData() async -> FirstLaunchDecision.CloudData {
        do {
            let zones = try await CKContainer(identifier: AppModelContainer.cloudKitContainer)
                .privateCloudDatabase.allRecordZones()
            return zones.contains { $0.zoneID.zoneName == zoneName } ? .present : .absent
        } catch {
            return .unknown
        }
    }
}

#if DEBUG
/// Crea en el entorno de desarrollo de CloudKit todos los tipos de registro y todos los campos del
/// modelo, también los que todavía no tiene ninguna prenda (precio, cuidados…). Sin esto, el
/// esquema que se despliega a producción puede quedarse sin campos y iCloud rechaza los cambios.
///
/// Se lanza con `-initializeCloudKitSchema` desde Xcode en un dispositivo con iCloud; después hay
/// que desplegar el esquema a producción en CloudKit Console.
enum CloudKitSchemaInitializer {
    static func run() {
        let url = FileManager.default.temporaryDirectory.appending(path: "CloudKitSchema-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: AppModelContainer.cloudKitContainer)
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        guard let model = NSManagedObjectModel.makeManagedObjectModel(
            for: [Garment.self, StorageLocation.self, BodyProfile.self, Outfit.self, OutfitPlan.self, Trip.self]) else {
            print("[CloudKit] No se pudo crear el modelo de Core Data")
            return
        }
        let container = NSPersistentCloudKitContainer(name: "ClosetFinderSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("[CloudKit] No se pudo abrir el almacén temporal: \(loadError)")
            return
        }
        do {
            try container.initializeCloudKitSchema()
            print("[CloudKit] Esquema creado en desarrollo. Despliégalo a producción en CloudKit Console.")
        } catch {
            print("[CloudKit] Error al crear el esquema: \(error)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
