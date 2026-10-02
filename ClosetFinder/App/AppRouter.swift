import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case closet, looks, locations, profile, search
}

/// Estado de navegación compartido: pestaña activa y pilas de navegación, para abrir una
/// prenda o una ubicación desde Spotlight, Siri, el widget o una etiqueta QR.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .closet
    var closetPath = NavigationPath()
    var locationsPath = NavigationPath()
    var looksPath = NavigationPath()
    var looksSection: LooksSection = .outfits

    func open(_ garment: Garment) {
        selectedTab = .closet
        var path = NavigationPath()
        path.append(garment)
        closetPath = path
    }

    func open(_ location: StorageLocation) {
        selectedTab = .locations
        var path = NavigationPath()
        path.append(location)
        locationsPath = path
    }

    func open(_ outfit: Outfit) {
        selectedTab = .looks
        looksSection = .outfits
        var path = NavigationPath()
        path.append(outfit)
        looksPath = path
    }

    func open(_ trip: Trip) {
        selectedTab = .looks
        looksSection = .trips
        var path = NavigationPath()
        path.append(trip)
        looksPath = path
    }

    func openGarment(withID id: String, in context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        open(.garment(uuid), in: context)
    }

    /// Abre el destino del enlace. Devuelve `false` si la prenda o ubicación ya no existe.
    @discardableResult
    func open(_ link: DeepLink, in context: ModelContext) -> Bool {
        switch link {
        case .garment(let uuid):
            var descriptor = FetchDescriptor<Garment>(predicate: #Predicate { $0.uuid == uuid })
            descriptor.fetchLimit = 1
            guard let garment = try? context.fetch(descriptor).first else { return false }
            open(garment)
        case .location(let uuid):
            var descriptor = FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.uuid == uuid })
            descriptor.fetchLimit = 1
            guard let location = try? context.fetch(descriptor).first else { return false }
            open(location)
        }
        return true
    }
}

extension View {
    /// Destinos de navegación comunes a todas las pestañas.
    func appNavigationDestinations() -> some View {
        self
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .navigationDestination(for: StorageLocation.self) { LocationDetailView(location: $0) }
            .navigationDestination(for: Outfit.self) { OutfitDetailView(outfit: $0) }
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
    }
}
