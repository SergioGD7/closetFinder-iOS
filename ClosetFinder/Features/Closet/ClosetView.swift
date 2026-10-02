import SwiftData
import SwiftUI

enum ClosetSort: String, CaseIterable, Identifiable {
    case recent, name, mostWorn, leastWorn

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: "Añadidas recientemente"
        case .name: "Nombre"
        case .mostWorn: "Más usadas"
        case .leastWorn: "Menos usadas"
        }
    }

    func sorted(_ garments: [Garment]) -> [Garment] {
        switch self {
        case .recent: garments.sorted { $0.createdAt > $1.createdAt }
        case .name: garments.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .mostWorn: garments.sorted { $0.wearCount > $1.wearCount }
        case .leastWorn: garments.sorted { ($0.lastWornAt ?? .distantPast) < ($1.lastWornAt ?? .distantPast) }
        }
    }
}

struct ClosetView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @Query private var locations: [StorageLocation]

    @State private var category: GarmentCategory?
    @State private var sort: ClosetSort = .recent
    @State private var favoritesOnly = false
    @State private var isAdding = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.closetPath) {
            Group {
                if garments.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Armario")
            .toolbar { toolbar }
            .appNavigationDestinations()
            .sheet(isPresented: $isAdding) { GarmentEditorView() }
        }
    }

    // MARK: Contenido

    private var visibleGarments: [Garment] {
        sort.sorted(garments.filter { garment in
            (category == nil || garment.category == category) && (!favoritesOnly || garment.isFavorite)
        })
    }

    private var presentCategories: [GarmentCategory] {
        let present = Set(garments.map(\.category))
        return GarmentCategory.allCases.filter(present.contains)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Todo", isSelected: category == nil && !favoritesOnly) {
                            category = nil
                            favoritesOnly = false
                        }
                        FilterChip(title: "Favoritas", systemImage: "heart.fill", isSelected: favoritesOnly) {
                            favoritesOnly.toggle()
                        }
                        ForEach(presentCategories) { item in
                            FilterChip(title: item.title, isSelected: category == item) {
                                category = category == item ? nil : item
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .animation(.snappy, value: category)

                let visible = visibleGarments
                if visible.isEmpty {
                    ContentUnavailableView("Nada por aquí", systemImage: "line.3.horizontal.decrease",
                                           description: Text("Ninguna prenda cumple estos filtros."))
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visible) { garment in
                            NavigationLink(value: garment) {
                                GarmentCard(garment: garment)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { contextMenu(for: garment) }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var summary: String {
        let garmentText = garments.count == 1 ? "1 prenda" : "\(garments.count) prendas"
        let locationText = locations.count == 1 ? "1 ubicación" : "\(locations.count) ubicaciones"
        return "\(garmentText) · \(locationText)"
    }

    @ViewBuilder
    private func contextMenu(for garment: Garment) -> some View {
        Button {
            garment.isFavorite.toggle()
        } label: {
            Label(garment.isFavorite ? "Quitar de favoritas" : "Añadir a favoritas",
                  systemImage: garment.isFavorite ? "heart.slash" : "heart")
        }
        Button {
            garment.markWorn()
        } label: {
            Label("La he usado hoy", systemImage: "checkmark")
        }
        Divider()
        Button(role: .destructive) {
            SpotlightIndexer.remove([garment])
            modelContext.delete(garment)
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !garments.isEmpty {
                Menu {
                    Picker("Ordenar por", selection: $sort) {
                        ForEach(ClosetSort.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Solo favoritas", isOn: $favoritesOnly)
                } label: {
                    Label("Ordenar y filtrar", systemImage: "line.3.horizontal.decrease")
                }
            }
            Button {
                isAdding = true
            } label: {
                Label("Añadir prenda", systemImage: "plus")
            }
        }
    }

    // MARK: Vacío

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Tu armario está vacío", systemImage: "hanger")
        } description: {
            Text("Haz una foto a una prenda y di dónde la guardas. Así sabrás siempre dónde está.")
        } actions: {
            Button("Añadir prenda") { isAdding = true }
                .glassButtonStyle(prominent: true)
            if locations.isEmpty {
                Button("Probar con un armario de ejemplo") {
                    SampleData.insertIfEmpty(into: modelContext)
                    SpotlightIndexer.reindexAll(in: modelContext)
                }
            }
        }
    }
}

#Preview {
    ClosetView()
        .environment(AppRouter())
        .modelContainer(AppModelContainer.preview())
}
