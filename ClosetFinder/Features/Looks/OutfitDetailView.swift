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
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isPlanning = false
    @State private var isAddingToTrip = false
    @State private var isConfirmingDelete = false
    @State private var planDate = Date.now
    @State private var feedback = 0
    @State private var confirmation: String?
    @State private var shareImage: UIImage?

    /// Cambia cuando cambia lo que sale en la imagen para compartir.
    private var shareKey: String {
        outfit.displayName + outfit.pieces.map { "\($0.uuid)\($0.imageRevision)" }.joined()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    OutfitFigure(garments: outfit.pieces, spacing: 8)
                        .padding(24)
                        .frame(height: 440)
                        .frame(maxWidth: 460)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                FittingRoomView(mode: .sheet(outfit: outfit, preselected: []))
                    .navigationTitle("Probador")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert("Cambiar nombre", isPresented: $isRenaming) {
            TextField("Nombre", text: $newName)
            Button("Guardar") { outfit.name = newName.trimmingCharacters(in: .whitespaces) }
            Button("Cancelar", role: .cancel) {}
        }
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
        .task(id: shareKey) {
            shareImage = ShareImageRenderer.render(OutfitShareCard(outfit: outfit).padding(16), width: 360)
        }
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
                .buttonStyle(.floatingSecondary)

                Button {
                    outfit.markWorn()
                    OutfitScheduler.plan(outfit, on: .now, in: modelContext)
                    show(String(localized: "Anotado para hoy"))
                } label: {
                    Label("Llevar hoy", systemImage: "checkmark").lineLimit(1).frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
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

            if let shareImage, !outfit.pieces.isEmpty {
                ShareLink(item: Image(uiImage: shareImage),
                          preview: SharePreview(outfit.displayName, image: Image(uiImage: shareImage))) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
            }

            Menu {
                Button { isEditing = true } label: { Label("Cambiar prendas en el probador", systemImage: "tshirt") }
                Button {
                    newName = outfit.name
                    isRenaming = true
                } label: { Label("Cambiar nombre", systemImage: "pencil") }
                Button { isAddingToTrip = true } label: { Label("Añadir a una maleta", systemImage: "suitcase") }
                Divider()
                Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Eliminar", systemImage: "trash") }
            } label: {
                Label("Más", systemImage: "ellipsis")
            }
        }
    }
}

/// Imagen de un look para compartir: la figura vestida, el nombre y las prendas.
struct OutfitShareCard: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutfitFigure(garments: outfit.pieces, spacing: 6)
                .padding(20)
                .frame(height: 380)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(outfit.displayName)
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 4) {
                ForEach(outfit.pieces) { garment in
                    HStack(spacing: 8) {
                        ColorSwatch(color: garment.primaryColor, size: 12)
                        Text(garment.displayName).font(.subheadline)
                        if !garment.brand.isEmpty {
                            Text(garment.brand).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Label("Closet Finder", systemImage: "hanger")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
