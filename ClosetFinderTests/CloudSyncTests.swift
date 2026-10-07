import CloudKit
import Foundation
import Testing
@testable import ClosetFinder

/// Primer arranque tras reinstalar y estado de la sincronización con iCloud.
struct CloudSyncTests {

    @Test func firstLaunchLooksForTheClosetInICloudFirst() {
        // Con datos en el dispositivo no hace falta nada.
        #expect(FirstLaunchDecision.decide(hasLocalData: true, syncsWithICloud: true, accountAvailable: true, cloudData: .absent) == .skip)
        // Hay armario en iCloud: se espera a que llegue.
        #expect(FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: true, accountAvailable: true, cloudData: .present)
                == .restore(patience: .seconds(90)))
        // Sin conexión no se sabe: se espera menos.
        #expect(FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: true, accountAvailable: true, cloudData: .unknown)
                == .restore(patience: .seconds(15)))
        // Usuario nuevo, sin cuenta de iCloud o compilación sin iCloud: bienvenida.
        #expect(FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: true, accountAvailable: true, cloudData: .absent) == .onboarding)
        #expect(FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: true, accountAvailable: false, cloudData: .present) == .onboarding)
        #expect(FirstLaunchDecision.decide(hasLocalData: false, syncsWithICloud: false, accountAvailable: true, cloudData: .present) == .onboarding)
    }

    @MainActor
    @Test func monitorTracksImportsExportsAndErrors() {
        let monitor = CloudSyncMonitor()
        let now = Date.now
        monitor.handle(.init(kind: .import, isFinished: false, succeeded: false, endDate: nil, errorDescription: nil))
        #expect(monitor.isImporting)
        #expect(monitor.finishedImports == 0)

        monitor.handle(.init(kind: .import, isFinished: true, succeeded: true, endDate: now, errorDescription: nil))
        #expect(!monitor.isImporting)
        #expect(monitor.finishedImports == 1)
        #expect(monitor.lastImport == now)

        // Una subida rechazada deja el error a la vista…
        monitor.handle(.init(kind: .export, isFinished: false, succeeded: false, endDate: nil, errorDescription: nil))
        #expect(monitor.isExporting)
        monitor.handle(.init(kind: .export, isFinished: true, succeeded: false, endDate: now,
                             errorDescription: "Cannot create or modify field 'CD_careRaw'"))
        #expect(!monitor.isExporting)
        #expect(monitor.lastError?.contains("CD_careRaw") == true)
        #expect(monitor.lastExport == nil)

        // …hasta que una sincronización sale bien.
        monitor.handle(.init(kind: .export, isFinished: true, succeeded: true, endDate: now, errorDescription: nil))
        #expect(monitor.lastError == nil)
        #expect(monitor.lastExport == now)
    }

    @Test func partialFailuresShowTheRecordError() {
        let recordError = NSError(domain: CKErrorDomain, code: CKError.Code.serverRejectedRequest.rawValue,
                                  userInfo: [NSLocalizedDescriptionKey: "Field 'CD_wearDates' is not in the production schema"])
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "a"): recordError]])
        #expect(CloudSyncMonitor.describe(partial).contains("CD_wearDates"))
        #expect(CloudSyncMonitor.describe(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sin red"])) == "Sin red")
    }
}
