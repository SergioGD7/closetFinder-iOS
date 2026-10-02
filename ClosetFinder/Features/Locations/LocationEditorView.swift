import SwiftData
import SwiftUI

enum LocationEditorTarget: Identifiable {
    case new(parent: StorageLocation?)
    case edit(StorageLocation)

    var id: String {
        switch self {
        case .new(let parent): "new-\(parent?.uuid.uuidString ?? "root")"
        case .edit(let location): "edit-\(location.uuid.uuidString)"
        }
    }
}

/// Crear o editar una ubicación. Al crear un mueble puede añadir sus compartimentos típicos.
struct LocationEditorView: View {
    let target: LocationEditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageLocation.sortIndex) private var allLocations: [StorageLocation]

    @State private var name = ""
    @State private var kind: LocationKind = .room
    @State private var addsCompartments = true
    @State private var parent: StorageLocation?
    @FocusState private var nameFocused: Bool

    init(target: LocationEditorTarget) {
        self.target = target
        switch target {
        case .new(let parent):
            _parent = State(initialValue: parent)
            _kind = State(initialValue: LocationKind.suggestedKinds(inside: parent).first ?? .room)
        case .edit(let location):
            _name = State(initialValue: location.name)
            _kind = State(initialValue: location.kind)
            _parent = State(initialValue: location.parent)
        }
    }

    private var editing: StorageLocation? {
        if case .edit(let location) = target { return location }
        return nil
    }

    private var kindOptions: [LocationKind] {
        var options = LocationKind.suggestedKinds(inside: parent)
        if !options.contains(kind) { options.insert(kind, at: 0) }
        return options
    }

    private var placeholder: String {
        switch kind {
        case .room: String(localized: "Dormitorio, Entrada, Trastero…")
        case .box: String(localized: "Caja «Invierno»")
        default: "\(kind.title) \(nextNumber)"
        }
    }

    private var nextNumber: Int {
        ((parent?.children ?? []).filter { $0.kind == kind }.count) + 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                    Picker("Tipo", selection: $kind) {
                        ForEach(kindOptions) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                }

                if editing == nil, let summary = kind.templateSummary {
                    Section {
                        Toggle(isOn: $addsCompartments) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Añadir compartimentos")
                                Text(summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text("Podrás renombrarlos, añadir más o borrarlos después.")
                    }
                }

                if editing != nil {
                    Section("Dentro de") {
                        NavigationLink {
                            LocationPicker(selection: parent, excluding: editing, allowsNone: true) { parent = $0 }
                        } label: {
                            Text(parent?.path ?? String(localized: "Ninguna (es una estancia)"))
                                .foregroundStyle(parent == nil ? Color.secondary : Color.primary)
                        }
                    }
                } else if let parent {
                    Section("Dentro de") {
                        Text(parent.path).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(editing == nil ? String(localized: "Nueva ubicación") : String(localized: "Editar ubicación"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                }
            }
            .onAppear { nameFocused = editing == nil }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty ? (kind == .room ? kind.title : "\(kind.title) \(nextNumber)") : trimmed

        if let editing {
            editing.name = finalName
            editing.kind = kind
            if editing.parent !== parent {
                editing.sortIndex = parent?.nextChildSortIndex ?? rootCount
                editing.parent = parent
            }
        } else {
            let location = StorageLocation(name: finalName, kind: kind, sortIndex: parent?.nextChildSortIndex ?? rootCount)
            modelContext.insert(location)
            location.parent = parent
            if addsCompartments {
                for (index, item) in kind.template.enumerated() {
                    let compartment = StorageLocation(name: item.name, kind: item.kind, sortIndex: index)
                    modelContext.insert(compartment)
                    compartment.parent = location
                }
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private var rootCount: Int { allLocations.filter { $0.parent == nil }.count }
}
