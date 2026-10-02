import Foundation

/// Forma 3D de una prenda puesta sobre un `BodyShape`, calculada con las medidas de la prenda.
///
/// La prenda nunca atraviesa el cuerpo: donde es más estrecha que el cuerpo se ajusta a él (y
/// el resumen avisa de que queda pequeña); donde es más ancha, cuelga con su propio contorno.
nonisolated struct GarmentShell: Sendable {

    /// Medidas de la prenda en centímetros (las de la ficha, en plano).
    struct Input: Sendable {
        var category: GarmentCategory
        var chestWidthCm: Double?
        var waistWidthCm: Double?
        var lengthCm: Double?
        var sleeveCm: Double?
        var inseamCm: Double?
        /// Talla escrita en la ficha («43», «M»…), para comparar el calzado.
        var size: String = ""
    }

    enum Style: Equatable, Sendable {
        case top, bottom, skirt, shoes, unsupported
    }

    /// Tubo (manga o pernera). Los anillos están en coordenadas locales: el eje del tubo es `y`.
    struct Tube: Sendable {
        var origin: SIMD3<Float>
        /// Giro sobre el eje z (brazos en «A»).
        var angle: Float
        var rings: [Ring]
    }

    enum Level: Sendable { case good, warning, info }

    struct FitLine: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let detail: String
        let level: Level
    }

    let style: Style
    /// Cuerpo de la prenda (torso, cadera o falda), de abajo arriba.
    var shell: [Ring] = []
    var tubes: [Tube] = []
    /// Las mangas no llevan la foto (que es de frente); se pintan del color de la prenda.
    var tubesUsePhoto = false
    var yTop: Float = 0
    var yHem: Float = 0
    /// Extensión horizontal sobre la que se proyecta la foto de la prenda (vista de frente).
    var photoMinX: Float = -0.3
    var photoMaxX: Float = 0.3
    /// Parte central de la foto que corresponde al cuerpo de la prenda (sin las mangas).
    var photoCropWidth: Float = 1
    var lines: [FitLine] = []

    static func style(for category: GarmentCategory) -> Style {
        switch category {
        case .tShirt, .shirt, .sweater, .jacket, .coat, .blazer, .dress: .top
        case .trousers, .shorts, .swimwear, .underwear: .bottom
        case .skirt: .skirt
        case .shoes: .shoes
        case .accessories: .unsupported
        }
    }

    init(_ input: Input, on body: BodyShape) {
        style = Self.style(for: input.category)
        switch style {
        case .top: buildTop(input, body)
        case .bottom: buildBottom(input, body)
        case .skirt: buildSkirt(input, body)
        case .shoes: buildShoes(input, body)
        case .unsupported: break
        }
    }

    // MARK: Parte de arriba

    private mutating func buildTop(_ input: Input, _ body: BodyShape) {
        let category = input.category
        let defaults: (length: Float, sleeve: Float, ease: Float) = switch category {
        case .tShirt: (0.70, 0.21, 0.10)
        case .shirt: (0.76, 0.62, 0.12)
        case .sweater: (0.68, 0.61, 0.12)
        case .jacket: (0.66, 0.63, 0.16)
        case .coat: (0.95, 0.64, 0.18)
        case .blazer: (0.75, 0.63, 0.14)
        default: (0.95, 0, 0.07) // vestido
        }
        let flare: Float = category == .dress ? 0.35 : (category == .coat ? 0.12 : 0)
        let garmentChest = input.chestWidthCm.map { Float($0) * 2 / 100 } ?? body.chest + defaults.ease
        let looseness = max(0, garmentChest - body.chest)
        let length = input.lengthCm.map { Float($0) / 100 } ?? defaults.length

        yTop = body.yNeckBase
        yHem = max(body.yNeckBase - length, 0.02)

        var rings: [Ring] = []
        var y = yHem
        while y <= yTop + 0.0001 {
            // Por debajo de la cadera, la prenda cuelga desde la cadera.
            let base = body.torsoShape(at: max(y, body.yHip)).inflated(by: 0.006)
            let target: Float
            if y >= body.yArmpit {
                target = base.circumference + looseness * 0.15
            } else {
                let belowHip = body.yHip - y
                let flareAmount = belowHip > 0 ? flare * belowHip / max(body.yHip - yHem, 0.01) : 0
                target = max(base.circumference, garmentChest * (1 + flareAmount))
            }
            rings.append(Ring(y: y, shape: base.scaled(toCircumference: target)))
            y += 0.01
        }
        shell = rings
        let maxA = rings.map(\.shape.a).max() ?? 0.25
        photoMinX = -maxA
        photoMaxX = maxA
        photoCropWidth = category == .dress ? 0.8 : 0.58

        // Mangas
        let sleeveLength = min(input.sleeveCm.map { Float($0) / 100 } ?? defaults.sleeve, body.armLength + 0.12)
        if sleeveLength > 0.03 {
            let ease = 0.012 + looseness * 0.08
            var sleeveRings: [Ring] = []
            var d: Float = -0.03
            while d <= sleeveLength + 0.0001 {
                sleeveRings.append(Ring(y: -d, shape: .circle(body.armRadius(atDistance: max(d, 0)) + ease)))
                d += 0.015
            }
            let joint = body.shoulderJoint
            tubes = [
                Tube(origin: joint, angle: body.armAngle, rings: sleeveRings),
                Tube(origin: SIMD3(-joint.x, joint.y, joint.z), angle: -body.armAngle, rings: sleeveRings),
            ]
        }

        // Resumen
        lines.append(chestLine(input, body, garmentChest: garmentChest))
        lines.append(FitLine(title: String(localized: "Largo"), detail: Self.describeHem(yHem, on: body), level: .info))
        if sleeveLength > 0.03 {
            lines.append(Self.sleeveLine(sleeveLength, body, measured: input.sleeveCm != nil))
        }
    }

    private func chestLine(_ input: Input, _ body: BodyShape, garmentChest: Float) -> FitLine {
        guard input.chestWidthCm != nil else {
            return FitLine(title: String(localized: "Pecho"), detail: String(localized: "Sin medida de la prenda: se muestra con una holgura típica"), level: .info)
        }
        let fit = SizeConverter.fit(category: input.category, chestWidthCm: input.chestWidthCm, waistWidthCm: nil,
                                    bodyChestCm: Double(body.chest * 100), bodyWaistCm: nil)
        let ease = Int(((garmentChest - body.chest) * 100).rounded())
        let easeText = "\(ease >= 0 ? "+" : "")\(ease) cm"
        let verdict = fit?.result.title ?? ""
        let detail = String(localized: "\(verdict) · prenda \(Self.cm(garmentChest)), tú \(Self.cm(body.chest)) (\(easeText))")
        return FitLine(title: String(localized: "Pecho"), detail: detail, level: fit?.result == .good ? .good : .warning)
    }

    // MARK: Parte de abajo

    private mutating func buildBottom(_ input: Input, _ body: BodyShape) {
        let category = input.category
        let defaultInseam: Float = switch category {
        case .trousers: body.inseam - 0.01
        case .shorts: 0.2
        case .swimwear: 0.12
        default: 0.04 // ropa interior
        }
        let garmentWaist = input.waistWidthCm.map { Float($0) * 2 / 100 }
        yTop = body.yWaist - 0.035
        let rise = yTop - body.yCrotch
        let legInseam = input.inseamCm.map { Float($0) / 100 }
            ?? input.lengthCm.map { Float($0) / 100 - rise }
            ?? defaultInseam
        let unclampedHem = body.yCrotch - legInseam
        yHem = max(unclampedHem, 0.008)

        // Cadera y tiro. Por debajo de la ingle, la sección abraza las dos perneras para que no
        // se vea un escalón entre la cadera y las piernas.
        let thigh = body.legRadius(at: body.yCrotch) + 0.016
        let bridge = Ellipse(a: body.legOffsetX + thigh, b: thigh + 0.004)
        var rings: [Ring] = [Ring(y: body.yCrotch - 0.05, shape: bridge), Ring(y: body.yCrotch - 0.02, shape: bridge)]
        var y = body.yCrotch
        // De la cintura a la ingle, los costados bajan en línea recta (como un pantalón de
        // verdad), sin meterse nunca dentro del cuerpo.
        let waistband = body.torsoShape(at: yTop).inflated(by: 0.01)
        while y <= yTop + 0.0001 {
            let t = (y - body.yCrotch) / max(yTop - body.yCrotch, 0.01)
            let straight = Ellipse(a: bridge.a + (waistband.a - bridge.a) * t, b: bridge.b + (waistband.b - bridge.b) * t)
            let skin = body.torsoShape(at: y).inflated(by: 0.008)
            let base = Ellipse(a: max(straight.a, skin.a), b: max(straight.b, skin.b))
            var target = base.circumference + 0.008
            if let garmentWaist, y > yTop - 0.03 { target = max(base.circumference, garmentWaist) }
            rings.append(Ring(y: y, shape: base.scaled(toCircumference: target)))
            y += 0.01
        }
        shell = rings

        // Perneras rectas: se estrechan poco hacia el bajo.
        let hemRadius = category == .trousers
            ? max(body.legRadius(at: yHem) + 0.02, thigh * 0.62)
            : thigh + 0.008
        var legRings: [Ring] = []
        y = yHem
        // Las perneras acaban dentro de la pieza que las une, para que no asomen sus bordes.
        let top = body.yCrotch - 0.03
        while y <= top + 0.0001 {
            let t = (y - yHem) / max(top - yHem, 0.01)
            let radius = max(body.legRadius(at: y) + 0.012, hemRadius + (thigh - hemRadius) * t)
            legRings.append(Ring(y: y, shape: .circle(radius)))
            y += 0.015
        }
        tubes = [
            Tube(origin: SIMD3(body.legOffsetX, 0, 0), angle: 0, rings: legRings),
            Tube(origin: SIMD3(-body.legOffsetX, 0, 0), angle: 0, rings: legRings),
        ]
        tubesUsePhoto = true
        let outer = body.legOffsetX + thigh
        let maxA = rings.map(\.shape.a).max() ?? outer
        photoMinX = -max(outer, maxA)
        photoMaxX = max(outer, maxA)
        photoCropWidth = 1

        // Resumen
        if let garmentWaist {
            let fit = SizeConverter.fit(category: category, chestWidthCm: nil, waistWidthCm: input.waistWidthCm,
                                        bodyChestCm: nil, bodyWaistCm: Double(body.waist * 100))
            let ease = Int(((garmentWaist - body.waist) * 100).rounded())
            let easeText = "\(ease >= 0 ? "+" : "")\(ease) cm"
            let verdict = fit?.result.title ?? ""
            lines.append(FitLine(title: String(localized: "Cintura"),
                                 detail: String(localized: "\(verdict) · prenda \(Self.cm(garmentWaist)), tú \(Self.cm(body.waist)) (\(easeText))"),
                                 level: fit?.result == .good ? .good : .warning))
        } else {
            lines.append(FitLine(title: String(localized: "Cintura"), detail: String(localized: "Sin medida de la prenda: se muestra con una holgura típica"), level: .info))
        }
        if category == .trousers {
            // Un pantalón largo está bien si el bajo queda entre el suelo y el tobillo
            // (con zapato, cae sobre él).
            let detail: String
            let level: Level
            if unclampedHem < -0.015 {
                (detail, level) = (String(localized: "Te sobran \(Int((-unclampedHem * 100).rounded())) cm de largo"), .warning)
            } else if unclampedHem > body.yAnkle + 0.02 {
                (detail, level) = (String(localized: "Se queda \(Int(((unclampedHem - body.yAnkle) * 100).rounded())) cm por encima del tobillo"), .warning)
            } else {
                (detail, level) = (String(localized: "Largo justo: cae sobre el zapato"), .good)
            }
            lines.append(FitLine(title: String(localized: "Largo"), detail: detail, level: level))
        } else {
            lines.append(FitLine(title: String(localized: "Largo"), detail: Self.describeHem(yHem, on: body), level: .info))
        }
    }

    // MARK: Falda

    private mutating func buildSkirt(_ input: Input, _ body: BodyShape) {
        let garmentWaist = input.waistWidthCm.map { Float($0) * 2 / 100 }
        let length = input.lengthCm.map { Float($0) / 100 } ?? 0.55
        yTop = body.yWaist
        yHem = max(yTop - length, 0.02)
        let hipShape = body.torsoShape(at: body.yHip).inflated(by: 0.012)
        var rings: [Ring] = []
        var y = yHem
        while y <= yTop + 0.0001 {
            let base = body.torsoShape(at: max(y, body.yHip)).inflated(by: 0.008)
            var target = base.circumference
            if y < body.yHip {
                let t = (body.yHip - y) / max(body.yHip - yHem, 0.01)
                target = hipShape.circumference * (1 + 0.3 * t)
            }
            if let garmentWaist, y > yTop - 0.03 { target = max(target, garmentWaist) }
            rings.append(Ring(y: y, shape: base.scaled(toCircumference: target)))
            y += 0.01
        }
        shell = rings
        let maxA = rings.map(\.shape.a).max() ?? 0.25
        photoMinX = -maxA
        photoMaxX = maxA
        lines.append(FitLine(title: String(localized: "Largo"), detail: Self.describeHem(yHem, on: body), level: .info))
    }

    // MARK: Calzado

    private mutating func buildShoes(_ input: Input, _ body: BodyShape) {
        let yours = SizeConverter.shoeEU(footCm: Double(body.foot * 100))
        let number = Double(input.size.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." })
        guard let number, (30...52).contains(number) else {
            lines.append(FitLine(title: String(localized: "Talla"), detail: String(localized: "Tu talla es la EU \(yours)"), level: .info))
            return
        }
        let difference = number - Double(yours)
        if abs(difference) < 0.75 {
            lines.append(FitLine(title: String(localized: "Talla"), detail: String(localized: "EU \(input.size): es tu talla"), level: .good))
        } else {
            let detail = difference > 0
                ? String(localized: "EU \(input.size): te quedará grande (la tuya es la \(yours))")
                : String(localized: "EU \(input.size): te quedará pequeña (la tuya es la \(yours))")
            lines.append(FitLine(title: String(localized: "Talla"), detail: detail, level: .warning))
        }
    }

    // MARK: Textos

    static func cm(_ meters: Float) -> String { "\(Int((meters * 100).rounded())) cm" }

    static func describeHem(_ y: Float, on body: BodyShape) -> String {
        switch y {
        case (body.yWaist + 0.03)...: String(localized: "Corta: por encima de la cintura")
        case (body.yHip - 0.02)...: String(localized: "Llega a la cadera")
        case (body.yCrotch - 0.06)...: String(localized: "Cubre la cadera")
        case (body.yKnee + 0.1)...: String(localized: "Llega a medio muslo")
        case (body.yKnee - 0.06)...: String(localized: "Llega a la rodilla")
        case (body.yAnkle + 0.12)...: String(localized: "Por debajo de la rodilla")
        default: String(localized: "Larga, hasta el tobillo")
        }
    }

    static func sleeveLine(_ length: Float, _ body: BodyShape, measured: Bool) -> FitLine {
        let difference = Int(((length - body.armLength) * 100).rounded())
        if length < body.upperArmLength * 0.8 {
            return FitLine(title: String(localized: "Manga"), detail: String(localized: "Manga corta"), level: .info)
        }
        guard measured else {
            return FitLine(title: String(localized: "Manga"), detail: String(localized: "Sin medida de la prenda: largo típico"), level: .info)
        }
        if abs(difference) <= 3 {
            return FitLine(title: String(localized: "Manga"), detail: String(localized: "Llega a la muñeca"), level: .good)
        }
        return difference < 0
            ? FitLine(title: String(localized: "Manga"), detail: String(localized: "Se queda \(-difference) cm antes de la muñeca"), level: .warning)
            : FitLine(title: String(localized: "Manga"), detail: String(localized: "Te sobran \(difference) cm de manga"), level: .warning)
    }
}
