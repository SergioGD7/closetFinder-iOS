import Foundation
import ImageIO
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Fibra textil, reconocida en los idiomas en que suelen venir las etiquetas.
nonisolated enum Fiber: String, CaseIterable, Sendable {
    case cotton, polyester, wool, cashmere, linen, silk, viscose, lyocell, modal, elastane, polyamide, acrylic, leather

    /// En minúsculas, para componer «60 % algodón, 40 % poliéster».
    var title: String {
        switch self {
        case .cotton: String(localized: "fiber.cotton", defaultValue: "algodón")
        case .polyester: String(localized: "fiber.polyester", defaultValue: "poliéster")
        case .wool: String(localized: "fiber.wool", defaultValue: "lana")
        case .cashmere: String(localized: "fiber.cashmere", defaultValue: "cachemira")
        case .linen: String(localized: "fiber.linen", defaultValue: "lino")
        case .silk: String(localized: "fiber.silk", defaultValue: "seda")
        case .viscose: String(localized: "fiber.viscose", defaultValue: "viscosa")
        case .lyocell: String(localized: "fiber.lyocell", defaultValue: "lyocell")
        case .modal: String(localized: "fiber.modal", defaultValue: "modal")
        case .elastane: String(localized: "fiber.elastane", defaultValue: "elastano")
        case .polyamide: String(localized: "fiber.polyamide", defaultValue: "poliamida")
        case .acrylic: String(localized: "fiber.acrylic", defaultValue: "acrílico")
        case .leather: String(localized: "fiber.leather", defaultValue: "piel")
        }
    }

    /// Palabras en inglés, español, francés, alemán, italiano y portugués, sin acentos.
    var keywords: [String] {
        switch self {
        case .cotton: ["cotton", "algodon", "algodao", "coton", "baumwolle", "cotone", "co"]
        case .polyester: ["polyester", "poliester", "polyestere", "pes", "pl"]
        case .wool: ["wool", "lana", "laine", "wolle", "la", "merino", "wo"]
        case .cashmere: ["cashmere", "cachemira", "cachemire", "kaschmir", "cashmir", "caxemira"]
        case .linen: ["linen", "lino", "lin", "leinen", "linho", "li"]
        case .silk: ["silk", "seda", "soie", "seide", "seta"]
        case .viscose: ["viscose", "viscosa", "viskose", "rayon", "cv"]
        case .lyocell: ["lyocell", "tencel"]
        case .modal: ["modal", "md"]
        case .elastane: ["elastane", "elastano", "elasthanne", "elasthan", "spandex", "lycra", "ea", "el"]
        case .polyamide: ["polyamide", "poliamida", "polyamid", "poliammide", "nylon", "pa"]
        case .acrylic: ["acrylic", "acrilico", "acrylique", "polyacryl", "acrilica", "pan"]
        case .leather: ["leather", "piel", "cuir", "leder", "pelle", "couro"]
        }
    }

    static func matching(_ word: String) -> Fiber? {
        allCases.first { $0.keywords.contains(word) }
    }
}

nonisolated struct FiberShare: Equatable, Sendable {
    let fiber: Fiber
    let percent: Int
}

/// Lo que se ha podido leer en la etiqueta interior de una prenda.
nonisolated struct LabelInfo: Equatable, Sendable {
    /// Talla principal: «M» o «38».
    var size: String?
    /// Otras tallas que trae la etiqueta: «EU 38 · UK 10 · US 6».
    var sizeEquivalents: String?
    var fibers: [FiberShare] = []
    var care: [CareInstruction] = []

    var isEmpty: Bool { size == nil && fibers.isEmpty && care.isEmpty }

    /// «100 % algodón», «60 % algodón, 40 % poliéster»
    var compositionText: String {
        fibers.map { share in
            let percent = (Double(share.percent) / 100).formatted(.percent.precision(.fractionLength(0)))
            return "\(percent) \(share.fiber.title)"
        }
        .joined(separator: ", ")
    }

    /// Completa lo que falte con otra lectura (la de Apple Intelligence).
    func filling(from other: LabelInfo) -> LabelInfo {
        var result = self
        if result.size == nil { result.size = other.size }
        if result.sizeEquivalents == nil { result.sizeEquivalents = other.sizeEquivalents }
        if result.fibers.isEmpty { result.fibers = other.fibers }
        if result.care.isEmpty { result.care = other.care }
        return result
    }
}

/// Interpreta el texto de una etiqueta: talla, composición e instrucciones de lavado.
/// Reglas sencillas y deterministas, pensadas para el formato habitual de las etiquetas.
nonisolated enum LabelParser {

    static func parse(_ lines: [String]) -> LabelInfo {
        var info = LabelInfo()
        let (size, equivalents) = parseSize(lines)
        info.size = size
        info.sizeEquivalents = equivalents
        info.fibers = parseFibers(lines.joined(separator: "\n"))
        info.care = parseCare(lines.joined(separator: "\n"))
        return info
    }

    /// Minúsculas y sin acentos, para comparar palabras en cualquier idioma.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: Talla

    static let letterSizes = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL", "2XL", "3XL", "4XL"]
    static let sizeWords: Set<String> = ["size", "talla", "taille", "grosse", "groesse", "taglia", "tamanho", "tam", "gr"]
    static let regions = ["EU", "EUR", "FR", "IT", "ES", "DE", "UK", "US", "USA", "MEX", "CN", "BR"]

    static func parseSize(_ lines: [String]) -> (size: String?, equivalents: String?) {
        var letter: String?
        var equivalents: [(region: String, value: String)] = []
        var loneNumber: String?

        for line in lines {
            let tokens = line.uppercased().split { !$0.isLetter && !$0.isNumber && $0 != "/" && $0 != "," && $0 != "." }.map(String.init)
            let lower = Set(tokens.map(normalize))
            // Una letra suelta solo cuenta en una línea corta o junto a «talla»: así no se confunde
            // con iniciales o códigos.
            if letter == nil, tokens.count <= 3 || !lower.isDisjoint(with: sizeWords) {
                letter = tokens.first { letterSizes.contains($0) }
            }
            // «EU 38», «UK:10», «US 6».
            for (index, token) in tokens.enumerated() where regions.contains(token) && index + 1 < tokens.count {
                let value = tokens[index + 1].replacingOccurrences(of: ",", with: ".")
                guard let number = Double(value), number > 0, number < 70 else { continue }
                let region = token == "EUR" ? "EU" : (token == "USA" ? "US" : token)
                if !equivalents.contains(where: { $0.region == region }) {
                    equivalents.append((region, SizeConverter.format(number)))
                }
            }
            // Un número solo en su línea («40»), sin grados: probablemente la talla europea.
            if loneNumber == nil, tokens.count == 1, !line.contains("°"), !line.contains("º"),
               let number = Int(tokens[0]), (32...58).contains(number) {
                loneNumber = tokens[0]
            }
        }

        let european = equivalents.first { ["EU", "FR", "ES", "IT", "DE"].contains($0.region) }?.value
        let size = letter ?? european ?? loneNumber
        let text = equivalents.isEmpty ? nil : equivalents.map { "\($0.region) \($0.value)" }.joined(separator: " · ")
        return (size, text)
    }

    // MARK: Composición

    static func parseFibers(_ text: String) -> [FiberShare] {
        let tokens = normalize(text.replacingOccurrences(of: "%", with: " % "))
            .split { !$0.isLetter && !$0.isNumber && $0 != "%" }.map(String.init)
        let percents = tokens.indices.filter { index in
            tokens[index] == "%" && index > 0 && Int(tokens[index - 1]).map { (1...100).contains($0) } == true
        }
        // Unas etiquetas ponen la fibra detrás («100% algodón») y otras delante («Baumwolle 100%»).
        // Lo decide el primer porcentaje: si va precedido de una fibra, todos lo van.
        func before(_ index: Int) -> Fiber? { index >= 2 ? Fiber.matching(tokens[index - 2]) : nil }
        func after(_ index: Int) -> Fiber? {
            tokens[(index + 1)..<min(index + 4, tokens.count)].lazy.compactMap(Fiber.matching).first
        }
        let fiberGoesFirst = percents.first.flatMap(before) != nil

        var shares: [Fiber: Int] = [:]
        var order: [Fiber] = []
        for index in percents {
            guard let percent = Int(tokens[index - 1]),
                  let fiber = fiberGoesFirst ? before(index) : (after(index) ?? before(index)) else { continue }
            if shares[fiber] == nil { order.append(fiber) }
            shares[fiber] = max(shares[fiber] ?? 0, percent)
        }
        return order
            .map { FiberShare(fiber: $0, percent: shares[$0] ?? 0) }
            .sorted { $0.percent > $1.percent }
    }

    // MARK: Lavado

    /// Frases de cada instrucción. Las negativas se comprueban antes que las positivas,
    /// porque «do not tumble dry» contiene «tumble dry».
    private static let negativeRules: [(CareInstruction, [String])] = [
        (.noWash, ["do not wash", "no lavar", "ne pas laver", "nicht waschen", "non lavare", "nao lavar"]),
        (.noBleach, ["do not bleach", "no usar lejia", "no lejia", "sin lejia", "ne pas blanchir", "nicht bleichen",
                     "non candeggiare", "nao usar alvejante", "nao branquear", "no bleach"]),
        (.noTumbleDry, ["do not tumble dry", "no usar secadora", "no secadora", "no secar en secadora", "ne pas secher en tambour",
                        "nicht im trockner", "nicht trocknergeeignet", "non asciugare in asciugatrice", "nao secar na maquina"]),
        (.noIron, ["do not iron", "no planchar", "ne pas repasser", "nicht bugeln", "non stirare", "nao passar"]),
        (.noDryClean, ["do not dry clean", "no limpiar en seco", "no lavar en seco", "ne pas nettoyer a sec",
                       "nicht chemisch reinigen", "non lavare a secco", "nao limpar a seco"]),
    ]

    private static let positiveRules: [(CareInstruction, [String])] = [
        (.handWash, ["hand wash", "lavar a mano", "lavado a mano", "lavage a la main", "handwasche", "lavare a mano", "lavar a mao"]),
        (.tumbleDry, ["tumble dry", "secadora", "sechage en tambour", "trockner", "asciugatrice"]),
        (.ironLow, ["iron low", "cool iron", "plancha baja", "planchar a baja", "planchado bajo", "repassage doux", "bugeln niedrig", "stirare a bassa"]),
        (.ironMedium, ["iron medium", "warm iron", "plancha media", "planchar a temperatura media", "repassage moyen", "stirare a media"]),
        (.ironHigh, ["iron high", "hot iron", "plancha alta", "repassage chaud", "stirare ad alta"]),
        (.dryClean, ["dry clean", "limpieza en seco", "limpiar en seco", "nettoyage a sec", "chemisch reinigen", "lavare a secco", "limpeza a seco"]),
    ]

    static func parseCare(_ text: String) -> [CareInstruction] {
        let normalized = normalize(text).replacingOccurrences(of: "\n", with: " ")
        var found: [CareInstruction] = []
        var groups = Set<CareInstruction.Group>()
        for (instruction, phrases) in negativeRules where phrases.contains(where: normalized.contains) {
            found.append(instruction)
            groups.insert(instruction.group)
        }
        for (instruction, phrases) in positiveRules
        where !groups.contains(instruction.group) && phrases.contains(where: normalized.contains) {
            found.append(instruction)
            groups.insert(instruction.group)
        }
        // Temperatura de lavado: «30°», «40 ºC», «wash at 60 c».
        if !groups.contains(.wash), let temperature = washTemperature(in: normalized) {
            found.append(temperature)
        }
        return CareInstruction.sorted(found)
    }

    private static func washTemperature(in text: String) -> CareInstruction? {
        let pattern = /(\d{2})\s*(?:°|º|o\s?c\b|c\b)/
        for match in text.matches(of: pattern) {
            switch Int(match.output.1) {
            case 30: return .wash30
            case 40: return .wash40
            case 60, 90, 95: return .wash60
            default: continue
            }
        }
        return nil
    }
}

/// Lee una foto de la etiqueta: reconoce el texto con Vision y lo interpreta. Con Apple
/// Intelligence (iOS 26+) completa lo que las reglas no hayan encontrado. Todo en el iPhone.
nonisolated enum LabelReader {

    @concurrent
    static func read(_ data: Data) async -> LabelInfo {
        let lines = recognizeText(in: data)
        var info = LabelParser.parse(lines)
        if info.size == nil || info.fibers.isEmpty, !lines.isEmpty,
           let extra = try? await interpretWithModel(lines.joined(separator: "\n")) {
            info = info.filling(from: extra)
        }
        return info
    }

    static func recognizeText(in data: Data) -> [String] {
        guard let image = ImageProcessor.downsample(data, maxPixelSize: 2400) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Las etiquetas están llenas de códigos y abreviaturas: la corrección los estropea.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["es-ES", "en-US", "fr-FR", "de-DE", "it-IT", "pt-BR"]
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    static func interpretWithModel(_ text: String) async throws -> LabelInfo? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: """
                Lees el texto de la etiqueta interior de una prenda de ropa, que puede venir en \
                varios idiomas a la vez. Extrae solo lo que aparezca en el texto, sin inventar.
                """)
            let response = try await session.respond(to: text, generating: LabelExtraction.self)
            return response.content.info
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
nonisolated struct LabelExtraction {
    @Guide(description: "Talla principal de la prenda tal y como aparece: una letra (S, M, L, XL…) o un número europeo. Vacío si no aparece.")
    var size: String?

    @Guide(description: "Fibras de la composición con su porcentaje. Si la composición aparece en varios idiomas, solo una vez.")
    var fibers: [LabelFiber]

    var info: LabelInfo {
        var info = LabelInfo()
        if let size = size?.trimmingCharacters(in: .whitespaces), !size.isEmpty, size.count <= 6 { info.size = size }
        var seen = Set<Fiber>()
        info.fibers = fibers.compactMap { item in
            let fiber = item.fiber.fiber
            guard (1...100).contains(item.percent), seen.insert(fiber).inserted else { return nil }
            return FiberShare(fiber: fiber, percent: item.percent)
        }
        .sorted { $0.percent > $1.percent }
        return info
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated struct LabelFiber {
    var fiber: LabelFiberKind
    @Guide(description: "Porcentaje de 1 a 100.")
    var percent: Int
}

@available(iOS 26.0, *)
@Generable
nonisolated enum LabelFiberKind {
    case algodon, poliester, lana, cachemira, lino, seda, viscosa, lyocell, modal, elastano, poliamida, acrilico, piel

    var fiber: Fiber {
        switch self {
        case .algodon: .cotton
        case .poliester: .polyester
        case .lana: .wool
        case .cachemira: .cashmere
        case .lino: .linen
        case .seda: .silk
        case .viscosa: .viscose
        case .lyocell: .lyocell
        case .modal: .modal
        case .elastano: .elastane
        case .poliamida: .polyamide
        case .acrilico: .acrylic
        case .piel: .leather
        }
    }
}
#endif
