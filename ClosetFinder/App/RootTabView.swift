import SwiftData
import SwiftUI

/// En iOS 18+ usa la API `Tab` con la pestaña de búsqueda del sistema (que en iOS 26 se
/// convierte en el campo de cristal junto al pulgar). En iOS 17, pestañas clásicas.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        if #available(iOS 18.0, *) {
            TabView(selection: $router.selectedTab) {
                Tab("Armario", systemImage: "hanger", value: AppTab.closet) {
                    ClosetView()
                }
                Tab("Looks", systemImage: "tshirt", value: AppTab.looks) {
                    LooksView()
                }
                Tab("Ubicaciones", systemImage: "shippingbox", value: AppTab.locations) {
                    LocationsView()
                }
                Tab("Medidas", systemImage: "figure.stand", value: AppTab.profile) {
                    ProfileView()
                }
                Tab(value: AppTab.search, role: .search) {
                    SearchView()
                }
            }
            // En iPad, las pestañas se pueden convertir en barra lateral.
            .tabViewStyle(.sidebarAdaptable)
            .minimizingTabBarOnScroll()
        } else {
            TabView(selection: $router.selectedTab) {
                ClosetView()
                    .tabItem { Label("Armario", systemImage: "hanger") }
                    .tag(AppTab.closet)
                LooksView()
                    .tabItem { Label("Looks", systemImage: "tshirt") }
                    .tag(AppTab.looks)
                LocationsView()
                    .tabItem { Label("Ubicaciones", systemImage: "shippingbox") }
                    .tag(AppTab.locations)
                ProfileView()
                    .tabItem { Label("Medidas", systemImage: "figure.stand") }
                    .tag(AppTab.profile)
                SearchView()
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppRouter())
        .modelContainer(AppModelContainer.preview())
}
