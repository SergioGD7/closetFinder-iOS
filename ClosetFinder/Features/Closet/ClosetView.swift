import SwiftData
import SwiftUI

/// Pantallas propias de la pestaña Armario.
enum ClosetRoute: Hashable {
    case stats
}

enum ClosetSort: String, CaseIterable, Identifiable {
    case recent, name, mostWorn, leastWorn

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: String(localized: "Más recientes")
        case .name: String(localized: "Nombre")
        case .mostWorn: String(localized: "Más usadas")
        case .leastWorn: String(localized: "Menos usadas")
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
    // Selección múltiple
    @State private var isSelecting = false
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var isConfirmingDelete = false
    @State private var isMovingSelection = false
    @State private var deleteFeedback = 0

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
            .navigationDestination(for: ClosetRoute.self) { route in
                switch route {
                case .stats: StatsView()
                }
            }
            .sheet(isPresented: $isAdding) { GarmentEditorView() }
            .safeAreaInset(edge: .bottom) { selectionBar }
            .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
            .confirmationDialog(
                selection.count == 1 ? String(localized: "¿Eliminar 1 prenda?") : String(localized: "¿Eliminar \(selection.count) prendas?"),
                isPresented: $isConfirmingDelete, titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive, action: deleteSelection)
            } message: {
                Text("Se borrarán con sus fotos y desaparecerán de los looks. No se puede deshacer.")
            }
            .sheet(isPresented: $isMovingSelection) {
                NavigationStack {
                    LocationPicker(selection: nil, allowsNone: true) { destination in
                        let moving = garments.filter { selection.contains($0.persistentModelID) }
                        for garment in moving { garment.location = destination }
                        SpotlightIndexer.index(moving)
                        endSelection()
                    }
                }
            }
            .sensoryFeedback(.success, trigger: deleteFeedback)
            #if DEBUG
            .task {
                // `-selecting` abre el Armario en modo selección con dos prendas marcadas (capturas).
                if ProcessInfo.processInfo.arguments.contains("-selecting") {
                    isSelecting = true
                    selection = Set(visibleGarments.prefix(2).map(\.persistentModelID))
                }
            }
            #endif
        }
    }

    // MARK: Selección múltiple

    @ViewBuilder
    private var selectionBar: some View {
        if isSelecting {
            HStack(spacing: 10) {
                Button {
                    isMovingSelection = true
                } label: {
                    Label("Mover", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(.floatingSecondary)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label(selection.isEmpty ? String(localized: "Eliminar") : String(localized: "Eliminar (\(selection.count))"),
                          systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DestructiveButtonStyle())
            }
            .disabled(selection.isEmpty)
            .frame(maxWidth: 560)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func toggle(_ garment: Garment) {
        let id = garment.persistentModelID
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func endSelection() {
        withAnimation(.spring(duration: 0.3, bounce: 0)) {
            isSelecting = false
            selection.removeAll()
        }
    }

    private func deleteSelection() {
        let deleting = garments.filter { selection.contains($0.persistentModelID) }
        SpotlightIndexer.remove(deleting)
        for garment in deleting { modelContext.delete(garment) }
        try? modelContext.save()
        deleteFeedback += 1
        endSelection()
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
                        FilterChip(title: String(localized: "Todo"), isSelected: category == nil && !favoritesOnly) {
                            category = nil
                            favoritesOnly = false
                        }
                        FilterChip(title: String(localized: "Favoritas"), systemImage: "heart.fill", isSelected: favoritesOnly) {
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
                            if isSelecting {
                                Button {
                                    toggle(garment)
                                } label: {
                                    GarmentCard(garment: garment)
                                        .overlay(alignment: .bottomTrailing) {
                                            SelectionMark(isSelected: selection.contains(garment.persistentModelID))
                                                .padding(10)
                                                .padding(.bottom, 44)
                                        }
                                        .opacity(selection.isEmpty || selection.contains(garment.persistentModelID) ? 1 : 0.75)
                                }
                                .buttonStyle(.pressable)
                                .accessibilityAddTraits(selection.contains(garment.persistentModelID) ? .isSelected : [])
                            } else {
                                NavigationLink(value: garment) {
                                    GarmentCard(garment: garment)
                                }
                                .buttonStyle(.pressable)
                                .contextMenu { contextMenu(for: garment) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var summary: String {
        let garmentText = garments.count == 1 ? String(localized: "1 prenda") : String(localized: "\(garments.count) prendas")
        let locationText = locations.count == 1 ? String(localized: "1 ubicación") : String(localized: "\(locations.count) ubicaciones")
        return "\(garmentText) · \(locationText)"
    }

    @ViewBuilder
    private func contextMenu(for garment: Garment) -> some View {
        Button {
            garment.isFavorite.toggle()
        } label: {
            Label(garment.isFavorite ? String(localized: "Quitar de favoritas") : String(localized: "Añadir a favoritas"),
                  systemImage: garment.isFavorite ? "heart.slash" : "heart")
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
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                let allSelected = selection.count == visibleGarments.count
                Button(allSelected ? String(localized: "Ninguna") : String(localized: "Todas")) {
                    selection = allSelected ? [] : Set(visibleGarments.map(\.persistentModelID))
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo", action: endSelection)
            }
        } else {
            closetToolbar
        }
    }

    @ToolbarContentBuilder
    private var closetToolbar: some ToolbarContent {
        if !garments.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: ClosetRoute.stats) {
                    Label("Estadísticas", systemImage: "chart.bar")
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !garments.isEmpty {
                Menu {
                    Picker("Ordenar por", selection: $sort) {
                        ForEach(ClosetSort.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Solo favoritas", isOn: $favoritesOnly)
                    Divider()
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0)) { isSelecting = true }
                    } label: {
                        Label("Seleccionar prendas", systemImage: "checkmark.circle")
                    }
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
                .buttonStyle(.primary)
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
