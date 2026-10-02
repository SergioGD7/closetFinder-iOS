import AppIntents
import SwiftData

/// «Oye Siri, busca una prenda en Closet Finder» → «¿Qué prenda buscas?» → «abrigo negro»
/// → «Tu Abrigo negro está en Dormitorio › Armario grande › Barra».
struct FindGarmentIntent: AppIntent {
    static let title: LocalizedStringResource = "Buscar una prenda"
    static let description = IntentDescription("Te dice dónde está guardada una prenda de tu armario.")

    @Parameter(title: "Prenda", requestValueDialog: "¿Qué prenda buscas?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Buscar \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext
        let garments = try context.fetch(FetchDescriptor<Garment>())
        let results = GarmentSearch.search(garments, text: query)

        guard let first = results.first else {
            return .result(dialog: "No he encontrado «\(query)» en tu armario.")
        }
        let answer = Self.sentence(for: first)
        guard results.count > 1 else {
            return .result(dialog: "\(answer)")
        }
        let others = results.count - 1
        return .result(dialog: "\(answer) Hay \(others) \(others == 1 ? "prenda más parecida" : "prendas más parecidas") en la app.")
    }

    static func sentence(for garment: Garment) -> String {
        guard let location = garment.location else {
            return "Tu \(garment.displayName) no tiene ubicación asignada."
        }
        switch garment.status {
        case .lent: return "Tu \(garment.displayName) está prestada. Su sitio es \(location.path)."
        case .laundry: return "Tu \(garment.displayName) está lavándose. Su sitio es \(location.path)."
        default: return "Tu \(garment.displayName) está en \(location.path)."
        }
    }
}

struct ClosetFinderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindGarmentIntent(),
            phrases: [
                "Busca una prenda en \(.applicationName)",
                "Dónde está mi ropa en \(.applicationName)",
                "Encuentra ropa con \(.applicationName)",
            ],
            shortTitle: "Buscar prenda",
            systemImageName: "hanger")
    }
}
