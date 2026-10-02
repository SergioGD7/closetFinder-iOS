import SwiftData
import SwiftUI

enum ProfileEditorTarget: Identifiable {
    case new
    case edit(BodyProfile)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let profile): profile.uuid.uuidString
        }
    }
}

struct ProfileEditorView: View {
    let target: ProfileEditorTarget
    var onSave: (BodyProfile) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sizing: SizingProfile = .menswear
    @State private var values: [BodyMeasurement: String] = [:]
    @State private var isConfirmingDelete = false

    init(target: ProfileEditorTarget, onSave: @escaping (BodyProfile) -> Void = { _ in }) {
        self.target = target
        self.onSave = onSave
        if case .edit(let profile) = target {
            _name = State(initialValue: profile.name)
            _sizing = State(initialValue: profile.sizing)
            var initial: [BodyMeasurement: String] = [:]
            for measurement in BodyMeasurement.allCases {
                if let value = profile.value(of: measurement) { initial[measurement] = SizeConverter.format(value) }
            }
            _values = State(initialValue: initial)
        }
    }

    private var editing: BodyProfile? {
        if case .edit(let profile) = target { return profile }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name, prompt: Text("Yo, Lucía, Pablo…"))
                    Picker("Tallas", selection: $sizing) {
                        ForEach(SizingProfile.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    ForEach(BodyMeasurement.allCases) { measurement in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(measurement.title)
                                Spacer()
                                TextField("—", text: Binding(
                                    get: { values[measurement] ?? "" },
                                    set: { values[measurement] = $0 }))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 70)
                                Text("cm").foregroundStyle(.secondary)
                            }
                            Text(measurement.howTo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Medidas en centímetros")
                } footer: {
                    Text("Usa una cinta métrica flexible y no aprietes. Todas son opcionales.")
                }

                if editing != nil {
                    Section {
                        Button("Eliminar persona", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? String(localized: "Nueva persona") : String(localized: "Editar medidas"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                }
            }
            .confirmationDialog("¿Eliminar a «\(name)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let editing { modelContext.delete(editing) }
                    dismiss()
                }
            } message: {
                Text("Sus prendas no se borran; solo dejarán de estar asignadas a esta persona.")
            }
        }
    }

    private func save() {
        let profile: BodyProfile
        if let editing {
            profile = editing
        } else {
            profile = BodyProfile(name: "")
            modelContext.insert(profile)
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        profile.name = trimmed.isEmpty ? String(localized: "Yo") : trimmed
        profile.sizing = sizing
        for measurement in BodyMeasurement.allCases {
            profile.setValue(GarmentEditorModel.parseCentimeters(values[measurement]), of: measurement)
        }
        try? modelContext.save()
        onSave(profile)
        dismiss()
    }
}
