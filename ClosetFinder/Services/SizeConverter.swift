import SwiftUI

nonisolated struct SizeRecommendation: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let size: String
    let equivalents: String
}

nonisolated enum FitResult: Sendable, Equatable {
    case tooSmall, snug, good, loose, tooBig

    var title: String {
        switch self {
        case .tooSmall: "Pequeña"
        case .snug: "Ajustada"
        case .good: "Te queda bien"
        case .loose: "Holgada"
        case .tooBig: "Grande"
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark"
        case .snug, .loose: "exclamationmark"
        case .tooSmall: "arrow.down.right.and.arrow.up.left"
        case .tooBig: "arrow.up.left.and.arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .good: .green
        case .snug, .loose: .orange
        case .tooSmall, .tooBig: .red
        }
    }
}

nonisolated struct FitAssessment: Sendable, Equatable {
    let result: FitResult
    /// «pecho» o «cintura»
    let bodyPart: String
    let bodyCm: Double
    /// Contorno de la prenda menos contorno del cuerpo.
    let easeCm: Double
}

/// Conversión de medidas corporales a tallas, y comparación prenda–cuerpo.
/// Las tablas son aproximaciones de las guías europeas más habituales; cada marca varía un poco.
nonisolated enum SizeConverter {

    // MARK: Parte de arriba

    static func topLetter(chestCm: Double, sizing: SizingProfile) -> String {
        let limits: [Double] = sizing == .menswear ? [88, 96, 104, 112, 120] : [82, 90, 98, 106, 114]
        let letters = ["XS", "S", "M", "L", "XL", "XXL"]
        let index = limits.firstIndex { chestCm < $0 } ?? limits.count
        return letters[index]
    }

    static func topEU(chestCm: Double, sizing: SizingProfile) -> Int {
        switch sizing {
        case .menswear: Int((chestCm / 4).rounded(.down)) * 2
        case .womenswear: max(32, 34 + 2 * Int(((chestCm - 80) / 4).rounded(.down)))
        }
    }

    static func topUS(chestCm: Double, sizing: SizingProfile) -> Int {
        switch sizing {
        case .menswear: Int((chestCm / 2.54).rounded(.down))
        case .womenswear: max(0, topEU(chestCm: chestCm, sizing: sizing) - 30)
        }
    }

    // MARK: Pantalones

    static func trousersEU(waistCm: Double?, hipCm: Double?, sizing: SizingProfile) -> Int? {
        switch sizing {
        case .menswear:
            guard let waistCm else { return nil }
            return Int((waistCm / 4).rounded()) * 2
        case .womenswear:
            guard let hipCm else { return nil }
            return max(32, 36 + 2 * Int(((hipCm - 92) / 4).rounded(.down)))
        }
    }

    /// Talla de vaquero «W/L» en pulgadas: «33/32».
    static func jeans(waistCm: Double, inseamCm: Double?) -> String {
        let waist = Int((waistCm / 2.54).rounded())
        guard let inseamCm else { return "W\(waist)" }
        return "\(waist)/\(Int((inseamCm / 2.54).rounded()))"
    }

    // MARK: Calzado

    static func shoeEU(footCm: Double) -> Int {
        Int(((footCm + 1.5) * 1.5).rounded())
    }

    /// Las tablas de las grandes marcas deportivas suben una talla US por centímetro de pie.
    static func shoeUS(footCm: Double, sizing: SizingProfile) -> Double {
        roundToHalf(footCm - (sizing == .menswear ? 18 : 17))
    }

    static func shoeUK(footCm: Double, sizing: SizingProfile) -> Double {
        let us = shoeUS(footCm: footCm, sizing: sizing)
        return sizing == .menswear ? us - 1 : us - 2.5
    }

    // MARK: Resumen

    static func recommendations(chestCm: Double?, waistCm: Double?, hipCm: Double?,
                                inseamCm: Double?, footCm: Double?, sizing: SizingProfile) -> [SizeRecommendation] {
        var result: [SizeRecommendation] = []
        if let chestCm {
            result.append(SizeRecommendation(
                id: "tops", title: "Camisetas y jerséis",
                size: topLetter(chestCm: chestCm, sizing: sizing),
                equivalents: "EU \(topEU(chestCm: chestCm, sizing: sizing)) · US \(topUS(chestCm: chestCm, sizing: sizing))"))
        }
        if let eu = trousersEU(waistCm: waistCm, hipCm: hipCm, sizing: sizing) {
            let jeansSize = waistCm.map { "Vaqueros \(jeans(waistCm: $0, inseamCm: inseamCm))" }
            result.append(SizeRecommendation(
                id: "trousers", title: "Pantalones", size: "EU \(eu)",
                equivalents: jeansSize ?? ""))
        }
        if let footCm {
            result.append(SizeRecommendation(
                id: "shoes", title: "Calzado", size: "EU \(shoeEU(footCm: footCm))",
                equivalents: "US \(format(shoeUS(footCm: footCm, sizing: sizing))) · UK \(format(shoeUK(footCm: footCm, sizing: sizing)))"))
        }
        return result
    }

    // MARK: ¿Me queda bien?

    /// Compara el contorno de la prenda (el doble de la medida en plano) con el del cuerpo.
    static func fit(category: GarmentCategory, chestWidthCm: Double?, waistWidthCm: Double?,
                    bodyChestCm: Double?, bodyWaistCm: Double?) -> FitAssessment? {
        switch category.bodyZone {
        case .upper:
            guard let chestWidthCm, let bodyChestCm else { return nil }
            let ease = chestWidthCm * 2 - bodyChestCm
            // Las prendas de abrigo se llevan encima de otras: necesitan más holgura.
            let shift: Double = category.isOuterwear ? 4 : 0
            let result: FitResult = switch ease - shift {
            case ..<(-2): .tooSmall
            case ..<4: .snug
            case ...16: .good
            case ...26: .loose
            default: .tooBig
            }
            return FitAssessment(result: result, bodyPart: "pecho", bodyCm: bodyChestCm, easeCm: ease)
        case .lower:
            guard let waistWidthCm, let bodyWaistCm else { return nil }
            let ease = waistWidthCm * 2 - bodyWaistCm
            let result: FitResult = switch ease {
            case ..<(-3): .tooSmall
            case ..<0: .snug
            case ...5: .good
            case ...10: .loose
            default: .tooBig
            }
            return FitAssessment(result: result, bodyPart: "cintura", bodyCm: bodyWaistCm, easeCm: ease)
        case .feet, .none:
            return nil
        }
    }

    // MARK: Utilidades

    static func roundToHalf(_ value: Double) -> Double { (value * 2).rounded() / 2 }

    /// «10», «9,5» según el idioma del dispositivo.
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension Double {
    /// «98 cm», «27,5 cm»
    nonisolated var centimeters: String { "\(SizeConverter.format(self)) cm" }
}
