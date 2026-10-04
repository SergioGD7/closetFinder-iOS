import SwiftData
import SwiftUI

/// Una prenda recortada, sin fondo: la foto sin fondo, la foto normal con esquinas redondeadas
/// o, si no hay foto, su ilustración.
struct GarmentCutout: View {
    let garment: Garment
    var fullSize = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let image = ImageCache.shared.image(for: garment, fullSize: fullSize) {
                if garment.hasCutout {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                GarmentArtwork(category: garment.category, color: garment.primaryColor)
            }
        }
        // En oscuro, un halo claro: si no, una prenda negra desaparece sobre el fondo.
        .shadow(color: colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.12),
                radius: colorScheme == .dark ? 2.5 : 6, y: colorScheme == .dark ? 0 : 4)
    }
}

/// Un look como en un probador: las prendas de arriba abajo, como se llevan puestas.
/// Abrigo y parte de arriba comparten fila; el calzado y los accesorios son más bajos.
struct OutfitFigure: View {
    let garments: [Garment]
    var spacing: CGFloat = 4

    private struct Row: Identifiable {
        let id: Int
        let garments: [Garment]
        let weight: CGFloat
    }

    private var rows: [Row] {
        func pieces(_ slots: Set<OutfitSlot>) -> [Garment] {
            Outfit.sortedBySlot(garments.filter { slots.contains(OutfitSlot.slot(for: $0.category)) })
        }
        let candidates: [(Set<OutfitSlot>, CGFloat)] = [
            ([.outer, .top], 1), ([.fullBody], 1.9), ([.bottom], 1.15), ([.feet], 0.55), ([.accessories], 0.45),
        ]
        return candidates.enumerated().compactMap { index, entry in
            let row = pieces(entry.0)
            return row.isEmpty ? nil : Row(id: index, garments: row, weight: entry.1)
        }
    }

    var body: some View {
        let rows = rows
        GeometryReader { proxy in
            let total = rows.map(\.weight).reduce(0, +)
            let available = proxy.size.height - spacing * CGFloat(max(rows.count - 1, 0))
            VStack(spacing: spacing) {
                ForEach(rows) { row in
                    HStack(spacing: -12) {
                        ForEach(row.garments) { garment in
                            GarmentCutout(garment: garment)
                        }
                    }
                    .frame(height: total > 0 ? available * row.weight / total : 0)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if rows.isEmpty {
                GarmentArtwork(category: .tShirt, color: .gray).opacity(0.3).padding(20)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Tarjeta de un look: la figura sobre un fondo liso, con el nombre debajo.
struct OutfitCard: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OutfitFigure(garments: outfit.pieces)
                .padding(14)
                .aspectRatio(0.7, contentMode: .fit)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if outfit.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.pink)
                            .padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(outfit.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                OutfitSubtitle(outfit: outfit)
            }
            .padding(.horizontal, 4)
        }
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
            OutfitFigure(garments: outfit.pieces, spacing: 1)
                .padding(5)
                .frame(width: 48, height: 64)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

/// Elige una prenda. Las de `unavailable` aparecen desactivadas con el motivo (por ejemplo,
/// «Ya va en la maleta»), para no añadir dos veces la misma.
struct GarmentPickerSheet: View {
    var title: String = String(localized: "Elegir prenda")
    var unavailable: [Garment] = []
    var unavailableReason: String = ""
    let onPick: (Garment) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Garment.name) private var garments: [Garment]
    @State private var searchText = ""

    private var candidates: [Garment] { GarmentSearch.search(garments, text: searchText) }

    var body: some View {
        NavigationStack {
            List(candidates) { garment in
                let isTaken = unavailable.contains { $0 === garment }
                Button {
                    onPick(garment)
                    dismiss()
                } label: {
                    HStack {
                        GarmentRow(garment: garment, locationText: isTaken ? unavailableReason : nil)
                        if isTaken {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(isTaken ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isTaken)
            }
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(String(localized: "No hay prendas"), systemImage: "hanger",
                                           description: Text("Añade prendas a tu armario."))
                }
            }
            .searchable(text: $searchText, prompt: "Buscar prenda")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

/// Elige un look guardado o crea uno nuevo en el probador.
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 18) {
                    Button {
                        isCreating = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                                .aspectRatio(0.7, contentMode: .fit)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus").font(.title2.weight(.semibold))
                                        Text("Crear en el probador").font(.footnote.weight(.semibold))
                                    }
                                    .foregroundStyle(.primary)
                                }
                            Text(verbatim: " ").font(.subheadline)
                        }
                    }
                    .buttonStyle(.pressable)

                    ForEach(candidates) { outfit in
                        Button {
                            onPick(outfit)
                            dismiss()
                        } label: {
                            OutfitCard(outfit: outfit)
                        }
                        .buttonStyle(.pressable)
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
                NavigationStack {
                    FittingRoomView(mode: .sheet(outfit: nil, preselected: [])) { created in
                        onPick(created)
                        dismiss()
                    }
                    .navigationTitle("Probador")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}
