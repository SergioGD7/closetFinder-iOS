import SwiftData
import SwiftUI

/// Selector de ubicación en forma de árbol. Llama a `onPick` y se cierra al elegir.
struct LocationPicker: View {
    let selection: StorageLocation?
    /// Ubicación que no se puede elegir junto con su contenido (para no meter un mueble dentro de sí mismo).
    var excluding: StorageLocation?
    var allowsNone = true
    let onPick: (StorageLocation?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\StorageLocation.sortIndex), SortDescriptor(\StorageLocation.name)])
    private var locations: [StorageLocation]

    @State private var searchText = ""
    @State private var editorTarget: LocationEditorTarget?

    private struct Entry: Identifiable {
        let location: StorageLocation
        let depth: Int
        var id: PersistentIdentifier { location.persistentModelID }
    }

    private var entries: [Entry] {
        func walk(_ location: StorageLocation, depth: Int) -> [Entry] {
            if let excluding, location === excluding { return [] }
            return [Entry(location: location, depth: depth)]
                + location.sortedChildren.flatMap { walk($0, depth: depth + 1) }
        }
        let all = locations.filter { $0.parent == nil }.flatMap { walk($0, depth: 0) }
        let query = GarmentSearch.tokenize(searchText)
        guard !query.isEmpty else { return all }
        return all
            .filter { entry in
                let words = entry.location.pathComponents.flatMap(GarmentSearch.tokenize)
                return query.allSatisfy { q in words.contains { $0.hasPrefix(q) } }
            }
            .map { Entry(location: $0.location, depth: 0) }
    }

    var body: some View {
        List {
            if allowsNone && searchText.isEmpty {
                row(title: "Sin ubicación", systemImage: "questionmark.folder", isSelected: selection == nil) {
                    pick(nil)
                }
            }
            ForEach(entries) { entry in
                Button {
                    pick(entry.location)
                } label: {
                    HStack(spacing: 12) {
                        LocationIcon(kind: entry.location.kind, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.location.name).foregroundStyle(.primary)
                            if !searchText.isEmpty, let parentPath = entry.location.parentPath {
                                Text(parentPath).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if entry.location === selection {
                            Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.leading, CGFloat(entry.depth) * 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.location.path)
                .accessibilityAddTraits(entry.location === selection ? .isSelected : [])
            }
        }
        .overlay {
            if locations.isEmpty {
                ContentUnavailableView {
                    Label("Sin ubicaciones", systemImage: "shippingbox")
                } description: {
                    Text("Crea una estancia para empezar a ordenar.")
                } actions: {
                    Button("Crear estancia") { editorTarget = .new(parent: nil) }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar ubicación")
        .navigationTitle("¿Dónde está?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorTarget = .new(parent: nil)
                } label: {
                    Label("Nueva estancia", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorTarget) { LocationEditorView(target: $0) }
    }

    private func row(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ location: StorageLocation?) {
        onPick(location)
        dismiss()
    }
}
