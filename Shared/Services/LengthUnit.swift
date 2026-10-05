import Foundation

/// Unidad elegida en Ajustes para las medidas. Por defecto, la de la región del iPhone.
nonisolated enum LengthUnitPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic, centimeters, inches

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automática")
        case .centimeters: String(localized: "Centímetros")
        case .inches: String(localized: "Pulgadas")
        }
    }
}

/// Centímetros o pulgadas. Las medidas se guardan siempre en centímetros: la unidad solo
/// cambia cómo se muestran y cómo se interpreta lo que escribe el usuario.
nonisolated enum LengthUnit: Sendable, Equatable {
    case centimeters, inches

    static let storageKey = "lengthUnit"
    static let centimetersPerInch = 2.54

    /// Estados Unidos y Reino Unido miden la ropa en pulgadas.
    static func resolve(_ preference: LengthUnitPreference, locale: Locale = .current) -> LengthUnit {
        switch preference {
        case .centimeters: .centimeters
        case .inches: .inches
        case .automatic: locale.measurementSystem == .metric ? .centimeters : .inches
        }
    }

    static var current: LengthUnit {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return resolve(LengthUnitPreference(rawValue: stored) ?? .automatic)
    }

    /// «cm» o «in» (en francés, «po»).
    var symbol: String {
        switch self {
        case .centimeters: "cm"
        case .inches: String(localized: "unit.inches.symbol", defaultValue: "in")
        }
    }

    func value(fromCentimeters centimeters: Double) -> Double {
        self == .inches ? centimeters / Self.centimetersPerInch : centimeters
    }

    func centimeters(from value: Double) -> Double {
        self == .inches ? value * Self.centimetersPerInch : value
    }

    /// Número para un campo de texto: «98» o «38,6».
    func editText(_ centimeters: Double) -> String {
        SizeConverter.format(value(fromCentimeters: centimeters))
    }

    /// «98 cm» o «38,6 in»
    func format(_ centimeters: Double) -> String {
        "\(editText(centimeters)) \(symbol)"
    }

    /// Lo que escribe el usuario («38,5» o «38.5»), pasado a centímetros.
    func parse(_ text: String?) -> Double? {
        guard let value = Self.parseNumber(text) else { return nil }
        return centimeters(from: value)
    }

    static func parseNumber(_ text: String?) -> Double? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }
}

extension Double {
    /// La medida (en centímetros) en la unidad elegida: «98 cm», «38,6 in».
    nonisolated var lengthText: String { LengthUnit.current.format(self) }
}
