import SwiftData
import SwiftUI

/// Detalle de una prenda. Lo primero que se ve es dónde está.
struct GarmentDetailView: View {
    @Bindable var garment: Garment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyProfile.createdAt) private var profiles: [BodyProfile]

    @State private var isEditing = false
    @State private var isMoving = false
    @State private var isConfirmingDelete = false
    @State private var wornFeedback = 0
    @State private var isTryingOn = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// En iPad (ancho regular) la foto es más alta y el texto no pasa de una columna cómoda.
    private var heroHeight: CGFloat { sizeClass == .regular ? 480 : 380 }
    private let readableWidth: CGFloat = 720

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                details
                    .padding(.horizontal)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                    .frame(maxWidth: readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground),
                                in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                    .padding(.top, -28)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actionBar }
        .navigationTitle(garment.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbar }
        .sheet(isPresented: $isEditing) { GarmentEditorView(garment: garment) }
        .sheet(isPresented: $isMoving) {
            NavigationStack {
                LocationPicker(selection: garment.location) { newLocation in
                    garment.location = newLocation
                    SpotlightIndexer.index(garment)
                }
            }
        }
        .confirmationDialog("¿Eliminar «\(garment.displayName)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Eliminar prenda", role: .destructive, action: delete)
        } message: {
            Text("Se borrarán la prenda y su foto. No se puede deshacer.")
        }
        .sensoryFeedback(.success, trigger: wornFeedback)
        .fullScreenCover(isPresented: $isTryingOn) { TryOnView(garment: garment) }
        #if DEBUG
        .task {
            // `-openTryOn` junto a `-openGarment` abre el probador (capturas y pruebas manuales).
            if ProcessInfo.processInfo.arguments.contains("-openTryOn") { isTryingOn = true }
        }
        #endif
    }

    // MARK: Cabecera

    private var hero: some View {
        GarmentImage(garment: garment, fullSize: true, inset: 0.14)
            .padding(.top, garment.hasCutout || garment.photo == nil ? 50 : 0)
            .frame(height: heroHeight)
            .background(garment.primaryColor.tint)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if let location = garment.location {
                    NavigationLink(value: location) {
                        Label(location.shortPath, systemImage: "mappin")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassBackground(in: Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading)
                    .padding(.bottom, 44)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if GarmentShell.style(for: garment.category) != .unsupported {
                    Button {
                        isTryingOn = true
                    } label: {
                        Label("Probar en 3D", systemImage: "figure.stand")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassBackground(in: Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing)
                    .padding(.bottom, 44)
                }
            }
    }

    // MARK: Detalles

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(garment.displayName)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if garment.status != .stored {
                Label(garment.status.title, systemImage: garment.status.symbol)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }

            whereCard
            measurementsCard
            infoCard

            if !garment.notes.isEmpty {
                card(title: String(localized: "Notas")) {
                    Text(garment.notes).font(.body)
                }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !garment.brand.isEmpty { parts.append(garment.brand) }
        if !garment.size.isEmpty { parts.append(String(localized: "Talla \(garment.size)")) }
        if !garment.material.isEmpty { parts.append(garment.material) }
        parts.append(garment.season.title)
        return parts.joined(separator: " · ")
    }

    private var whereCard: some View {
        card(title: String(localized: "Dónde está")) {
            if let location = garment.location {
                NavigationLink(value: location) {
                    HStack(spacing: 14) {
                        if let furniture = location.schematicFurniture {
                            FurnitureSchematic(furniture: furniture, highlighted: location === furniture ? nil : location)
                                .frame(width: 84, height: 66)
                        } else {
                            LocationIcon(kind: location.kind, size: 44)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            if let parentPath = location.parentPath {
                                Text(parentPath)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Label("Sin ubicación", systemImage: "questionmark.folder")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Asignar") { isMoving = true }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    @ViewBuilder
    private var measurementsCard: some View {
        let measurements = garment.category.relevantMeasurements.compactMap { m in
            garment.measurement(m).map { (m, $0) }
        }
        if !measurements.isEmpty {
            card(title: String(localized: "Medidas de la prenda")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        ForEach(measurements, id: \.0) { measurement, value in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(value.centimeters)
                                    .font(.headline)
                                    .monospacedDigit()
                                Text(measurement.shortTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if let profile = fitProfile,
                       let fit = SizeConverter.fit(category: garment.category,
                                                   chestWidthCm: garment.chestWidthCm, waistWidthCm: garment.waistWidthCm,
                                                   bodyChestCm: profile.chestCm, bodyWaistCm: profile.waistCm) {
                        FitBadge(fit: fit, personName: profile.name)
                    }
                }
            }
        }
    }

    /// La persona dueña de la prenda o, si no tiene, la primera de la casa.
    private var fitProfile: BodyProfile? { garment.owner ?? profiles.first }

    private var infoCard: some View {
        card(title: String(localized: "Uso")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(garment.wearCount == 1 ? String(localized: "Usada 1 vez") : String(localized: "Usada \(garment.wearCount) veces"))
                    Spacer()
                    if let lastWorn = garment.lastWornAt {
                        Text("Última: \(lastWorn.formatted(.relative(presentation: .named)))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)

                if !garment.colors.isEmpty || garment.owner != nil {
                    Divider()
                    HStack(spacing: 6) {
                        ForEach(garment.colors) { color in
                            HStack(spacing: 4) {
                                ColorSwatch(color: color, size: 14)
                                Text(color.title)
                            }
                            .font(.footnote)
                        }
                        Spacer()
                        if let owner = garment.owner {
                            Label(owner.name, systemImage: "person")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Acciones

    private var actionBar: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isMoving = true
                } label: {
                    Label("Mover", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyle()

                Button {
                    garment.markWorn()
                    wornFeedback += 1
                } label: {
                    Label("La he usado", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                garment.isFavorite.toggle()
            } label: {
                Label(garment.isFavorite ? String(localized: "Quitar de favoritas") : String(localized: "Añadir a favoritas"),
                      systemImage: garment.isFavorite ? "heart.fill" : "heart")
            }
            .tint(garment.isFavorite ? .pink : nil)

            Menu {
                Button { isEditing = true } label: { Label("Editar", systemImage: "pencil") }
                Menu {
                    Picker("Estado", selection: $garment.statusRaw) {
                        ForEach(GarmentStatus.allCases) { status in
                            Label(status.title, systemImage: status.symbol).tag(status.rawValue)
                        }
                    }
                } label: {
                    Label("Estado: \(garment.status.title)", systemImage: garment.status.symbol)
                }
                Divider()
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Label("Más", systemImage: "ellipsis")
            }
        }
    }

    private func delete() {
        SpotlightIndexer.remove([garment])
        modelContext.delete(garment)
        dismiss()
    }
}

/// «Te queda bien · pecho de Yo 98 cm»
struct FitBadge: View {
    let fit: FitAssessment
    let personName: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: fit.result.symbol)
                .font(.caption.weight(.bold))
            Text(fit.result.title)
                .fontWeight(.semibold)
            Text("· \(fit.bodyPart) de \(personName): \(fit.bodyCm.centimeters)")
                .foregroundStyle(fit.result.color.opacity(0.85))
        }
        .font(.footnote)
        .foregroundStyle(fit.result.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(fit.result.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = AppModelContainer.preview()
    let garment = try! container.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.name == "Chaqueta vaquera" }!
    return NavigationStack {
        GarmentDetailView(garment: garment)
    }
    .modelContainer(container)
}
