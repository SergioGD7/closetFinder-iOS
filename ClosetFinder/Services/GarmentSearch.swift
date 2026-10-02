import Foundation

/// Filtro estructurado que se añade a la búsqueda como «token».
nonisolated enum SearchToken: Hashable, Identifiable, Sendable {
    case color(GarmentColor)
    case category(GarmentCategory)
    case season(Season)
    case status(GarmentStatus)

    var id: String {
        switch self {
        case .color(let value): "color-\(value.rawValue)"
        case .category(let value): "category-\(value.rawValue)"
        case .season(let value): "season-\(value.rawValue)"
        case .status(let value): "status-\(value.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .color(let value): String(localized: "Color: \(value.title)")
        case .category(let value): value.title
        case .season(let value): value.title
        case .status(let value): value.title
        }
    }

    var symbol: String {
        switch self {
        case .color: "paintpalette"
        case .category: "hanger"
        case .season(let value): value.symbol
        case .status(let value): value.symbol
        }
    }

    /// Palabras que, escritas por el usuario, sugieren este token.
    /// Tokens del mismo tipo se combinan con «o»; de tipos distintos, con «y».
    var kind: Int {
        switch self {
        case .color: 0
        case .category: 1
        case .season: 2
        case .status: 3
        }
    }

    var keywords: [String] {
        switch self {
        case .color(let value): [value.masculine, value.feminine]
        case .category(let value): [value.title, value.singular]
        case .season(let value): [value.title]
        case .status(let value): [value.title]
        }
    }

    static let all: [SearchToken] =
        GarmentColor.allCases.map(SearchToken.color)
        + GarmentCategory.allCases.map(SearchToken.category)
        + Season.allCases.filter { $0 != .allYear }.map(SearchToken.season)
        + GarmentStatus.allCases.filter { $0 != .stored }.map(SearchToken.status)
}

/// Búsqueda en memoria sobre el inventario. Con unos pocos miles de prendas es instantánea y
/// permite reglas que un `#Predicate` no expresa bien (acentos, plurales, varias palabras).
nonisolated enum GarmentSearch {

    static let stopWords: Set<String> = [
        "de", "del", "la", "el", "los", "las", "un", "una", "unos", "unas", "mi", "mis",
        "y", "en", "con", "donde", "esta", "estan", "que", "para", "por",
        "algo", "alguna", "alguno", "algun", "ropa", "prenda", "prendas", "cosa", "cosas",
        "busco", "quiero", "necesito", "tengo", "ponerme", "llevar",
        // Otros idiomas de la app
        "the", "a", "an", "my", "of", "for", "with", "where", "is", "something", "some", "clothes",
        "le", "les", "un", "une", "des", "mon", "ma", "mes", "pour", "avec", "ou", "quelque", "chose",
        "der", "die", "das", "ein", "eine", "mein", "meine", "fur", "mit", "wo", "ist", "etwas",
        "il", "lo", "gli", "uno", "mio", "mia", "per", "dove", "qualcosa",
        "o", "os", "as", "um", "uma", "meu", "minha", "com", "onde", "algum", "alguma",
    ]

    static func search(_ garments: [Garment], text: String, tokens: [SearchToken] = []) -> [Garment] {
        let words = queryWords(text)
        let groups = Dictionary(grouping: tokens, by: \.kind).values
        let filtered = garments.filter { garment in
            groups.allSatisfy { group in group.contains { matches(garment, token: $0) } }
                && matches(garment, words: words)
        }
        guard !words.isEmpty else {
            return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
        // Primero las que coinciden por nombre; después, las que coinciden por otros campos.
        return filtered.sorted { lhs, rhs in
            let l = nameScore(lhs, words: words), r = nameScore(rhs, words: words)
            if l != r { return l > r }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func matches(_ garment: Garment, token: SearchToken) -> Bool {
        switch token {
        case .color(let color): garment.colors.contains(color)
        case .category(let category): garment.category == category
        case .season(let season): garment.season == season || garment.season == .allYear
        case .status(let status): garment.status == status
        }
    }

    /// Cada palabra de la consulta tiene que ser el comienzo de alguna palabra de la prenda.
    static func matches(_ garment: Garment, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let haystack = haystackWords(for: garment)
        return words.allSatisfy { word in haystack.contains { $0.hasPrefix(word) } }
    }

    static func haystackWords(for garment: Garment) -> [String] {
        var parts = [
            garment.displayName, garment.brand, garment.material, garment.notes, garment.size,
            garment.category.title, garment.category.singular,
            garment.season.title, garment.status.title,
            garment.owner?.name ?? "",
        ]
        parts += garment.colors.flatMap { [$0.masculine, $0.feminine] }
        parts += garment.location?.pathComponents ?? []
        return parts.flatMap(tokenize)
    }

    static func queryWords(_ text: String) -> [String] {
        tokenize(text)
            .filter { !stopWords.contains($0) }
            .map(singular)
    }

    /// Minúsculas, sin acentos, separado por cualquier signo.
    static func tokenize(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Plural a singular aproximado: «chaquetas» → «chaqueta», «azules» → «azul».
    static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("es"), let last = word.dropLast(2).last, !"aeiou".contains(last) {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    static func nameScore(_ garment: Garment, words: [String]) -> Int {
        let nameWords = tokenize(garment.displayName)
        return words.filter { word in nameWords.contains { $0.hasPrefix(word) } }.count
    }

    /// Tokens que encajan con la última palabra que se está escribiendo.
    static func suggestedTokens(for text: String, excluding current: [SearchToken]) -> [SearchToken] {
        guard let last = tokenize(text).last, last.count >= 2 else { return [] }
        return SearchToken.all.filter { token in
            !current.contains(token) && token.keywords.contains { keyword in
                tokenize(keyword).contains { $0.hasPrefix(last) }
            }
        }
        .prefix(6)
        .map { $0 }
    }

    /// Quita la última palabra del texto (cuando se ha convertido en token).
    static func removingLastWord(from text: String) -> String {
        var words = text.split(separator: " ")
        guard !words.isEmpty else { return text }
        words.removeLast()
        return words.isEmpty ? "" : words.joined(separator: " ") + " "
    }
}
