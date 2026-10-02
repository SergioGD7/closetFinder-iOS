import Foundation
import SwiftData

/// Medidas corporales de una persona de la casa.
@Model
nonisolated final class BodyProfile {
    var uuid: UUID = UUID()
    var name: String = ""
    var sizingRaw: String = SizingProfile.menswear.rawValue
    var heightCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipCm: Double?
    var inseamCm: Double?
    var footCm: Double?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Garment.owner)
    var garments: [Garment]? = []

    init(name: String, sizing: SizingProfile = .menswear) {
        self.name = name
        self.sizingRaw = sizing.rawValue
    }

    var sizing: SizingProfile {
        get { SizingProfile(rawValue: sizingRaw) ?? .menswear }
        set { sizingRaw = newValue.rawValue }
    }

    var initial: String { name.first.map { String($0).uppercased() } ?? "?" }

    func value(of measurement: BodyMeasurement) -> Double? {
        switch measurement {
        case .height: heightCm
        case .chest: chestCm
        case .waist: waistCm
        case .hip: hipCm
        case .inseam: inseamCm
        case .foot: footCm
        }
    }

    func setValue(_ value: Double?, of measurement: BodyMeasurement) {
        switch measurement {
        case .height: heightCm = value
        case .chest: chestCm = value
        case .waist: waistCm = value
        case .hip: hipCm = value
        case .inseam: inseamCm = value
        case .foot: footCm = value
        }
    }

    var recommendations: [SizeRecommendation] {
        SizeConverter.recommendations(chestCm: chestCm, waistCm: waistCm, hipCm: hipCm,
                                      inseamCm: inseamCm, footCm: footCm, sizing: sizing)
    }
}

nonisolated enum BodyMeasurement: String, CaseIterable, Identifiable, Sendable {
    case height, chest, waist, hip, inseam, foot

    var id: Self { self }

    var title: String {
        switch self {
        case .height: "Altura"
        case .chest: "Pecho"
        case .waist: "Cintura"
        case .hip: "Cadera"
        case .inseam: "Entrepierna"
        case .foot: "Pie"
        }
    }

    var howTo: String {
        switch self {
        case .height: "Descalzo, de pie contra la pared."
        case .chest: "Contorno por la parte más ancha, bajo las axilas."
        case .waist: "Contorno a la altura del ombligo, sin apretar."
        case .hip: "Contorno por la parte más ancha de la cadera."
        case .inseam: "Del tiro del pantalón al suelo, por dentro de la pierna."
        case .foot: "Del talón a la punta del dedo más largo."
        }
    }
}
