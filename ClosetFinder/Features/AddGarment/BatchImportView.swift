import PhotosUI
import SwiftData
import SwiftUI

/// Importar muchas fotos de la fototeca de una vez. La cuadrícula se va rellenando a medida que
/// se procesan; solo hay que revisar las fotos en las que la app no reconoce la prenda.
struct BatchImportView: View {
    var onFinish: ([Garment]) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyProfile.createdAt) private var profiles: [BodyProfile]

    @State private var model = BatchImportModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPicking = false
    @State private var reviewing: BatchImportModel.Item?
    @State private var isChoosingLocation = false
    @State private var isConfirmingSkip = false
    @State private var savedFeedback = 0

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Importar fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                if !model.items.isEmpty, model.remainingSlots > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPicking = true
                        } label: {
                            Label("Añadir más fotos", systemImage: "plus")
                        }
                    }
                }
            }
            .photosPicker(isPresented: $isPicking, selection: $pickerItems,
                          maxSelectionCount: max(1, model.remainingSlots), selectionBehavior: .ordered, matching: .images)
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                let loaders: [BatchImportModel.DataLoader] = items.map { item in
                    { try? await item.loadTransferable(type: Data.self) }
                }
                pickerItems = []
                Task { await model.process(loaders) }
            }
            .sheet(item: $reviewing) { item in
                ImportItemReviewSheet(item: item) { category, colors in
                    model.review(item.id, category: category, colors: colors)
                } onRemove: {
                    model.remove(item.id)
                }
            }
            .sheet(isPresented: $isChoosingLocation) {
                NavigationStack {
                    LocationPicker(selection: model.location, allowsNone: true) { model.location = $0 }
                }
            }
            .confirmationDialog(
                model.reviewCount == 1 ? String(localized: "1 foto está sin revisar") : String(localized: "\(model.reviewCount) fotos están sin revisar"),
                isPresented: $isConfirmingSkip, titleVisibility: .visible
            ) {
                Button(model.addable.count == 1 ? String(localized: "Añadir solo 1 prenda") : String(localized: "Añadir solo \(model.addable.count) prendas"), action: save)
            } message: {
                Text("Las fotos sin revisar no se añadirán. Tócalas para elegir qué prenda es.")
            }
            .sensoryFeedback(.success, trigger: savedFeedback)
        }
        .interactiveDismissDisabled(!model.items.isEmpty)
    }

    // MARK: Vacío

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Importar varias fotos", systemImage: "photo.stack")
        } description: {
            Text("Elige hasta \(BatchImportModel.maxPhotos) fotos de prendas. La app recorta el fondo y reconoce cada prenda; tú solo revisas las dudosas.")
        } actions: {
            Button("Elegir fotos") { isPicking = true }
                .buttonStyle(.primary)
        }
    }

    // MARK: Contenido

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.summary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(model.items) { item in
                        Button {
                            if item.state == .ready || item.state == .failed { reviewing = item }
                        } label: {
                            ImportTile(item: item)
                        }
                        .buttonStyle(.pressable)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Guardar todas en")
                        .textCase(.uppercase)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.4)
                    VStack(spacing: 0) {
                        Button {
                            isChoosingLocation = true
                        } label: {
                            HStack {
                                Label("Ubicación", systemImage: "mappin")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(model.location?.path ?? String(localized: "Sin ubicación"))
                                    .foregroundStyle(model.location == nil ? Color.secondary : Color.accentColor)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 14)
                        HStack {
                            Label("Temporada", systemImage: "calendar")
                            Spacer()
                            Picker("Temporada", selection: $model.season) {
                                ForEach(Season.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                        if !profiles.isEmpty {
                            Divider().padding(.leading, 14)
                            HStack {
                                Label("Persona", systemImage: "person")
                                Spacer()
                                Picker("Persona", selection: $model.owner) {
                                    Text("Nadie en concreto").tag(nil as BodyProfile?)
                                    ForEach(profiles) { Text($0.name).tag($0 as BodyProfile?) }
                                }
                                .labelsHidden()
                            }
                            .padding(.leading, 14)
                            .padding(.trailing, 4)
                            .padding(.vertical, 4)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if model.reviewCount > 0 { isConfirmingSkip = true } else { save() }
            } label: {
                Group {
                    if model.isProcessing {
                        Label(String(localized: "Procesando \(model.pendingCount) fotos…"), systemImage: "hourglass")
                    } else if model.addable.isEmpty {
                        Text("Toca las fotos marcadas para revisarlas")
                    } else {
                        Text(model.addable.count == 1 ? String(localized: "Añadir 1 prenda") : String(localized: "Añadir \(model.addable.count) prendas"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(model.isProcessing || model.addable.isEmpty)
            .frame(maxWidth: 560)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func save() {
        let garments = model.save(in: modelContext)
        SpotlightIndexer.index(garments)
        savedFeedback += 1
        onFinish(garments)
        dismiss()
    }
}

/// Una foto de la importación: procesándose, lista, por revisar o fallida.
private struct ImportTile: View {
    let item: BatchImportModel.Item

    var body: some View {
        ZStack {
            (item.colors.first ?? .gray).tint
            if let data = item.image?.thumbnail, let image = UIImage(data: data) {
                if item.image?.isCutout == true {
                    Image(uiImage: image).resizable().scaledToFit().padding(10)
                } else {
                    Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }
                }
            }
            switch item.state {
            case .waiting, .processing:
                ProgressView()
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
            case .ready:
                EmptyView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if item.state == .ready {
                Text(item.category?.singular ?? String(localized: "¿Qué es?"))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .padding(6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if item.needsReview {
                Image(systemName: "questionmark.circle.fill")
                    .font(.body.weight(.bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .orange)
                    .padding(6)
            } else if item.canBeAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body.weight(.bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(.systemBackground), Color.primary)
                    .padding(6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch item.state {
        case .waiting, .processing: String(localized: "Procesando la foto")
        case .failed: String(localized: "No se ha podido leer la foto")
        case .ready: item.category?.singular ?? String(localized: "Prenda sin reconocer. Toca para elegir qué es.")
        }
    }
}

/// Revisar una foto de la importación: qué prenda es y de qué color, o quitarla.
private struct ImportItemReviewSheet: View {
    let item: BatchImportModel.Item
    let onSave: (GarmentCategory, [GarmentColor]) -> Void
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: GarmentCategory?
    @State private var colors: [GarmentColor]

    init(item: BatchImportModel.Item, onSave: @escaping (GarmentCategory, [GarmentColor]) -> Void, onRemove: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onRemove = onRemove
        _category = State(initialValue: item.category)
        _colors = State(initialValue: item.colors)
    }

    var body: some View {
        NavigationStack {
            Form {
                if item.state == .ready {
                    Section {
                        ImportTile(item: item)
                            .frame(maxWidth: 220)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)

                    Section("¿Qué prenda es?") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(GarmentCategory.allCases) { option in
                                FilterChip(title: option.singular, isSelected: category == option, compact: true) { category = option }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Section("Color") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 8) {
                            ForEach(GarmentColor.allCases) { color in
                                Button {
                                    if let index = colors.firstIndex(of: color) { colors.remove(at: index) } else { colors.append(color) }
                                } label: {
                                    ColorSwatch(color: color, size: 28, isSelected: colors.contains(color))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(color.title)
                                .accessibilityAddTraits(colors.contains(color) ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        Text("No se ha podido leer esta foto. Puede que el archivo esté en iCloud y no se haya descargado.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Quitar de la importación", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Revisar foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                if item.state == .ready {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar", systemImage: "checkmark") {
                            if let category { onSave(category, colors) }
                            dismiss()
                        }
                        .disabled(category == nil)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    BatchImportView()
        .modelContainer(AppModelContainer.preview())
}
