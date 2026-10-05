import Foundation

/// Instrucciones de lavado de una prenda, como vienen en la etiqueta.
/// Dentro de cada grupo (lavado, lejía, secadora, plancha y limpieza en seco) solo vale una.
nonisolated enum CareInstruction: String, CaseIterable, Codable, Identifiable, Sendable {
    case handWash, wash30, wash40, wash60, noWash
    case noBleach
    case tumbleDry, noTumbleDry
    case ironLow, ironMedium, ironHigh, noIron
    case dryClean, noDryClean

    var id: Self { self }

    enum Group: Sendable {
        case wash, bleach, dryer, iron, dryClean
    }

    var group: Group {
        switch self {
        case .handWash, .wash30, .wash40, .wash60, .noWash: .wash
        case .noBleach: .bleach
        case .tumbleDry, .noTumbleDry: .dryer
        case .ironLow, .ironMedium, .ironHigh, .noIron: .iron
        case .dryClean, .noDryClean: .dryClean
        }
    }

    var title: String {
        switch self {
        case .handWash: String(localized: "Lavar a mano")
        case .wash30: String(localized: "Lavar a 30 °C")
        case .wash40: String(localized: "Lavar a 40 °C")
        case .wash60: String(localized: "Lavar a 60 °C")
        case .noWash: String(localized: "No lavar")
        case .noBleach: String(localized: "Sin lejía")
        case .tumbleDry: String(localized: "Secadora")
        case .noTumbleDry: String(localized: "Sin secadora")
        case .ironLow: String(localized: "Plancha baja")
        case .ironMedium: String(localized: "Plancha media")
        case .ironHigh: String(localized: "Plancha alta")
        case .noIron: String(localized: "No planchar")
        case .dryClean: String(localized: "Limpieza en seco")
        case .noDryClean: String(localized: "Sin limpieza en seco")
        }
    }

    var symbol: String {
        switch self {
        case .handWash: "hand.raised"
        case .wash30, .wash40, .wash60: "washer"
        case .tumbleDry: "dryer"
        case .ironLow: "thermometer.low"
        case .ironMedium: "thermometer.medium"
        case .ironHigh: "thermometer.high"
        case .dryClean: "sparkles"
        case .noWash, .noBleach, .noTumbleDry, .noIron, .noDryClean: "nosign"
        }
    }

    /// Ordenadas como en la etiqueta y sin repetir grupo (gana la última que se añadió).
    static func sorted(_ instructions: [CareInstruction]) -> [CareInstruction] {
        var byGroup: [Group: CareInstruction] = [:]
        for instruction in instructions { byGroup[instruction.group] = instruction }
        return allCases.filter { byGroup[$0.group] == $0 }
    }

    /// Activa o desactiva una instrucción, quitando la otra del mismo grupo.
    static func toggling(_ instruction: CareInstruction, in current: [CareInstruction]) -> [CareInstruction] {
        if current.contains(instruction) { return current.filter { $0 != instruction } }
        return sorted(current.filter { $0.group != instruction.group } + [instruction])
    }
}
