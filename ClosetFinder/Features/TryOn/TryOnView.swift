import PhotosUI
import SceneKit
import SwiftData
import SwiftUI

/// Probador 3D: un maniquí con tus medidas y la prenda puesta con las suyas. Se gira y se
/// amplía con los dedos. Todo se calcula en el iPhone, sin servidores.
struct TryOnView: View {
    let garment: Garment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BodyProfile.createdAt) private var profiles: [BodyProfile]

    @State private var selectedProfileID: UUID?
    @State private var showsGarment = true
    @State private var scene: SCNScene?
    @State private var shell: GarmentShell?
    @State private var body3D: BodyShape?
    @State private var isPanelExpanded = true

    private var profile: BodyProfile? {
        profiles.first { $0.uuid == selectedProfileID } ?? garment.owner ?? profiles.first
    }

    /// Cambia cuando hay que reconstruir la escena.
    private var sceneKey: String {
        [profile?.uuid.uuidString ?? "-", String(profile?.hasTryOnPhoto ?? false),
         String(describing: profile?.chestCm), String(describing: profile?.heightCm),
         String(garment.imageRevision), colorScheme == .dark ? "dark" : "light"].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let scene {
                    SceneView(scene: scene,
                              pointOfView: scene.rootNode.childNode(withName: TryOnSceneBuilder.cameraNodeName, recursively: true),
                              options: [.allowsCameraControl, .temporalAntialiasingEnabled])
                        .ignoresSafeArea()
                        .accessibilityLabel("Maniquí en 3D con \(garment.displayName). Desliza para girarlo.")
                } else {
                    ProgressView()
                }
            }
            .overlay(alignment: .bottom) { panel }
            .navigationTitle("Probador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task(id: sceneKey) { rebuild() }
            .onChange(of: showsGarment) { _, visible in
                scene?.rootNode.childNode(withName: TryOnSceneBuilder.garmentNodeName, recursively: false)?.isHidden = !visible
            }
        }
    }

    // MARK: Escena

    private func rebuild() {
        let input = BodyShape.Input(
            heightCm: profile?.heightCm, chestCm: profile?.chestCm, waistCm: profile?.waistCm,
            hipCm: profile?.hipCm, inseamCm: profile?.inseamCm, footCm: profile?.footCm,
            sizing: profile?.sizing ?? .menswear,
            shoulderRatio: profile?.shoulderRatio, hipRatio: profile?.hipRatio)
        let body = BodyShape(input)
        let shell = GarmentShell(.init(category: garment.category, chestWidthCm: garment.chestWidthCm,
                                       waistWidthCm: garment.waistWidthCm, lengthCm: garment.lengthCm,
                                       sleeveCm: garment.sleeveCm, inseamCm: garment.inseamCm, size: garment.size), on: body)

        var appearance = TryOnAppearance()
        appearance.isDark = colorScheme == .dark
        if let tone = profile?.skinTone, tone.count == 3 {
            appearance.skinColor = UIColor(red: tone[0], green: tone[1], blue: tone[2], alpha: 1)
        }
        appearance.faceTexture = profile?.faceTexture.flatMap(UIImage.init(data:))
        appearance.garmentPhoto = garment.hasCutout ? garment.photo.flatMap(UIImage.init(data:)) : nil
        appearance.garmentColor = UIColor(garment.primaryColor.swatch)

        let newScene = TryOnSceneBuilder.makeScene(body: body, shell: shell.style == .unsupported ? nil : shell, appearance: appearance)
        newScene.rootNode.childNode(withName: TryOnSceneBuilder.garmentNodeName, recursively: false)?.isHidden = !showsGarment
        self.body3D = body
        self.shell = shell
        self.scene = newScene
    }

    // MARK: Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { isPanelExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(garment.displayName).font(.headline)
                        Text(profile.map { String(localized: "En el maniquí de \($0.name)") } ?? String(localized: "Maniquí estándar"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPanelExpanded {
                if shell?.style == .unsupported {
                    Text("El probador todavía no muestra accesorios.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shell?.lines ?? []) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: symbol(for: line.level))
                                .foregroundStyle(color(for: line.level))
                                .frame(width: 16)
                            Text(line.title).fontWeight(.semibold)
                            Text(line.detail).foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                if let assumed = assumedText {
                    Label(assumed, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let profile, !profile.hasTryOnPhoto {
                    TryOnPhotoButton(profile: profile)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 560, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var assumedText: String? {
        guard let assumed = body3D?.assumed, !assumed.isEmpty else { return nil }
        let names = BodyMeasurement.allCases.filter(assumed.contains).map { $0.title.lowercased() }
        let list = ListFormatter.localizedString(byJoining: names)
        return profile == nil
            ? String(localized: "Maniquí con medidas típicas. Añade tus medidas en la pestaña Medidas.") : String(localized: "Sin medir: \(list). Se usan valores típicos.")
    }

    private func symbol(for level: GarmentShell.Level) -> String {
        switch level {
        case .good: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .info: "ruler"
        }
    }

    private func color(for level: GarmentShell.Level) -> Color {
        switch level {
        case .good: .green
        case .warning: .orange
        case .info: .secondary
        }
    }

    // MARK: Barra

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cerrar", systemImage: "xmark") { dismiss() }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showsGarment.toggle()
            } label: {
                Label(showsGarment ? String(localized: "Quitar la prenda") : String(localized: "Poner la prenda"),
                      systemImage: showsGarment ? "tshirt.fill" : "tshirt")
            }
            if profiles.count > 1 {
                Menu {
                    Picker("Persona", selection: Binding(
                        get: { profile?.uuid },
                        set: { selectedProfileID = $0 })) {
                            ForEach(profiles) { Text($0.name).tag(Optional($0.uuid)) }
                        }
                } label: {
                    Label("Persona", systemImage: "person.2")
                }
            }
        }
    }
}

/// Botón para elegir una foto de cuerpo entero y personalizar el maniquí.
struct TryOnPhotoButton: View {
    @Bindable var profile: BodyProfile
    @State private var item: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        // La etiqueta de PhotosPicker no se ejecuta en el actor principal: se calcula antes.
        let analyzing = isAnalyzing
        let symbol = profile.hasTryOnPhoto ? "arrow.triangle.2.circlepath.camera" : "person.crop.rectangle"
        let title = analyzing ? String(localized: "Analizando la foto…") : profile.hasTryOnPhoto ? String(localized: "Cambiar la foto") : String(localized: "Usar una foto mía")
        VStack(alignment: .leading, spacing: 6) {
            PhotosPicker(selection: $item, matching: .images) {
                HStack(spacing: 8) {
                    if analyzing {
                        ProgressView()
                    } else {
                        Image(systemName: symbol)
                    }
                    Text(title)
                }
                .font(.subheadline.weight(.semibold))
            }
            .disabled(isAnalyzing)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.orange)
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            analyze(newItem)
        }
    }

    private func analyze(_ item: PhotosPickerItem) {
        isAnalyzing = true
        errorMessage = nil
        Task {
            defer {
                isAnalyzing = false
                self.item = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                errorMessage = String(localized: "No se ha podido abrir la foto.")
                return
            }
            do {
                let analysis = try await BodyPhotoAnalyzer.analyze(data)
                profile.shoulderRatio = analysis.shoulderRatio ?? profile.shoulderRatio
                profile.hipRatio = analysis.hipRatio ?? profile.hipRatio
                if let tone = analysis.skinTone { profile.skinTone = tone }
                if let face = analysis.faceTexture { profile.faceTexture = face }
                if analysis.shoulderRatio == nil {
                    errorMessage = String(localized: "Se ha usado tu cara, pero no se ve el cuerpo entero: las proporciones son las típicas.")
                }
            } catch {
                errorMessage = String(localized: "No se ve a ninguna persona. Usa una foto de cuerpo entero, de frente y con buena luz.")
            }
        }
    }
}
