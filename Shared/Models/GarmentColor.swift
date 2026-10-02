import SwiftUI
import UIKit

/// Paleta cerrada de colores de ropa. Una lista corta hace que filtrar y buscar por color sea fiable.
nonisolated enum GarmentColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case black, white, gray, beige, brown, navy, blue, lightBlue, green, olive, yellow, orange, red, burgundy, pink, purple, multicolor

    var id: Self { self }

    var masculine: String {
        switch self {
        case .black: "negro"
        case .white: "blanco"
        case .gray: "gris"
        case .beige: "beige"
        case .brown: "marrón"
        case .navy: "azul marino"
        case .blue: "azul"
        case .lightBlue: "celeste"
        case .green: "verde"
        case .olive: "verde oliva"
        case .yellow: "amarillo"
        case .orange: "naranja"
        case .red: "rojo"
        case .burgundy: "burdeos"
        case .pink: "rosa"
        case .purple: "morado"
        case .multicolor: "multicolor"
        }
    }

    var feminine: String {
        switch self {
        case .black: "negra"
        case .white: "blanca"
        case .yellow: "amarilla"
        case .red: "roja"
        case .purple: "morada"
        default: masculine
        }
    }

    var title: String { masculine.prefix(1).uppercased() + masculine.dropFirst() }

    func adjective(feminine isFeminine: Bool) -> String { isFeminine ? feminine : masculine }

    /// Componentes RGB (0…1). `nil` para multicolor.
    var rgb: (r: Double, g: Double, b: Double)? {
        let hex: UInt32? = switch self {
        case .black: 0x1E1F24
        case .white: 0xF7F6F2
        case .gray: 0x8E9098
        case .beige: 0xD9C7A7
        case .brown: 0x7A5638
        case .navy: 0x26355C
        case .blue: 0x3F6CB5
        case .lightBlue: 0x8FBCE6
        case .green: 0x5E8C61
        case .olive: 0x77783F
        case .yellow: 0xE8C547
        case .orange: 0xE0883A
        case .red: 0xC2423A
        case .burgundy: 0x7A2738
        case .pink: 0xE7A1B0
        case .purple: 0x7B5AA6
        case .multicolor: nil
        }
        guard let hex else { return nil }
        return (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    var swatch: Color {
        guard let rgb else { return Color(red: 0.6, green: 0.5, blue: 0.7) }
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    /// Relleno para las siluetas: degradado en el caso multicolor.
    var fill: AnyShapeStyle {
        if self == .multicolor {
            return AnyShapeStyle(LinearGradient(
                colors: [GarmentColor.red.swatch, GarmentColor.yellow.swatch, GarmentColor.green.swatch, GarmentColor.blue.swatch],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(swatch)
    }

    /// Fondo suave derivado del color, adaptado a modo claro y oscuro.
    var tint: Color {
        let base = rgb ?? (0.62, 0.6, 0.7)
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let target = dark ? 0.0 : 1.0
            let amount = dark ? 0.62 : 0.78
            return UIColor(
                red: base.r + (target - base.r) * amount,
                green: base.g + (target - base.g) * amount,
                blue: base.b + (target - base.b) * amount,
                alpha: 1)
        })
    }

    /// Color de la paleta más cercano a un RGB dado (distancia «redmean», más fiel a la percepción que la euclídea).
    static func nearest(r: Double, g: Double, b: Double) -> GarmentColor {
        var best = GarmentColor.gray
        var bestDistance = Double.greatestFiniteMagnitude
        for color in allCases {
            guard let c = color.rgb else { continue }
            let rMean = (r + c.r) / 2
            let dr = r - c.r, dg = g - c.g, db = b - c.b
            let distance = (2 + rMean) * dr * dr + 4 * dg * dg + (3 - rMean) * db * db
            if distance < bestDistance {
                bestDistance = distance
                best = color
            }
        }
        return best
    }
}
