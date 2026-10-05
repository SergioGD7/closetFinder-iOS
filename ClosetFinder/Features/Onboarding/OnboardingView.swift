import CloudKit
import SwiftData
import SwiftUI

/// Primer arranque en tres pasos: dónde guardas la ropa, la primera prenda e iCloud.
struct OnboardingView: View {
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case home, garment, iCloud
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var garments: [Garment]
    @Query private var locations: [StorageLocation]

    @State private var step: Step = .home
    @State private var rooms = RoomDraft.defaults
    @State private var newRoomName = ""
    @State private var isAddingGarment = false
    @State private var isImporting = false
    @State private var iCloudStatus: CKAccountStatus?
    /// Lo creado aquí no cuenta como «han llegado datos de iCloud».
    @State private var createdHere = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Group {
                    switch step {
                    case .home: homeStep
                    case .garment: garmentStep
                    case .iCloud: iCloudStep
                    }
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isAddingGarment) { GarmentEditorView() }
        .sheet(isPresented: $isImporting) { BatchImportView() }
        .task { await loadICloudStatus() }
        .onChange(of: garments.count + locations.count) { old, new in
            // Quien reinstala la app recibe sus datos de iCloud a los pocos segundos: entonces
            // no hace falta seguir.
            if step == .home, !createdHere, old == 0, new > 0 { onFinish() }
        }
    }

    // MARK: Cabecera y pie

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.primary : Color(.tertiarySystemFill))
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: 200)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Paso \(step.rawValue + 1) de \(Step.allCases.count)"))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case .home:
                Button {
                    createdHere = true
                    HomeSetup.create(rooms, in: modelContext)
                    advance()
                } label: {
                    Text("Continuar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                Button("Probar con un armario de ejemplo") {
                    createdHere = true
                    SampleData.insertIfEmpty(into: modelContext)
                    SpotlightIndexer.reindexAll(in: modelContext)
                    onFinish()
                }
                .font(.subheadline.weight(.semibold))
            case .garment:
                if garments.isEmpty {
                    Button(action: advance) { Text("Lo haré después").frame(maxWidth: .infinity) }
                        .buttonStyle(.secondary)
                } else {
                    Button(action: advance) { Text("Continuar").frame(maxWidth: .infinity) }
                        .buttonStyle(.primary)
                }
            case .iCloud:
                Button(action: onFinish) { Text("Empezar").frame(maxWidth: .infinity) }
                    .buttonStyle(.primary)
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return onFinish() }
        withAnimation(.spring(duration: 0.4, bounce: 0)) { step = next }
    }

    private func title(_ symbol: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    // MARK: 1. Casa

    private var homeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("house", String(localized: "¿Dónde guardas la ropa?"),
                  String(localized: "Elige las estancias y sus muebles. Crearemos los cajones y las baldas habituales, y podrás cambiarlo todo después."))

            VStack(spacing: 10) {
                ForEach($rooms) { $room in
                    roomCard($room)
                }
                HStack {
                    TextField("Otra estancia", text: $newRoomName)
                        .submitLabel(.done)
                        .onSubmit(addRoom)
                    Button("Añadir", action: addRoom)
                        .buttonStyle(.secondary(.small))
                        .disabled(newRoomName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Label("¿Ya usabas Closet Finder? Con el mismo Apple ID, tu armario llegará solo desde iCloud en unos segundos.",
                  systemImage: "icloud.and.arrow.down")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func roomCard(_ room: Binding<RoomDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0)) { room.wrappedValue.isIncluded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    LocationIcon(kind: .room, size: 32)
                    Text(room.wrappedValue.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    SelectionMark(isSelected: room.wrappedValue.isIncluded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(room.wrappedValue.isIncluded ? .isSelected : [])

            if room.wrappedValue.isIncluded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(RoomDraft.furnitureOptions) { kind in
                            FilterChip(title: kind.title, systemImage: kind.symbol,
                                       isSelected: room.wrappedValue.furniture.contains(kind), compact: true) {
                                room.wrappedValue.toggle(kind)
                            }
                        }
                    }
                }
                if let summary = summary(of: room.wrappedValue) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// «Armario: barra · 4 baldas · 2 cajones»
    private func summary(of room: RoomDraft) -> String? {
        let parts = room.furniture.compactMap { kind in kind.templateSummary.map { "\(kind.title): \($0)" } }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func addRoom() {
        let name = newRoomName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.snappy) {
            rooms.append(RoomDraft(name: name, isIncluded: true, furniture: [.wardrobe]))
        }
        newRoomName = ""
    }

    // MARK: 2. Primera prenda

    private var garmentStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("camera", String(localized: "Tu primera prenda"),
                  String(localized: "Haz una foto con la prenda extendida sobre un fondo liso. La app recorta el fondo, reconoce el color y te sugiere qué prenda es. Luego eliges dónde la guardas."))

            VStack(spacing: 10) {
                Button {
                    isAddingGarment = true
                } label: {
                    Label("Añadir una prenda", systemImage: "camera").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                Button {
                    isImporting = true
                } label: {
                    Label("Importar varias fotos", systemImage: "photo.stack").frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
            }

            if !garments.isEmpty {
                Label(garments.count == 1 ? String(localized: "1 prenda en tu armario") : String(localized: "\(garments.count) prendas en tu armario"),
                      systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: garments.count)
    }

    // MARK: 3. iCloud

    private var iCloudStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("checkmark.icloud", String(localized: "Tus datos, a salvo"),
                  String(localized: "Tu armario se guarda en tu iCloud privado y se sincroniza entre tu iPhone y tu iPad. Si cambias de iPhone o reinstalas la app, todo vuelve solo."))

            HStack(spacing: 12) {
                Image(systemName: iCloudIsWorking ? "checkmark.icloud.fill" : "exclamationmark.icloud")
                    .font(.title2)
                    .foregroundStyle(iCloudIsWorking ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(iCloudTitle).font(.body.weight(.semibold))
                    Text(iCloudDetail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("En Ajustes (pestaña Medidas) también puedes guardar una copia de seguridad en un archivo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var iCloudIsWorking: Bool { AppModelContainer.syncsWithICloud && iCloudStatus == .available }

    private var iCloudTitle: String {
        guard AppModelContainer.syncsWithICloud else { return String(localized: "Sincronización no disponible") }
        switch iCloudStatus {
        case .available: return String(localized: "iCloud activado")
        case .noAccount: return String(localized: "Sin cuenta de iCloud")
        case nil: return String(localized: "Comprobando iCloud…")
        default: return String(localized: "iCloud no disponible ahora")
        }
    }

    private var iCloudDetail: String {
        guard AppModelContainer.syncsWithICloud else {
            return String(localized: "Esta compilación no tiene acceso a iCloud. Los datos solo se guardan en este dispositivo.")
        }
        switch iCloudStatus {
        case .available: return String(localized: "No tienes que hacer nada: los cambios se copian solos.")
        case .noAccount: return String(localized: "Inicia sesión en Ajustes › tu nombre para guardar una copia en iCloud.")
        case nil: return ""
        default: return String(localized: "Se sincronizará en cuanto iCloud vuelva a estar disponible.")
        }
    }

    private func loadICloudStatus() async {
        guard AppModelContainer.syncsWithICloud else { return }
        iCloudStatus = try? await CKContainer(identifier: AppModelContainer.cloudKitContainer).accountStatus()
    }
}

#Preview {
    OnboardingView {}
        .modelContainer(AppModelContainer.make(inMemory: true))
}
