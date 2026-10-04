import SwiftData
import SwiftUI

/// Probador: una fila deslizable por cada parte del cuerpo. La prenda centrada es la elegida;
/// la chincheta fija una fila y el dado combina al azar las demás.
struct FittingRoomView: View {
    enum Mode {
        /// En la pestaña Looks: al guardar se crea un look nuevo y el probador sigue abierto.
        case tab
        /// En una hoja: crear un look (opcionalmente con prendas ya elegidas) o editar uno.
        case sheet(outfit: Outfit?, preselected: [Garment])
    }

    let mode: Mode
    var onSave: (Outfit) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Garment.name) private var garments: [Garment]

    @State private var model: FittingRoomModel?
    @State private var isNaming = false
    @State private var name = ""
    @State private var savedMessage: String?
    @State private var selectionFeedback = 0
    @State private var shuffleFeedback = 0

    private var editing: Outfit? {
        if case .sheet(let outfit, _) = mode { return outfit }
        return nil
    }

    var body: some View {
        Group {
            if let model {
                if garments.isEmpty {
                    ContentUnavailableView("Tu armario está vacío", systemImage: "hanger",
                                           description: Text("Añade prendas en el Armario para combinarlas aquí."))
                } else {
                    room(model)
                }
            } else {
                ProgressView()
            }
        }
        .background(Color(.systemBackground))
        .task(id: garments.count) {
            // Se crea al aparecer, y otra vez si cambia el número de prendas del armario.
            let preselected: [Garment]
            if case .sheet(_, let garments) = mode { preselected = garments } else { preselected = [] }
            model = FittingRoomModel(garments: garments, outfit: editing, preselected: preselected)
        }
        .toolbar {
            if case .sheet = mode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .alert(editing == nil ? String(localized: "Guardar look") : String(localized: "Guardar cambios"), isPresented: $isNaming) {
            TextField("Nombre", text: $name)
            Button("Guardar", action: save)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Ponle un nombre para encontrarlo luego: Oficina, Boda, Domingo…")
        }
        .overlay(alignment: .top) {
            if let savedMessage {
                Label(savedMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassBackground(in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedback)
        .sensoryFeedback(.impact(weight: .medium), trigger: shuffleFeedback)
    }

    // MARK: Probador

    private func room(_ model: FittingRoomModel) -> some View {
        GeometryReader { proxy in
            let slots = model.layout.slots
            let total = slots.map(Self.weight).reduce(0, +)
            let available = proxy.size.height - 56 // cabecera
            VStack(spacing: 0) {
                HStack {
                    Text(model.layout.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Guardar") {
                        name = editing?.name ?? model.suggestedName
                        isNaming = true
                    }
                    .buttonStyle(.primary(.small))
                    .disabled(!model.canSave)
                }
                .padding(.horizontal)
                .frame(height: 56)
                ForEach(slots) { slot in
                    FittingRow(model: model, slot: slot, onChange: { selectionFeedback += 1 })
                        .frame(height: max(available * Self.weight(slot) / total, 70))
                }
                Spacer(minLength: 0)
            }
            .animation(.spring(duration: 0.4, bounce: 0), value: model.layout)
        }
        .safeAreaInset(edge: .bottom) { controls(model) }
    }

    /// Altura relativa de cada fila: una prenda de cuerpo entero ocupa casi dos filas.
    static func weight(_ slot: OutfitSlot) -> CGFloat {
        switch slot {
        case .outer, .top: 1
        case .bottom: 1.15
        case .fullBody: 1.9
        case .feet: 0.6
        case .accessories: 0.5
        }
    }

    private func controls(_ model: FittingRoomModel) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
            ForEach(FittingLayout.allCases) { layout in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0)) { model.layout = layout }
                } label: {
                    LayoutGlyph(slots: layout.slots, isSelected: model.layout == layout)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(layout.title)
                .accessibilityAddTraits(model.layout == layout ? .isSelected : [])
            }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassBackground(in: Capsule())

            // Fuera del cristal: un relleno sólido dentro de él perdería su color.
            Button {
                withAnimation(.spring(duration: 0.45, bounce: 0.15)) { model.shuffle() }
                shuffleFeedback += 1
            } label: {
                Image(systemName: "dice.fill")
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Combinar al azar")
            .accessibilityHint("Cambia las filas que no estén fijadas con la chincheta")
        }
        .padding(.bottom, 8)
    }

    // MARK: Guardar

    private func save() {
        guard let model else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let outfit: Outfit
        if let editing {
            outfit = editing
        } else {
            outfit = Outfit()
            modelContext.insert(outfit)
        }
        outfit.name = trimmed
        outfit.garments = model.selectedGarments
        try? modelContext.save()
        onSave(outfit)
        if case .sheet = mode {
            dismiss()
        } else {
            withAnimation(.snappy) { savedMessage = String(localized: "Guardado en Looks") }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.snappy) { savedMessage = nil }
            }
        }
    }
}

/// Una fila del probador: carrusel horizontal con imán al centro.
private struct FittingRow: View {
    @Bindable var model: FittingRoomModel
    let slot: OutfitSlot
    let onChange: () -> Void

    var body: some View {
        let items = model.items(for: slot)
        if items.isEmpty || items == [FittingRoomModel.noneID] {
            HStack(spacing: 10) {
                GarmentArtwork(category: slot.representativeCategory, color: .gray)
                    .frame(width: 32, height: 32)
                    .opacity(0.4)
                Text("No tienes prendas de «\(slot.title)»")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                carousel(items, width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    /// La prenda ocupa la mitad del ancho; los márgenes del 25 % dejan ver las de los lados y
    /// hacen que el imán la deje centrada.
    private func carousel(_ items: [UUID], width: CGFloat, height: CGFloat) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(items, id: \.self) { id in
                        item(id)
                            .frame(width: width * 0.5, height: height)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.78)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, width * 0.25, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { model.selection[slot] },
                set: { newValue in
                    guard let newValue, newValue != model.selection[slot] else { return }
                    model.selection[slot] = newValue
                    onChange()
                }))
            .overlay(alignment: .topTrailing) {
                pinButton.padding(.trailing, max(width * 0.25 - 18, 4))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(slot.title)
    }

    @ViewBuilder
    private func item(_ id: UUID) -> some View {
        let garment = model.garment(id, in: slot)
        VStack(spacing: 4) {
            if let garment {
                GarmentCutout(garment: garment)
                    .padding(.horizontal, 8)
                    .accessibilityLabel(garment.displayName)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    Text("Sin \(slot.title.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(6)
                }
                .padding(12)
                .accessibilityLabel(String(localized: "Sin \(slot.title.lowercased())"))
            }
        }
        .padding(.vertical, 6)
    }

    private var pinButton: some View {
        let isPinned = model.pinned.contains(slot)
        return Button {
            withAnimation(.spring(duration: 0.25, bounce: 0)) { model.togglePin(slot) }
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.subheadline.weight(.semibold))
                .rotationEffect(.degrees(45))
                .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 36, height: 36)
                .background(isPinned ? Color.accentColor.opacity(0.15) : Color.clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .padding(.top, 4)
        .accessibilityLabel(isPinned ? String(localized: "Soltar \(slot.title)") : String(localized: "Fijar \(slot.title)"))
    }
}

/// Icono de cada diseño: tantas barras como filas, como en los probadores de ropa.
private struct LayoutGlyph: View {
    let slots: [OutfitSlot]
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ForEach(slots) { slot in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: 2).fill(isSelected ? Color.accentColor.opacity(0.35) : .clear))
                    .frame(width: 22, height: max(22 * FittingRoomView.weight(slot) / CGFloat(slots.count + 1), 3))
            }
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .frame(width: 30, height: 30)
    }
}

#Preview {
    NavigationStack {
        FittingRoomView(mode: .tab)
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(AppModelContainer.preview())
}
