import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case closet, locations, profile, search
}

/// Estado de navegación compartido: pestaña activa y pila del Armario (para abrir una prenda
/// desde Spotlight o Siri).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .closet
    var closetPath = NavigationPath()

    func open(_ garment: Garment) {
        selectedTab = .closet
        var path = NavigationPath()
        path.append(garment)
        closetPath = path
    }

    func openGarment(withID id: String, in context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        var descriptor = FetchDescriptor<Garment>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard let garment = try? context.fetch(descriptor).first else { return }
        open(garment)
    }
}

extension View {
    /// Destinos de navegación comunes a todas las pestañas.
    func appNavigationDestinations() -> some View {
        self
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .navigationDestination(for: StorageLocation.self) { LocationDetailView(location: $0) }
    }
}
