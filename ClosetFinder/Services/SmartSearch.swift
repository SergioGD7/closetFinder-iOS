import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Interpreta frases como «algo de abrigo para la nieve» con el modelo de Apple Intelligence
/// del dispositivo (Foundation Models, iOS 26+) y las convierte en filtros de búsqueda.
/// Todo ocurre en el iPhone: la frase no sale del dispositivo.
nonisolated enum SmartSearch {

    struct Interpretation: Equatable {
        let tokens: [SearchToken]
        let text: String
    }

    enum Failure: Error {
        case unavailable
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Solo merece la pena con frases, no con una palabra suelta.
    static func shouldOffer(for text: String) -> Bool {
        GarmentSearch.queryWords(text).count >= 2 && isAvailable
    }

    static func interpret(_ query: String) async throws -> Interpretation {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                Eres el buscador de una app para encontrar ropa en casa. Conviertes lo que pide \
                el usuario, en español, en filtros de búsqueda. Usa solo los valores permitidos \
                y deja vacío lo que la frase no indique.
                """)
            let response = try await session.respond(to: query, generating: GarmentQuery.self)
            return response.content.interpretation
        }
        #endif
        throw Failure.unavailable
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
nonisolated struct GarmentQuery {
    @Guide(description: "Colores de ropa que se piden. Vacío si no se menciona ningún color.")
    var colors: [QueryColor]

    @Guide(description: "Tipos de prenda que encajan con la petición. Puede haber varios si es general, como «algo de abrigo» (abrigos, chaquetas, jerséis).")
    var categories: [QueryCategory]

    @Guide(description: "Temporada, solo si la frase la sugiere: frío o nieve es otoño-invierno; playa o calor es primavera-verano.")
    var season: QuerySeason?

    @Guide(description: "Palabras sueltas útiles para buscar por nombre, marca, material o lugar de la casa (por ejemplo «boda», «Levi's», «trastero»). Sin artículos, verbos ni palabras ya cubiertas por los otros campos.")
    var keywords: [String]

    var interpretation: SmartSearch.Interpretation {
        var tokens: [SearchToken] = colors.map { .color($0.garmentColor) }
        tokens += categories.map { .category($0.garmentCategory) }
        if let season { tokens.append(.season(season.season)) }
        var unique: [SearchToken] = []
        for token in tokens where !unique.contains(token) { unique.append(token) }
        return SmartSearch.Interpretation(tokens: unique, text: keywords.joined(separator: " "))
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated enum QueryColor {
    case negro, blanco, gris, beige, marron, azulMarino, azul, celeste, verde, verdeOliva
    case amarillo, naranja, rojo, burdeos, rosa, morado, multicolor

    var garmentColor: GarmentColor {
        switch self {
        case .negro: .black
        case .blanco: .white
        case .gris: .gray
        case .beige: .beige
        case .marron: .brown
        case .azulMarino: .navy
        case .azul: .blue
        case .celeste: .lightBlue
        case .verde: .green
        case .verdeOliva: .olive
        case .amarillo: .yellow
        case .naranja: .orange
        case .rojo: .red
        case .burdeos: .burgundy
        case .rosa: .pink
        case .morado: .purple
        case .multicolor: .multicolor
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated enum QueryCategory {
    case camiseta, camisa, jerseyOSudadera, chaqueta, abrigo, americana, pantalon, pantalonCorto
    case falda, vestido, calzado, ropaInterior, bano, accesorio

    var garmentCategory: GarmentCategory {
        switch self {
        case .camiseta: .tShirt
        case .camisa: .shirt
        case .jerseyOSudadera: .sweater
        case .chaqueta: .jacket
        case .abrigo: .coat
        case .americana: .blazer
        case .pantalon: .trousers
        case .pantalonCorto: .shorts
        case .falda: .skirt
        case .vestido: .dress
        case .calzado: .shoes
        case .ropaInterior: .underwear
        case .bano: .swimwear
        case .accesorio: .accessories
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated enum QuerySeason {
    case primaveraVerano, otonoInvierno, entretiempo

    var season: Season {
        switch self {
        case .primaveraVerano: .springSummer
        case .otonoInvierno: .autumnWinter
        case .entretiempo: .midSeason
        }
    }
}
#endif
