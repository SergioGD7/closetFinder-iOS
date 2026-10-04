import SwiftUI

// Botones de la app. Sólidos y de alto contraste en modo claro y oscuro: el cristal se reserva
// para la capa flotante del sistema (barras y pestañas), sin apilar cristal sobre cristal.
// Todos responden al instante al pulsar (se encogen un poco) con un muelle sin rebote.

/// Acción principal: relleno del color del texto (negro en claro, blanco en oscuro).
struct PrimaryButtonStyle: ButtonStyle {
    var size: ControlSize = .large
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, size == .large ? 22 : 14)
            .frame(minHeight: size == .large ? 50 : 34)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .pressEffect(configuration.isPressed)
    }
}

/// Acción secundaria: relleno gris suave del sistema. Si flota sobre contenido (`floating`),
/// usa un material opaco con sombra para que no se pierda contra lo que hay debajo.
struct SecondaryButtonStyle: ButtonStyle {
    var size: ControlSize = .large
    var floating = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .large ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, size == .large ? 22 : 14)
            .frame(minHeight: size == .large ? 50 : 34)
            .foregroundStyle(.primary)
            .background {
                if floating {
                    Capsule().fill(.thickMaterial).shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                } else {
                    Capsule().fill(Color(.tertiarySystemFill))
                }
            }
            .opacity(isEnabled ? 1 : 0.35)
            .pressEffect(configuration.isPressed)
    }
}

/// Acción destructiva: rojo del sistema, para borrar.
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 22)
            .frame(minHeight: 50)
            .foregroundStyle(.white)
            .background(Color.red, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .pressEffect(configuration.isPressed)
    }
}

/// Círculo de selección, como en Fotos.
struct SelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle().fill(isSelected ? Color.accentColor : Color.black.opacity(0.2))
            Circle().strokeBorder(.white, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .animation(.spring(duration: 0.2, bounce: 0), value: isSelected)
        .accessibilityHidden(true)
    }
}

/// Para tarjetas y celdas pulsables: solo la respuesta al toque.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .pressEffect(configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(_ size: ControlSize) -> PrimaryButtonStyle { PrimaryButtonStyle(size: size) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(_ size: ControlSize) -> SecondaryButtonStyle { SecondaryButtonStyle(size: size) }
    /// Secundario que flota sobre contenido (barras inferiores).
    static var floatingSecondary: SecondaryButtonStyle { SecondaryButtonStyle(floating: true) }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

extension View {
    /// Se encoge al pulsar y vuelve con un muelle críticamente amortiguado (sin rebote).
    func pressEffect(_ isPressed: Bool) -> some View {
        scaleEffect(isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0), value: isPressed)
    }
}

/// Apariencia elegida en Ajustes.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "Automática")
        case .light: String(localized: "Clara")
        case .dark: String(localized: "Oscura")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static let storageKey = "appearance"
}
