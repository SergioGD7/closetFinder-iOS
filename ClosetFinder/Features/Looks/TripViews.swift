import SwiftData
import SwiftUI

/// Fila de una maleta: nombre, fechas y cuánto está ya hecho.
struct TripRow: View {
    let trip: Trip

    var body: some View {
        let total = trip.packingList.count
        let packed = trip.packedCount
        HStack(spacing: 12) {
            LocationIcon(kind: .suitcase, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(TripRow.dateText(trip))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if total > 0 {
                ZStack {
                    Circle().stroke(Color(.tertiarySystemFill), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: CGFloat(packed) / CGFloat(total))
                        .stroke(packed == total ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(packed)/\(total)")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                }
                .frame(width: 36, height: 36)
                .accessibilityLabel(String(localized: "\(packed) de \(total) prendas en la maleta"))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// «12–15 oct · 4 días»
    static func dateText(_ trip: Trip) -> String {
        let range = (trip.startDate..<max(trip.endDate, trip.startDate.addingTimeInterval(1)))
            .formatted(.interval.day().month(.abbreviated))
        let days = trip.dayCount == 1 ? String(localized: "1 día") : String(localized: "\(trip.dayCount) días")
        return "\(range) · \(days)"
    }
}

/// Lista de maletas: próximas y pasadas.
struct TripsListView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Binding var isCreating: Bool

    var body: some View {
        let upcoming = trips.filter(\.isUpcoming)
        let past = trips.filter { !$0.isUpcoming }.reversed()
        if trips.isEmpty {
            ContentUnavailableView {
                Label("Sin maletas", systemImage: "suitcase")
            } description: {
                Text("Crea una maleta para un viaje, añade los looks que quieres llevar y la app te dirá qué meter y dónde está cada prenda.")
            } actions: {
                Button("Nueva maleta") { isCreating = true }
                    .glassButtonStyle(prominent: true)
            }
        } else {
            List {
                if !upcoming.isEmpty {
                    Section("Próximas") {
                        ForEach(upcoming) { trip in
                            NavigationLink(value: trip) { TripRow(trip: trip) }
                        }
                    }
                }
                if !past.isEmpty {
                    Section("Pasadas") {
                        ForEach(Array(past)) { trip in
                            NavigationLink(value: trip) { TripRow(trip: trip) }
                        }
                    }
                }
            }
        }
    }
}

/// Crear o editar un viaje.
struct TripEditorView: View {
    private let trip: Trip?
    private let onSave: (Trip) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String

    init(trip: Trip? = nil, onSave: @escaping (Trip) -> Void = { _ in }) {
        self.trip = trip
        self.onSave = onSave
        let start = trip?.startDate ?? Calendar.current.startOfDay(for: .now.addingTimeInterval(7 * 86_400))
        _name = State(initialValue: trip?.name ?? "")
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: trip?.endDate ?? start.addingTimeInterval(2 * 86_400))
        _notes = State(initialValue: trip?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name, prompt: Text("Escapada a Lisboa"))
                }
                Section {
                    DatePicker("Salida", selection: $startDate, displayedComponents: .date)
                    DatePicker("Vuelta", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Notas") {
                    TextField("Tiempo previsto, planes, cosas que no olvidar…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue { endDate = newValue }
            }
            .navigationTitle(trip == nil ? String(localized: "Nueva maleta") : String(localized: "Editar maleta"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty ? String(localized: "Viaje") : trimmed
        let saved: Trip
        if let trip {
            saved = trip
            saved.name = finalName
            saved.startDate = startDate
            saved.endDate = endDate
        } else {
            saved = Trip(name: finalName, startDate: startDate, endDate: endDate)
            modelContext.insert(saved)
        }
        saved.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        onSave(saved)
        dismiss()
    }
}

/// Una maleta: looks, prendas sueltas y la lista de qué llevar agrupada por dónde está.
struct TripDetailView: View {
    @Bindable var trip: Trip

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isAddingOutfit = false
    @State private var isAddingGarment = false
    @State private var isConfirmingDelete = false
    @State private var packedFeedback = 0

    var body: some View {
        let list = trip.packingList
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(TripRow.dateText(trip))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !list.isEmpty {
                        ProgressView(value: Double(trip.packedCount), total: Double(list.count))
                            .tint(trip.packedCount == list.count ? .green : .accentColor)
                        Text(trip.packedCount == list.count
                             ? String(localized: "Maleta lista")
                             : String(localized: "\(trip.packedCount) de \(list.count) prendas en la maleta"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(trip.packedCount == list.count ? Color.green : Color.primary)
                    }
                    if !trip.notes.isEmpty {
                        Text(trip.notes).font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(trip.sortedOutfits) { outfit in
                    NavigationLink(value: outfit) { OutfitRow(outfit: outfit) }
                        .swipeActions {
                            Button("Quitar", role: .destructive) {
                                trip.outfits = (trip.outfits ?? []).filter { $0 !== outfit }
                            }
                        }
                }
                Button {
                    isAddingOutfit = true
                } label: {
                    Label("Añadir look", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Looks")
            } footer: {
                outfitHint
            }

            Section {
                ForEach(trip.extraGarments ?? []) { garment in
                    GarmentRow(garment: garment)
                        .swipeActions {
                            Button("Quitar", role: .destructive) {
                                trip.extraGarments = (trip.extraGarments ?? []).filter { $0 !== garment }
                            }
                        }
                }
                Button {
                    isAddingGarment = true
                } label: {
                    Label("Añadir prenda", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Prendas sueltas")
            } footer: {
                Text("Lo que no va en ningún look: pijama, bañador, una chaqueta de repuesto…")
            }

            if !list.isEmpty {
                Section {
                } header: {
                    Text("Qué llevar")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .textCase(nil)
                } footer: {
                    Text("Agrupado por dónde está guardada cada prenda, para recogerlo todo de una vez. Marca lo que ya está en la maleta.")
                }
            }

            ForEach(trip.packingListByLocation, id: \.place) { group in
                Section {
                    ForEach(group.garments) { garment in
                        packingRow(garment)
                    }
                } header: {
                    Label(group.place, systemImage: "mappin")
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { isEditing = true } label: { Label("Editar", systemImage: "pencil") }
                    Button { trip.packedGarmentIDs = [] } label: {
                        Label("Vaciar la maleta", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(trip.packedGarmentIDs.isEmpty)
                    Divider()
                    Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Eliminar", systemImage: "trash") }
                } label: {
                    Label("Más", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditing) { TripEditorView(trip: trip) }
        .sheet(isPresented: $isAddingOutfit) {
            OutfitPickerSheet(title: String(localized: "Añadir look"), excluding: trip.outfits ?? []) { outfit in
                trip.outfits = (trip.outfits ?? []) + [outfit]
            }
        }
        .sheet(isPresented: $isAddingGarment) {
            GarmentPickerSheet(selected: trip.extraGarments ?? []) { garment in
                if !(trip.extraGarments ?? []).contains(where: { $0 === garment }) {
                    trip.extraGarments = (trip.extraGarments ?? []) + [garment]
                }
            }
        }
        .confirmationDialog("¿Eliminar «\(trip.name)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Eliminar maleta", role: .destructive) {
                modelContext.delete(trip)
                dismiss()
            }
        } message: {
            Text("Los looks y las prendas no se borran.")
        }
        .sensoryFeedback(.selection, trigger: packedFeedback)
    }

    @ViewBuilder
    private var outfitHint: some View {
        let looks = trip.sortedOutfits.count
        if looks < trip.dayCount {
            Text("Son \(trip.dayCount) días y llevas \(looks) looks. Repite alguno o añade más.")
        } else {
            Text("Un look por día cubierto.")
        }
    }

    private func packingRow(_ garment: Garment) -> some View {
        let packed = trip.isPacked(garment)
        return Button {
            withAnimation(.snappy) { trip.togglePacked(garment) }
            packedFeedback += 1
        } label: {
            HStack(spacing: 12) {
                Image(systemName: packed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(packed ? Color.green : Color.secondary)
                GarmentImage(garment: garment, inset: 0.1)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(garment.displayName)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(packed)
                        .foregroundStyle(packed ? Color.secondary : Color.primary)
                    if garment.status != .stored {
                        Label(garment.status.title, systemImage: garment.status.symbol)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                if !garment.size.isEmpty { SizeBadge(size: garment.size) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(packed ? .isSelected : [])
        .accessibilityHint(packed ? String(localized: "Marcada como en la maleta") : String(localized: "Toca para marcarla como en la maleta"))
    }
}
