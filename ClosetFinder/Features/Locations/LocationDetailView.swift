import SwiftData
import SwiftUI

/// Un mueble, estancia o compartimento: qué contiene y qué prendas hay. Permite mover
/// varias prendas a la vez (por ejemplo, en el cambio de temporada).
struct LocationDetailView: View {
    @Bindable var location: StorageLocation

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editorTarget: LocationEditorTarget?
    @State private var isAddingGarment = false
    @State private var isConfirmingDelete = false
    @State private var isShowingLabel = false
    @State private var isSelecting = false
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var isMovingSelection = false
    @State private var movedFeedback = 0

    var body: some View {
        List {
            header
            if !location.sortedChildren.isEmpty {
                Section("Contiene") {
                    ForEach(location.sortedChildren) { child in
                        NavigationLink(value: child) {
                            LocationRow(location: child)
                        }
                        .disabled(isSelecting)
                    }
                }
            }
            garmentsSection
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { selectionBar }
        .sheet(item: $editorTarget) { LocationEditorView(target: $0) }
        .sheet(isPresented: $isAddingGarment) { GarmentEditorView(location: location) }
        .sheet(isPresented: $isShowingLabel) { QRLabelSheet(location: location) }
        .sheet(isPresented: $isMovingSelection) {
            NavigationStack {
                LocationPicker(selection: nil, allowsNone: false, onPick: moveSelection)
            }
        }
        .confirmationDialog("¿Eliminar «\(location.name)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                modelContext.delete(location)
                dismiss()
            }
        } message: {
            Text(location.children?.isEmpty == false
                 ? String(localized: "Se eliminará también todo lo que contiene. Las prendas quedarán sin ubicación.") : String(localized: "Las prendas que hay aquí quedarán sin ubicación."))
        }
        .sensoryFeedback(.success, trigger: movedFeedback)
    }

    // MARK: Cabecera

    private var header: some View {
        Section {
            HStack(spacing: 16) {
                if let furniture = location.schematicFurniture {
                    FurnitureSchematic(furniture: furniture, highlighted: furniture === location ? nil : location)
                        .frame(width: 96, height: 76)
                } else {
                    LocationIcon(kind: location.kind, size: 56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.kind.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.4)
                    Text(location.name)
                        .font(.title2.bold())
                    if let parentPath = location.parentPath {
                        Text(parentPath)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(location.totalGarmentCount == 1 ? String(localized: "1 prenda") : String(localized: "\(location.totalGarmentCount) prendas"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Prendas

    private var garments: [Garment] {
        location.allGarments.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    @ViewBuilder
    private var garmentsSection: some View {
        let garments = garments
        Section {
            if garments.isEmpty {
                Button {
                    isAddingGarment = true
                } label: {
                    Label("Añadir una prenda aquí", systemImage: "plus")
                }
            }
            ForEach(garments) { garment in
                let relativePath = relativePath(of: garment)
                if isSelecting {
                    Button {
                        toggleSelection(garment)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selection.contains(garment.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.contains(garment.persistentModelID) ? Color.accentColor : Color.secondary)
                            GarmentRow(garment: garment, locationText: relativePath)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: garment) {
                        GarmentRow(garment: garment, locationText: relativePath)
                    }
                }
            }
        } header: {
            HStack {
                Text("Prendas")
                Spacer()
                if !garments.isEmpty {
                    Button(isSelecting ? String(localized: "Listo") : String(localized: "Seleccionar")) {
                        withAnimation(.snappy) {
                            isSelecting.toggle()
                            selection.removeAll()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
    }

    /// Ruta de la prenda dentro de esta ubicación: «Balda 2», «Caja › Bolsa».
    private func relativePath(of garment: Garment) -> String {
        guard let garmentLocation = garment.location else { return String(localized: "Sin ubicación") }
        if garmentLocation === location { return String(localized: "Aquí") }
        let components = garmentLocation.pathComponents
        let ownDepth = location.pathComponents.count
        return components.dropFirst(ownDepth).joined(separator: " › ")
    }

    private func toggleSelection(_ garment: Garment) {
        let id = garment.persistentModelID
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func moveSelection(to destination: StorageLocation?) {
        let moving = garments.filter { selection.contains($0.persistentModelID) }
        for garment in moving { garment.location = destination }
        SpotlightIndexer.index(moving)
        selection.removeAll()
        isSelecting = false
        movedFeedback += 1
    }

    @ViewBuilder
    private var selectionBar: some View {
        if isSelecting {
            Button {
                isMovingSelection = true
            } label: {
                Label(selection.count == 1 ? String(localized: "Mover 1 prenda") : String(localized: "Mover \(selection.count) prendas"),
                      systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle(prominent: true)
            .controlSize(.large)
            .fontWeight(.semibold)
            .disabled(selection.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { isAddingGarment = true } label: { Label("Añadir prenda aquí", systemImage: "tshirt") }
                Button { editorTarget = .new(parent: location) } label: {
                    Label(location.kind == .room ? String(localized: "Añadir mueble") : String(localized: "Añadir compartimento"), systemImage: "plus.square")
                }
                Button { isShowingLabel = true } label: { Label("Etiqueta QR", systemImage: "qrcode") }
                Divider()
                Button { editorTarget = .edit(location) } label: { Label("Editar", systemImage: "pencil") }
                Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Eliminar", systemImage: "trash") }
            } label: {
                Label("Opciones", systemImage: "ellipsis")
            }
        }
    }
}

#Preview {
    let container = AppModelContainer.preview()
    let wardrobe = try! container.mainContext.fetch(FetchDescriptor<StorageLocation>()).first { $0.name == "Armario grande" }!
    return NavigationStack {
        LocationDetailView(location: wardrobe)
            .appNavigationDestinations()
    }
    .modelContainer(container)
}
