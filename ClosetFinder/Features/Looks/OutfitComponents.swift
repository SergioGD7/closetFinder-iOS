import SwiftData
import SwiftUI

/// Mosaico con las prendas de un look (hasta cuatro; si hay más, indica cuántas faltan).
struct OutfitMosaic: View {
    let garments: [Garment]
    var cornerRadius: CGFloat = 20
    var spacing: CGFloat = 3

    var body: some View {
        let items = Array(garments.prefix(4))
        let extra = garments.count - items.count
        Group {
            switch items.count {
            case 0:
                ZStack {
                    Color(.tertiarySystemFill)
                    GarmentArtwork(category: .tShirt, color: .gray)
                        .opacity(0.35)
                        .padding(24)
                }
            case 1:
                tile(items[0])
            case 2:
                HStack(spacing: spacing) { tile(items[0]); tile(items[1]) }
            case 3:
                HStack(spacing: spacing) {
                    tile(items[0])
                    VStack(spacing: spacing) { tile(items[1]); tile(items[2]) }
                }
            default:
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) { tile(items[0]); tile(items[1]) }
                    HStack(spacing: spacing) {
                        tile(items[2])
                        tile(items[3])
                            .overlay {
                                if extra > 0 {
                                    Text("+\(extra)")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(.black.opacity(0.35))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func tile(_ garment: Garment) -> some View {
        GarmentImage(garment: garment, inset: 0.1)
    }
}

/// Tarjeta de un look para rejillas.
struct OutfitCard: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { OutfitMosaic(garments: outfit.pieces, cornerRadius: 22) }
                .overlay(alignment: .topLeading) {
                    if outfit.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.pink)
                            .padding(7)
                            .background(.regularMaterial, in: Circle())
                            .padding(8)
                    }
                }
            Text(outfit.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 2)
            OutfitSubtitle(outfit: outfit)
                .padding(.horizontal, 2)
                .padding(.top, -3)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// «4 prendas» o el aviso de que alguna no está disponible.
struct OutfitSubtitle: View {
    let outfit: Outfit

    var body: some View {
        let unavailable = outfit.unavailablePieces
        HStack(spacing: 4) {
            if let first = unavailable.first {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("\(first.displayName): \(first.status.title.lowercased())")
            } else {
                let count = outfit.pieces.count
                Text(count == 1 ? String(localized: "1 prenda") : String(localized: "\(count) prendas"))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// Fila de un look para listas.
struct OutfitRow: View {
    let outfit: Outfit

    var body: some View {
        HStack(spacing: 12) {
            OutfitMosaic(garments: outfit.pieces, cornerRadius: 12, spacing: 1.5)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(outfit.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                OutfitSubtitle(outfit: outfit)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Elige una prenda. Si se indica una parte del cuerpo, solo muestra las que encajan en ella.
struct GarmentPickerSheet: View {
    var slot: OutfitSlot?
    var selected: [Garment] = []
    let onPick: (Garment) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Garment.name) private var garments: [Garment]
    @State private var searchText = ""

    private var candidates: [Garment] {
        let inSlot = slot.map { slot in garments.filter { OutfitSlot.slot(for: $0.category) == slot } } ?? garments
        return GarmentSearch.search(inSlot, text: searchText)
    }

    var body: some View {
        NavigationStack {
            List(candidates) { garment in
                Button {
                    onPick(garment)
                    dismiss()
                } label: {
                    HStack {
                        GarmentRow(garment: garment)
                        if selected.contains(where: { $0 === garment }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No hay prendas"),
                        systemImage: "hanger",
                        description: Text(slot.map { String(localized: "Añade prendas de tipo «\($0.title)» a tu armario.") }
                                          ?? String(localized: "Añade prendas a tu armario.")))
                }
            }
            .searchable(text: $searchText, prompt: "Buscar prenda")
            .navigationTitle(slot?.title ?? String(localized: "Elegir prenda"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

/// Elige un look guardado o crea uno nuevo.
struct OutfitPickerSheet: View {
    var title: String = String(localized: "Elegir look")
    var excluding: [Outfit] = []
    let onPick: (Outfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]
    @State private var isCreating = false

    private var candidates: [Outfit] { outfits.filter { outfit in !excluding.contains { $0 === outfit } } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 16) {
                    Button {
                        isCreating = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.title.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            Text("Crear look nuevo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(candidates) { outfit in
                        Button {
                            onPick(outfit)
                            dismiss()
                        } label: {
                            OutfitCard(outfit: outfit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $isCreating) {
                OutfitEditorView { created in
                    onPick(created)
                    dismiss()
                }
            }
        }
    }
}

/// Cabecera de sección con la ilustración de la parte del cuerpo.
struct OutfitSlotHeader: View {
    let slot: OutfitSlot
    var count: Int?

    var body: some View {
        HStack(spacing: 6) {
            GarmentArtwork(category: slot.representativeCategory, color: .gray)
                .frame(width: 18, height: 18)
            Text(slot.title)
            if let count, slot.maxItems > 1 {
                Text("\(count)/\(slot.maxItems)").foregroundStyle(.tertiary)
            }
        }
    }
}
