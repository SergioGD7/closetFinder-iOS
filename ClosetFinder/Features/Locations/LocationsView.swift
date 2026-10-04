import SwiftData
import SwiftUI

/// Estancias de la casa y sus muebles, con el número de prendas de cada uno.
struct LocationsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\StorageLocation.sortIndex), SortDescriptor(\StorageLocation.name)])
    private var locations: [StorageLocation]
    @Query private var garments: [Garment]

    @State private var editorTarget: LocationEditorTarget?
    @State private var roomToDelete: StorageLocation?
    @State private var isScanning = false

    private var rooms: [StorageLocation] { locations.filter { $0.parent == nil } }
    private var unassigned: [Garment] { garments.filter { $0.location == nil } }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.locationsPath) {
            Group {
                if rooms.isEmpty {
                    ContentUnavailableView {
                        Label("Aún no hay ubicaciones", systemImage: "shippingbox")
                    } description: {
                        Text("Empieza por las estancias donde guardas ropa: dormitorio, entrada, trastero…")
                    } actions: {
                        Button("Añadir estancia") { editorTarget = .new(parent: nil) }
                            .buttonStyle(.primary)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Ubicaciones")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if QRScannerView.isAvailable {
                        Button {
                            isScanning = true
                        } label: {
                            Label("Escanear etiqueta", systemImage: "qrcode.viewfinder")
                        }
                    }
                    Button {
                        editorTarget = .new(parent: nil)
                    } label: {
                        Label("Añadir estancia", systemImage: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $isScanning) { QRScannerSheet() }
            .appNavigationDestinations()
            .sheet(item: $editorTarget) { target in
                LocationEditorView(target: target)
            }
            .confirmationDialog(
                "¿Eliminar «\(roomToDelete?.name ?? "")»?",
                isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Eliminar estancia", role: .destructive) {
                    if let roomToDelete { modelContext.delete(roomToDelete) }
                    roomToDelete = nil
                }
            } message: {
                Text("Se eliminarán también sus muebles y compartimentos. Las prendas no se borran: quedarán sin ubicación.")
            }
        }
    }

    private var list: some View {
        List {
            Section {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            ForEach(rooms) { room in
                Section {
                    ForEach(room.sortedChildren) { child in
                        NavigationLink(value: child) {
                            LocationRow(location: child)
                        }
                    }
                    if room.directGarments.count > 0 || room.sortedChildren.isEmpty {
                        NavigationLink(value: room) {
                            Label(room.sortedChildren.isEmpty ? String(localized: "Ver \(room.name)") : String(localized: "Sueltas en \(room.name)"),
                                  systemImage: "tray.full")
                                .badge(room.directGarments.count)
                        }
                    }
                } header: {
                    roomHeader(room)
                }
            }

            if !unassigned.isEmpty {
                Section {
                    NavigationLink {
                        GarmentListView(title: String(localized: "Sin ubicación"), garments: unassigned)
                    } label: {
                        Label("Prendas sin ubicación", systemImage: "questionmark.folder")
                            .badge(unassigned.count)
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
    }

    private func roomHeader(_ room: StorageLocation) -> some View {
        HStack {
            Text(room.name)
            Text("\(room.totalGarmentCount)")
                .monospacedDigit()
                .foregroundStyle(.tertiary)
            Spacer()
            Menu {
                Button { editorTarget = .new(parent: room) } label: {
                    Label("Añadir mueble", systemImage: "plus")
                }
                Button { editorTarget = .edit(room) } label: {
                    Label("Renombrar", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) { roomToDelete = room } label: {
                    Label("Eliminar estancia", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .accessibilityLabel("Opciones de \(room.name)")
            }
        }
    }

    private var summary: String {
        let total = garments.count - unassigned.count
        let roomText = rooms.count == 1 ? String(localized: "1 estancia") : String(localized: "\(rooms.count) estancias")
        return total == 1 ? String(localized: "1 prenda en \(roomText)") : String(localized: "\(total) prendas en \(roomText)")
    }
}

/// Fila de ubicación: icono, nombre, contenido y número de prendas.
struct LocationRow: View {
    let location: StorageLocation
    var showsPath = false

    var body: some View {
        HStack(spacing: 12) {
            LocationIcon(kind: location.kind)
            VStack(alignment: .leading, spacing: 1) {
                Text(location.name)
                    .font(.body.weight(.medium))
                if showsPath, let parentPath = location.parentPath {
                    Text(parentPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let summary = location.contentsSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text("\(location.totalGarmentCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lista simple de prendas, usada para «Sin ubicación».
struct GarmentListView: View {
    let title: String
    let garments: [Garment]

    var body: some View {
        List(garments.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }) { garment in
            NavigationLink(value: garment) {
                GarmentRow(garment: garment)
            }
        }
        .navigationTitle(title)
    }
}

#Preview {
    LocationsView()
        .environment(AppRouter())
        .modelContainer(AppModelContainer.preview())
}
