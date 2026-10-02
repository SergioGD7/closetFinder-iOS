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

    // Probador 3D: datos sacados de una foto de cuerpo entero (la foto no se guarda).
    /// Distancia entre hombros / altura.
    var shoulderRatio: Double?
    /// Distancia entre caderas / altura.
    var hipRatio: Double?
    /// Tono de piel (r, g, b entre 0 y 1). Vacío si no hay foto.
    var skinTone: [Double] = []
    /// Cara recortada para la cabeza del maniquí (PNG).
    @Attribute(.externalStorage) var faceTexture: Data?

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

    var hasTryOnPhoto: Bool { faceTexture != nil || shoulderRatio != nil }

    func clearTryOnPhoto() {
        shoulderRatio = nil
        hipRatio = nil
        skinTone = []
        faceTexture = nil
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
        case .height: String(localized: "Altura")
        case .chest: String(localized: "Pecho")
        case .waist: String(localized: "Cintura")
        case .hip: String(localized: "Cadera")
        case .inseam: String(localized: "Entrepierna")
        case .foot: String(localized: "Pie")
        }
    }

    var howTo: String {
        switch self {
        case .height: String(localized: "Descalzo, de pie contra la pared.")
        case .chest: String(localized: "Contorno por la parte más ancha, bajo las axilas.")
        case .waist: String(localized: "Contorno a la altura del ombligo, sin apretar.")
        case .hip: String(localized: "Contorno por la parte más ancha de la cadera.")
        case .inseam: String(localized: "Del tiro del pantalón al suelo, por dentro de la pierna.")
        case .foot: String(localized: "Del talón a la punta del dedo más largo.")
        }
    }
}
