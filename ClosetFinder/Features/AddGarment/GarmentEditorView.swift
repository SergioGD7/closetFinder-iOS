import PhotosUI
import SwiftData
import SwiftUI

/// Alta y edición de prendas. Al elegir una foto se recorta el fondo y se sugieren categoría y
/// color. El modo ráfaga encadena altas en la misma ubicación.
struct GarmentEditorView: View {
    private let garment: Garment?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyProfile.createdAt) private var profiles: [BodyProfile]

    @State private var model: GarmentEditorModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var savedFeedback = 0
    @State private var burstMessage: String?

    init(garment: Garment? = nil, location: StorageLocation? = nil, owner: BodyProfile? = nil) {
        self.garment = garment
        _model = State(initialValue: GarmentEditorModel(garment: garment, location: location, owner: owner))
    }

    private var isNew: Bool { garment == nil }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                suggestionsSection
                garmentSection
                colorSection
                whereSection
                usageSection
                measurementsSection
                Section("Notas") {
                    TextField("Dónde la compraste, arreglos pendientes…", text: $model.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if isNew { burstSection }
            }
            .navigationTitle(isNew ? String(localized: "Nueva prenda") : String(localized: "Editar prenda"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                        .disabled(model.isProcessing)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await model.processPhoto(data)
                    }
                    pickerItem = nil
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    Task { await model.processPhoto(data) }
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .top) { burstBanner }
            .sensoryFeedback(.success, trigger: savedFeedback)
        }
        .interactiveDismissDisabled(model.hasPhoto && isNew)
    }

    // MARK: Foto

    private var photoSection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill((model.colors.first ?? .gray).tint)
                    if let data = model.thumbnail ?? model.photo, let image = UIImage(data: data) {
                        if model.hasCutout {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
                                .padding(24)
                        } else {
                            Color.clear.overlay {
                                Image(uiImage: image).resizable().scaledToFill()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    } else {
                        VStack(spacing: 8) {
                            GarmentArtwork(category: model.category, color: model.colors.first ?? .gray)
                                .frame(width: 110, height: 110)
                                .opacity(0.55)
                            Text("Haz una foto con la prenda extendida sobre un fondo liso")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    }
                    if model.isProcessing {
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial)
                        ProgressView("Recortando el fondo…")
                    }
                }
                .frame(height: 230)
                .overlay(alignment: .bottomLeading) {
                    if model.hasCutout && !model.isProcessing {
                        Label("Fondo eliminado", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassBackground(in: Capsule())
                            .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if model.hasPhoto && !model.isProcessing {
                        GlassCircleButton(title: String(localized: "Quitar foto"), systemImage: "trash") { model.removePhoto() }
                            .padding(10)
                    }
                }

                GlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            isShowingCamera = true
                        } label: {
                            Label("Cámara", systemImage: "camera").frame(maxWidth: .infinity)
                        }
                        .glassButtonStyle(prominent: !model.hasPhoto)
                        .disabled(!CameraPicker.isAvailable)

                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("Fotos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                        }
                        .glassButtonStyle()
                    }
                    .fontWeight(.semibold)
                }
                .disabled(model.isProcessing)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if model.suggestedCategory != nil || !model.detectedColors.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let category = model.suggestedCategory {
                            suggestionChip(category.singular, systemImage: "sparkles", isApplied: model.category == category) {
                                model.category = category
                                model.categoryWasChosen = true
                            }
                        }
                        ForEach(model.detectedColors) { color in
                            suggestionChip(color.title, swatch: color, isApplied: model.colors.contains(color)) {
                                if !model.colors.contains(color) { model.toggleColor(color) }
                            }
                        }
                    }
                }
            } header: {
                Text("Detectado en la foto")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        }
    }

    private func suggestionChip(_ title: String, systemImage: String? = nil, swatch: GarmentColor? = nil,
                                isApplied: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                if let swatch { Circle().fill(swatch.fill).frame(width: 12, height: 12) }
                Text(title)
                if isApplied { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Datos

    private var garmentSection: some View {
        Section("Prenda") {
            TextField("Nombre", text: $model.name, prompt: Text(model.generatedName))
            Picker("Categoría", selection: Binding(
                get: { model.category },
                set: { model.category = $0; model.categoryWasChosen = true })) {
                    ForEach(GarmentCategory.allCases) { Text($0.title).tag($0) }
                }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Talla")
                    TextField("M, 42, 32/32…", text: $model.size)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.category.sizeSuggestions, id: \.self) { size in
                            Button(size) { model.size = size }
                                .font(.footnote.weight(.semibold))
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(model.size == size ? .accentColor : .secondary)
                        }
                    }
                }
            }
            TextField("Marca", text: $model.brand)
            TextField("Material", text: $model.material)
        }
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 8) {
                ForEach(GarmentColor.allCases) { color in
                    Button {
                        model.toggleColor(color)
                    } label: {
                        ColorSwatch(color: color, size: 28, isSelected: model.colors.contains(color))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.title)
                    .accessibilityAddTraits(model.colors.contains(color) ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var whereSection: some View {
        Section("Dónde está") {
            NavigationLink {
                LocationPicker(selection: model.location) { model.location = $0 }
            } label: {
                LabeledContent("Ubicación") {
                    Text(model.location?.path ?? String(localized: "Sin ubicación"))
                        .foregroundStyle(model.location == nil ? Color.secondary : Color.accentColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            Picker("Persona", selection: $model.owner) {
                Text("Nadie en concreto").tag(nil as BodyProfile?)
                ForEach(profiles) { profile in
                    Text(profile.name).tag(profile as BodyProfile?)
                }
            }
        }
    }

    private var usageSection: some View {
        Section("Uso") {
            Picker("Temporada", selection: $model.season) {
                ForEach(Season.allCases) { Text($0.title).tag($0) }
            }
            Picker("Estado", selection: $model.status) {
                ForEach(GarmentStatus.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
        }
    }

    @ViewBuilder
    private var measurementsSection: some View {
        let relevant = model.category.relevantMeasurements
        if !relevant.isEmpty {
            Section {
                ForEach(relevant) { measurement in
                    HStack {
                        Text(measurement.title)
                        Spacer()
                        TextField("—", text: Binding(
                            get: { model.measurements[measurement] ?? "" },
                            set: { model.measurements[measurement] = $0 }))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Medidas de la prenda")
            } footer: {
                Text("Mide la prenda extendida en plano. Con tus medidas corporales, la app te dirá si te queda bien.")
            }
        }
    }

    private var burstSection: some View {
        Section {
            Toggle(isOn: $model.burstMode) {
                Label("Alta en ráfaga", systemImage: "square.stack.3d.up")
            }
        } footer: {
            Text("Al guardar se abre otra prenda nueva con la misma ubicación, persona y temporada. Ideal para fotografiar un cajón entero.")
        }
    }

    @ViewBuilder
    private var burstBanner: some View {
        if let burstMessage {
            Label(burstMessage, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassBackground(in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Guardar

    private func save() {
        let saved = model.save(in: modelContext, editing: garment)
        try? modelContext.save()
        SpotlightIndexer.index(saved)
        savedFeedback += 1

        guard isNew, model.burstMode else {
            dismiss()
            return
        }
        model.prepareNextInBurst()
        let count = model.burstCount
        withAnimation(.snappy) {
            burstMessage = count == 1 ? String(localized: "1 prenda guardada") : String(localized: "\(count) prendas guardadas")
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            if model.burstCount == count {
                withAnimation(.snappy) { burstMessage = nil }
            }
        }
    }
}

#Preview {
    GarmentEditorView()
        .modelContainer(AppModelContainer.preview())
}
