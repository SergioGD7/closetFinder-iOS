import CoreSpotlight
import SwiftData
import SwiftUI
import WidgetKit

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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingOnboarding = false

    var body: some View {
        RootTabView()
            .preferredColorScheme(appearance.colorScheme)
            .task {
                if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
                    SampleData.insertIfEmpty(into: modelContext)
                }
                SpotlightIndexer.reindexAll(in: modelContext)
                decideOnboarding()
                #if DEBUG
                applyDebugLaunchArguments()
                #endif
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    isShowingOnboarding = false
                }
                .preferredColorScheme(appearance.colorScheme)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                router.openGarment(withID: id, in: modelContext)
            }
            .onOpenURL { url in
                if let link = DeepLink(url: url) { router.open(link, in: modelContext) }
            }
            .onChange(of: scenePhase) { _, phase in
                // El widget lee el mismo almacén: al salir de la app se refresca con los cambios.
                if phase == .background {
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
    }

    /// El primer arranque guiado sale una sola vez, y solo si el armario está vacío: quien ya
    /// tiene datos (de una versión anterior o de iCloud) no lo ve. `-showOnboarding` lo fuerza.
    private func decideOnboarding() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-showOnboarding") {
            isShowingOnboarding = true
            return
        }
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !hasCompletedOnboarding, !isTesting, !arguments.contains("-skipOnboarding") else { return }
        let garments = (try? modelContext.fetchCount(FetchDescriptor<Garment>())) ?? 0
        let locations = (try? modelContext.fetchCount(FetchDescriptor<StorageLocation>())) ?? 0
        if garments + locations > 0 {
            hasCompletedOnboarding = true
        } else {
            isShowingOnboarding = true
        }
    }

    #if DEBUG
    /// Abre una pantalla concreta al arrancar, para capturas y pruebas manuales:
    /// `-openTab looks|week|trips|locations|profile|search|stats|value|year`, `-openGarment "Chaqueta vaquera"`,
    /// `-openLocation "Armario grande"`, `-openOutfit "Oficina"` o `-openTrip "Escapada a la sierra"`.
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
        case "stats": router.closetPath.append(ClosetRoute.stats)
        case "value": router.closetPath.append(ClosetRoute.stats); router.closetPath.append(ClosetRoute.value)
        case "year": router.closetPath.append(ClosetRoute.stats); router.closetPath.append(ClosetRoute.yearInReview)
        case "looks": router.selectedTab = .looks
        case "outfits": router.selectedTab = .looks; router.looksSection = .outfits
        case "week": router.selectedTab = .looks; router.looksSection = .week
        case "trips": router.selectedTab = .looks; router.looksSection = .trips
        default: break
        }
        // `-samplePhotos`: las prendas sin foto reciben su ilustración como foto recortada,
        // para probar el probador 3D y las texturas sin tener fotos reales.
        if arguments.contains("-samplePhotos"),
           let garments = try? modelContext.fetch(FetchDescriptor<Garment>()) {
            for garment in garments where garment.photo == nil {
                let renderer = ImageRenderer(content: GarmentArtwork(category: garment.category, color: garment.primaryColor)
                    .frame(width: 600, height: 600))
                renderer.scale = 1
                guard let png = renderer.uiImage?.pngData() else { continue }
                garment.photo = png
                garment.thumbnail = png
                garment.hasCutout = true
                garment.imageRevision += 1
            }
        }
        if let name = value(after: "-openOutfit"),
           let outfit = try? modelContext.fetch(FetchDescriptor<Outfit>()).first(where: { $0.name == name }) {
            router.open(outfit)
        }
        if let name = value(after: "-openTrip"),
           let trip = try? modelContext.fetch(FetchDescriptor<Trip>()).first(where: { $0.name == name }) {
            router.open(trip)
        }
        if let name = value(after: "-openLocation"),
           let location = try? modelContext.fetch(FetchDescriptor<StorageLocation>()).first(where: { $0.name == name }) {
            router.open(location)
        }
        if let name = value(after: "-openGarment"),
           let garment = try? modelContext.fetch(FetchDescriptor<Garment>()).first(where: { $0.name == name }) {
            router.open(garment)
        }
    }
    #endif
}
