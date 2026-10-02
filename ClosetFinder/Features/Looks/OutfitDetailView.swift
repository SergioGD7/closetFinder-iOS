import SwiftData
import SwiftUI

/// Planificación de looks por día (uno por día).
enum OutfitScheduler {
    /// Asigna el look al día, sustituyendo el que hubiera.
    @discardableResult
    static func plan(_ outfit: Outfit, on day: Date, in context: ModelContext, calendar: Calendar = .current) -> OutfitPlan {
        let start = calendar.startOfDay(for: day)
        removePlans(on: start, in: context, calendar: calendar)
        let plan = OutfitPlan(day: start)
        context.insert(plan)
        plan.outfit = outfit
        return plan
    }

    static func removePlans(on day: Date, in context: ModelContext, calendar: Calendar = .current) {
        let plans = (try? context.fetch(FetchDescriptor<OutfitPlan>())) ?? []
        for plan in plans where calendar.isDate(plan.day, inSameDayAs: day) {
            context.delete(plan)
        }
    }
}

/// Un look: sus prendas, dónde está cada una y qué hacer con él.
struct OutfitDetailView: View {
    @Bindable var outfit: Outfit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var isPlanning = false
    @State private var isAddingToTrip = false
    @State private var isConfirmingDelete = false
    @State private var planDate = Date.now
    @State private var feedback = 0
    @State private var confirmation: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    OutfitMosaic(garments: outfit.pieces, cornerRadius: 26)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 460)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(outfit.displayName).font(.title2.bold())
                        Text(summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !outfit.notes.isEmpty {
                        Text(outfit.notes).font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            if !outfit.unavailablePieces.isEmpty {
                Section {
                    ForEach(outfit.unavailablePieces) { garment in
                        Label("\(garment.displayName): \(garment.status.title.lowercased())",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            Section {
                ForEach(outfit.pieces) { garment in
                    NavigationLink(value: garment) {
                        GarmentRow(garment: garment)
                    }
                }
            } header: {
                Text("Dónde está cada prenda")
            } footer: {
                Text("Toca una prenda para ver su sitio en el mueble.")
            }

            let trips = (outfit.trips ?? []).filter(\.isUpcoming)
            if !trips.isEmpty {
                Section("En la maleta de") {
                    ForEach(trips) { trip in
                        NavigationLink(value: trip) {
                            Label(trip.name, systemImage: "suitcase")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .overlay(alignment: .top) {
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassBackground(in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(outfit.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbar }
        .sheet(isPresented: $isEditing) { OutfitEditorView(outfit: outfit) }
        .sheet(isPresented: $isPlanning) { planSheet }
        .sheet(isPresented: $isAddingToTrip) {
            TripPickerSheet(excluding: outfit.trips ?? []) { trip in
                if !(trip.outfits ?? []).contains(where: { $0 === outfit }) {
                    trip.outfits = (trip.outfits ?? []) + [outfit]
                }
                show(String(localized: "Añadido a «\(trip.name)»"))
            }
        }
        .confirmationDialog("¿Eliminar «\(outfit.displayName)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Eliminar look", role: .destructive) {
                modelContext.delete(outfit)
                dismiss()
            }
        } message: {
            Text("Las prendas no se borran. El look desaparece de la semana y de las maletas.")
        }
        .sensoryFeedback(.success, trigger: feedback)
    }

    private var summary: String {
        let count = outfit.pieces.count
        var parts = [count == 1 ? String(localized: "1 prenda") : String(localized: "\(count) prendas")]
        if outfit.wearCount > 0 {
            parts.append(outfit.wearCount == 1 ? String(localized: "Puesto 1 vez") : String(localized: "Puesto \(outfit.wearCount) veces"))
        }
        return parts.joined(separator: " · ")
    }

    private var actionBar: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    planDate = .now
                    isPlanning = true
                } label: {
                    Label("Planificar", systemImage: "calendar").lineLimit(1).frame(maxWidth: .infinity)
                }
                .glassButtonStyle()

                Button {
                    outfit.markWorn()
                    OutfitScheduler.plan(outfit, on: .now, in: modelContext)
                    show(String(localized: "Anotado para hoy"))
                } label: {
                    Label("Llevar hoy", systemImage: "checkmark").lineLimit(1).frame(maxWidth: .infinity)
                }
                .glassButtonStyle(prominent: true)
            }
            .controlSize(.large)
            .fontWeight(.semibold)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var planSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Día", selection: $planDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("Planificar look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { isPlanning = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Planificar", systemImage: "checkmark") {
                        OutfitScheduler.plan(outfit, on: planDate, in: modelContext)
                        isPlanning = false
                        show(String(localized: "Planificado para el \(planDate.formatted(.dateTime.weekday(.wide).day().month()))"))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func show(_ message: String) {
        feedback += 1
        withAnimation(.snappy) { confirmation = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { confirmation = nil }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                outfit.isFavorite.toggle()
            } label: {
                Label(outfit.isFavorite ? String(localized: "Quitar de favoritos") : String(localized: "Añadir a favoritos"),
                      systemImage: outfit.isFavorite ? "heart.fill" : "heart")
            }
            .tint(outfit.isFavorite ? .pink : nil)

            Menu {
                Button { isEditing = true } label: { Label("Editar", systemImage: "pencil") }
                Button { isAddingToTrip = true } label: { Label("Añadir a una maleta", systemImage: "suitcase") }
                Divider()
                Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Eliminar", systemImage: "trash") }
            } label: {
                Label("Más", systemImage: "ellipsis")
            }
        }
    }
}

/// Elige una maleta o crea una nueva.
struct TripPickerSheet: View {
    var excluding: [Trip] = []
    let onPick: (Trip) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isCreating = true
                    } label: {
                        Label("Nueva maleta", systemImage: "plus.circle.fill")
                    }
                }
                Section {
                    ForEach(trips.filter { trip in trip.isUpcoming && !excluding.contains { $0 === trip } }) { trip in
                        Button {
                            onPick(trip)
                            dismiss()
                        } label: {
                            TripRow(trip: trip)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Añadir a una maleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $isCreating) {
                TripEditorView { trip in
                    onPick(trip)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let container = AppModelContainer.preview()
    let outfit = try! container.mainContext.fetch(FetchDescriptor<Outfit>()).first!
    return NavigationStack {
        OutfitDetailView(outfit: outfit)
            .appNavigationDestinations()
    }
    .modelContainer(container)
}
