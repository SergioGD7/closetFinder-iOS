import SwiftUI

/// Chip de filtro. Va en la capa de contenido, así que es sólido (no de cristal): el
/// seleccionado se rellena con el color del texto, como un interruptor encendido.
struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
            .padding(.horizontal, compact ? 12 : 14)
            .frame(minHeight: compact ? 30 : 36)
            .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
            .background {
                Capsule().fill(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground))
                Capsule().strokeBorder(Color(.separator).opacity(isSelected ? 0 : 0.6), lineWidth: 0.5)
            }
            .animation(.spring(duration: 0.25, bounce: 0), value: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Icono de ubicación en un cuadrado redondeado de color, como en Ajustes.
struct LocationIcon: View {
    let kind: LocationKind
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(kind.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Fila de prenda para listas: miniatura, nombre, ubicación y talla.
struct GarmentRow: View {
    let garment: Garment
    /// Ubicación a mostrar; por defecto la ruta completa.
    var locationText: String?

    var body: some View {
        HStack(spacing: 12) {
            GarmentImage(garment: garment, inset: 0.1)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(garment.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: garment.location == nil ? "questionmark.folder" : "mappin")
                    Text(locationText ?? garment.locationPath)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(garment.location == nil ? Color.secondary : Color.accentColor)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if garment.status != .stored {
                Image(systemName: garment.status.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(garment.status.title)
            }
            if !garment.size.isEmpty {
                SizeBadge(size: garment.size)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SizeBadge: View {
    let size: String

    var body: some View {
        Text(size)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityLabel("Talla \(size)")
    }
}

/// Muestra de color redonda.
struct ColorSwatch: View {
    let color: GarmentColor
    var size: CGFloat = 22
    var isSelected = false

    var body: some View {
        Circle()
            .fill(color.fill)
            .frame(width: size, height: size)
            .overlay { Circle().stroke(.black.opacity(0.12), lineWidth: 0.5) }
            .padding(3)
            .overlay {
                if isSelected { Circle().stroke(Color.accentColor, lineWidth: 2) }
            }
    }
}

/// Esquema de un mueble con sus compartimentos, resaltando uno de ellos.
struct FurnitureSchematic: View {
    let furniture: StorageLocation
    var highlighted: StorageLocation?

    var body: some View {
        let compartments = furniture.compartments
        let rails = compartments.filter { $0.kind == .rail }
        let stacked = compartments.filter { $0.kind != .rail }

        HStack(spacing: 4) {
            ForEach(rails) { rail in
                RailSlot(isHighlighted: rail === highlighted)
            }
            if !stacked.isEmpty {
                VStack(spacing: 3) {
                    ForEach(stacked) { slot in
                        ZStack {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(slot === highlighted ? Color.accentColor : Color(.tertiarySystemFill))
                            if slot.kind == .drawer {
                                Capsule()
                                    .fill(slot === highlighted ? Color.white : Color.secondary.opacity(0.5))
                                    .frame(width: 10, height: 2)
                            }
                        }
                    }
                }
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay { RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color(.separator), lineWidth: 1) }
        }
        .accessibilityElement()
        .accessibilityLabel(highlighted.map { String(localized: "\($0.name) de \(furniture.name)") } ?? furniture.name)
    }

    private struct RailSlot: View {
        let isHighlighted: Bool

        var body: some View {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
                Capsule()
                    .fill(isHighlighted ? Color.accentColor : Color.secondary.opacity(0.6))
                    .frame(height: 2)
                    .padding(.top, 5)
                    .padding(.horizontal, 3)
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(isHighlighted ? Color.accentColor.opacity(0.7) : Color(.tertiarySystemFill))
                            .frame(width: 3, height: [18, 24, 16, 21][index])
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}
