import Foundation

/// Sección horizontal elíptica del cuerpo o de una prenda, en metros.
nonisolated struct Ellipse: Equatable, Sendable {
    /// Semiancho (eje x, de lado a lado).
    var a: Float
    /// Semifondo (eje z, de delante a atrás).
    var b: Float

    /// Perímetro (aproximación de Ramanujan, error < 0,01 % para estas proporciones).
    var circumference: Float {
        let h = (a - b) * (a - b) / ((a + b) * (a + b))
        return .pi * (a + b) * (1 + 3 * h / (10 + (4 - 3 * h).squareRoot()))
    }

    /// Elipse con un perímetro dado y una proporción ancho/fondo dada.
    static func with(circumference: Float, ratio: Float) -> Ellipse {
        let unit = Ellipse(a: ratio, b: 1).circumference
        let b = circumference / unit
        return Ellipse(a: ratio * b, b: b)
    }

    func scaled(toCircumference target: Float) -> Ellipse {
        let k = target / circumference
        return Ellipse(a: a * k, b: b * k)
    }

    func inflated(by gap: Float) -> Ellipse { Ellipse(a: a + gap, b: b + gap) }

    static func circle(_ radius: Float) -> Ellipse { Ellipse(a: radius, b: radius) }
}

/// Una sección a una altura `y` (metros desde el suelo).
nonisolated struct Ring: Equatable, Sendable {
    var y: Float
    var shape: Ellipse
}

/// Maniquí paramétrico construido con las medidas de una persona.
///
/// Las alturas de cada parte del cuerpo siguen proporciones antropométricas habituales
/// (en fracciones de la altura total). Las secciones del torso se calculan para que su
/// perímetro sea exactamente el contorno medido de pecho, cintura y cadera.
nonisolated struct BodyShape: Sendable {

    /// Medidas de entrada en centímetros. Las que falten se rellenan con valores típicos.
    struct Input: Sendable {
        var heightCm: Double?
        var chestCm: Double?
        var waistCm: Double?
        var hipCm: Double?
        var inseamCm: Double?
        var footCm: Double?
        var sizing: SizingProfile = .menswear
        /// Ancho entre hombros / altura, medido en una foto (si la hay).
        var shoulderRatio: Double?
        /// Ancho entre caderas / altura, medido en una foto (si la hay).
        var hipRatio: Double?
    }

    let height: Float
    let chest: Float
    let waist: Float
    let hip: Float
    let inseam: Float
    let foot: Float
    let shoulderWidth: Float
    let hipJointSpacing: Float
    let sizing: SizingProfile
    /// Qué medidas se han rellenado con valores típicos.
    let assumed: Set<BodyMeasurement>

    init(_ input: Input) {
        let defaults: (h: Double, chest: Double, waist: Double, hip: Double, inseam: Double, foot: Double) =
            input.sizing == .menswear ? (175, 98, 84, 100, 80, 26.5) : (163, 90, 72, 98, 76, 24)
        let h = input.heightCm ?? defaults.h
        let scale = h / defaults.h
        var assumed = Set<BodyMeasurement>()
        func value(_ measured: Double?, _ fallback: Double, _ measurement: BodyMeasurement) -> Float {
            if let measured { return Float(measured / 100) }
            assumed.insert(measurement)
            return Float(fallback * scale / 100)
        }
        if input.heightCm == nil { assumed.insert(.height) }
        height = Float(h / 100)
        chest = value(input.chestCm, defaults.chest, .chest)
        waist = value(input.waistCm, defaults.waist, .waist)
        hip = value(input.hipCm, defaults.hip, .hip)
        inseam = value(input.inseamCm, defaults.inseam, .inseam)
        foot = value(input.footCm, defaults.foot, .foot)
        sizing = input.sizing
        self.assumed = assumed

        let defaultShoulderRatio = input.sizing == .menswear ? 0.235 : 0.22
        shoulderWidth = Float(input.shoulderRatio.map { $0 + 0.035 } ?? defaultShoulderRatio) * height
        let defaultHipRatio = input.sizing == .menswear ? 0.105 : 0.115
        hipJointSpacing = Float(input.hipRatio ?? defaultHipRatio) * height
    }

    // MARK: Alturas (metros desde el suelo)

    var yAnkle: Float { 0.045 * height }
    var yKnee: Float { 0.285 * height }
    var yCrotch: Float { min(inseam, 0.52 * height) }
    var yHip: Float { yCrotch + 0.055 * height }
    var yWaist: Float { max(0.61 * height, yHip + 0.06) }
    var yChest: Float { 0.72 * height }
    var yArmpit: Float { 0.755 * height }
    var yShoulder: Float { 0.815 * height }
    var yNeckBase: Float { 0.84 * height }
    var yChin: Float { 0.87 * height }
    var headCenterY: Float { 0.935 * height }
    var headRadius: Float { 0.062 * height }

    // MARK: Torso

    private var chestRatio: Float { sizing == .menswear ? 1.45 : 1.35 }
    private var hipRatioAB: Float { sizing == .menswear ? 1.25 : 1.35 }

    /// Secciones clave del torso, de abajo arriba.
    var torsoKeyRings: [Ring] {
        let hipShape = Ellipse.with(circumference: hip, ratio: hipRatioAB)
        let chestShape = Ellipse.with(circumference: chest, ratio: chestRatio)
        let neck = Float(0.042) * height
        // En la ingle, el torso se estrecha hasta el arranque de las dos piernas.
        let thigh = legRadius(at: yCrotch)
        return [
            Ring(y: yCrotch - 0.01, shape: Ellipse(a: legOffsetX + thigh * 0.8, b: thigh * 1.05)),
            Ring(y: yHip, shape: hipShape),
            Ring(y: yWaist, shape: .with(circumference: waist, ratio: 1.3)),
            Ring(y: yChest, shape: chestShape),
            Ring(y: yArmpit, shape: Ellipse(a: max(chestShape.a * 1.02, shoulderWidth * 0.44), b: chestShape.b * 0.92)),
            Ring(y: yShoulder, shape: Ellipse(a: shoulderWidth / 2, b: chestShape.b * 0.62)),
            Ring(y: yNeckBase, shape: Ellipse(a: neck * 1.15, b: neck)),
        ]
    }

    /// Sección del torso a cualquier altura, interpolada suavemente (Catmull-Rom) entre las
    /// secciones clave. Fuera del torso devuelve la sección del extremo más cercano.
    func torsoShape(at y: Float) -> Ellipse {
        Self.interpolate(torsoKeyRings, at: y)
    }

    static func interpolate(_ keys: [Ring], at y: Float) -> Ellipse {
        guard let first = keys.first, let last = keys.last else { return .circle(0.1) }
        if y <= first.y { return first.shape }
        if y >= last.y { return last.shape }
        let i = keys.lastIndex { $0.y <= y } ?? 0
        let p1 = keys[i], p2 = keys[min(i + 1, keys.count - 1)]
        let p0 = keys[max(i - 1, 0)], p3 = keys[min(i + 2, keys.count - 1)]
        let t = (y - p1.y) / max(p2.y - p1.y, 0.0001)
        func spline(_ v0: Float, _ v1: Float, _ v2: Float, _ v3: Float) -> Float {
            let t2 = t * t, t3 = t2 * t
            let value = 0.5 * (2 * v1 + (-v0 + v2) * t + (2 * v0 - 5 * v1 + 4 * v2 - v3) * t2 + (-v0 + 3 * v1 - 3 * v2 + v3) * t3)
            // Sin pasarse de los valores vecinos, para que no salgan bultos.
            return min(max(value, min(v1, v2) * 0.97), max(v1, v2) * 1.03)
        }
        return Ellipse(
            a: spline(p0.shape.a, p1.shape.a, p2.shape.a, p3.shape.a),
            b: spline(p0.shape.b, p1.shape.b, p2.shape.b, p3.shape.b))
    }

    // MARK: Piernas y brazos

    /// Distancia del centro de cada pierna al eje del cuerpo: el borde exterior del muslo
    /// coincide con el lateral de la cadera. Con foto, se ajusta un poco a su separación real.
    var legOffsetX: Float {
        let fromHip = Ellipse.with(circumference: hip, ratio: hipRatioAB).a - legRadius(at: yCrotch) * 0.95
        let fromPhoto = hipJointSpacing / 2
        return max(0.05, fromHip * 0.8 + min(fromPhoto, fromHip * 1.15) * 0.2)
    }

    /// Radio de la pierna a una altura (de la ingle al tobillo).
    func legRadius(at y: Float) -> Float {
        let thigh = 0.6 * hip / (2 * .pi)
        let knee = 0.37 * hip / (2 * .pi)
        let calf = 0.38 * hip / (2 * .pi)
        let ankle = Float(0.034) * height / 1.75
        let keys: [(Float, Float)] = [
            (yAnkle, ankle), (yKnee - 0.09 * height / 1.75, calf), (yKnee, knee),
            (yCrotch - 0.04, thigh * 0.97), (yCrotch + 0.06, thigh),
        ]
        if y <= keys[0].0 { return keys[0].1 }
        for (lower, upper) in zip(keys, keys.dropFirst()) where y <= upper.0 {
            let t = (y - lower.0) / (upper.0 - lower.0)
            let smooth = t * t * (3 - 2 * t)
            return lower.1 + (upper.1 - lower.1) * smooth
        }
        return keys[keys.count - 1].1
    }

    /// Ángulo de los brazos respecto a la vertical (postura en «A»).
    var armAngle: Float { 0.2 }
    var upperArmLength: Float { 0.186 * height }
    var forearmLength: Float { 0.146 * height }
    var armLength: Float { upperArmLength + forearmLength }

    /// Hombro (articulación) del brazo derecho del maniquí (x positiva).
    var shoulderJoint: SIMD3<Float> { SIMD3(shoulderWidth / 2 - 0.035 * height / 1.75, yShoulder - 0.025 * height / 1.75, 0) }

    /// Radio del brazo a una distancia `d` desde el hombro.
    func armRadius(atDistance d: Float) -> Float {
        let upper = 0.3 * chest / (2 * .pi)
        let elbow = upper * 0.72
        let wrist = upper * 0.56
        if d <= upperArmLength {
            let t = d / upperArmLength
            return upper + (elbow - upper) * t
        }
        let t = min((d - upperArmLength) / forearmLength, 1)
        return elbow + (wrist - elbow) * t
    }
}
