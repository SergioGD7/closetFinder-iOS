import SwiftData
import SwiftUI

/// Crear o editar un look eligiendo una prenda para cada parte del cuerpo.
struct OutfitEditorView: View {
    private let outfit: Outfit?
    private let onSave: (Outfit) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var notes: String
    @State private var selected: [Garment]
    @State private var pickingSlot: OutfitSlot?

    init(outfit: Outfit? = nil, garments: [Garment] = [], onSave: @escaping (Outfit) -> Void = { _ in }) {
        self.outfit = outfit
        self.onSave = onSave
        _name = State(initialValue: outfit?.name ?? "")
        _notes = State(initialValue: outfit?.notes ?? "")
        _selected = State(initialValue: outfit?.pieces ?? garments)
    }

    private var sortedSelection: [Garment] { Outfit.sortedBySlot(selected) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    OutfitMosaic(garments: sortedSelection, cornerRadius: 24)
                        .frame(height: 240)
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity)
                        .animation(.snappy, value: selected.map(\.uuid))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    TextField("Nombre", text: $name, prompt: Text("Oficina, Fin de semana, Boda…"))
                }

                ForEach(OutfitSlot.allCases) { slot in
                    slotSection(slot)
                }

                Section("Notas") {
                    TextField("Para qué ocasión, con qué complementos…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(outfit == nil ? String(localized: "Nuevo look") : String(localized: "Editar look"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                        .disabled(selected.isEmpty)
                }
            }
            .sheet(item: $pickingSlot) { slot in
                GarmentPickerSheet(slot: slot, selected: selected) { add($0) }
            }
        }
    }

    private func slotSection(_ slot: OutfitSlot) -> some View {
        let pieces = sortedSelection.filter { OutfitSlot.slot(for: $0.category) == slot }
        return Section {
            ForEach(pieces) { garment in
                HStack {
                    GarmentRow(garment: garment)
                    Button {
                        withAnimation(.snappy) { remove(garment) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Quitar \(garment.displayName)"))
                }
            }
            if pieces.count < slot.maxItems {
                Button {
                    pickingSlot = slot
                } label: {
                    Label(pieces.isEmpty ? String(localized: "Elegir") : String(localized: "Añadir otra"),
                          systemImage: "plus.circle.fill")
                }
            } else if slot.maxItems == 1 {
                Button("Cambiar") { pickingSlot = slot }
            }
        } header: {
            OutfitSlotHeader(slot: slot, count: pieces.count)
        }
    }

    /// Añade la prenda (o la quita si ya estaba). Si la parte del cuerpo está llena, la nueva
    /// sustituye a la primera.
    private func add(_ garment: Garment) {
        withAnimation(.snappy) {
            if selected.contains(where: { $0 === garment }) {
                remove(garment)
                return
            }
            let slot = OutfitSlot.slot(for: garment.category)
            let inSlot = selected.filter { OutfitSlot.slot(for: $0.category) == slot }
            if inSlot.count >= slot.maxItems, let first = inSlot.first {
                remove(first)
            }
            selected.append(garment)
        }
    }

    private func remove(_ garment: Garment) {
        selected.removeAll { $0 === garment }
    }

    private func save() {
        let saved: Outfit
        if let outfit {
            saved = outfit
        } else {
            saved = Outfit()
            modelContext.insert(saved)
        }
        saved.name = name.trimmingCharacters(in: .whitespaces)
        saved.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.garments = selected
        try? modelContext.save()
        onSave(saved)
        dismiss()
    }
}

#Preview {
    OutfitEditorView()
        .modelContainer(AppModelContainer.preview())
}
