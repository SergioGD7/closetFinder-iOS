import CoreSpotlight
import SwiftData
import SwiftUI

@main
struct ClosetFinderApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
        .modelContainer(AppModelContainer.shared)
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RootTabView()
            .task {
                if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
                    SampleData.insertIfEmpty(into: modelContext)
                }
                SpotlightIndexer.reindexAll(in: modelContext)
                #if DEBUG
                applyDebugLaunchArguments()
                #endif
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                router.openGarment(withID: id, in: modelContext)
            }
    }

    #if DEBUG
    /// Abre una pantalla concreta al arrancar, para capturas y pruebas manuales:
    /// `-openTab locations|profile|search` o `-openGarment "Chaqueta vaquera"`.
    private func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        switch value(after: "-openTab") {
        case "locations": router.selectedTab = .locations
        case "profile": router.selectedTab = .profile
        case "search": router.selectedTab = .search
        default: break
        }
        if let name = value(after: "-openGarment"),
           let garment = try? modelContext.fetch(FetchDescriptor<Garment>()).first(where: { $0.name == name }) {
            router.open(garment)
        }
    }
    #endif
}
