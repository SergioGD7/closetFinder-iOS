import SwiftData
import Testing
@testable import ClosetFinder

@MainActor
struct GarmentSearchTests {
    let container = AppModelContainer.preview()
    var garments: [Garment] { (try? container.mainContext.fetch(FetchDescriptor<Garment>())) ?? [] }

    private func names(_ results: [Garment]) -> [String] { results.map(\.displayName) }

    @Test func pluralsAndAccentsAreIgnored() {
        let results = names(GarmentSearch.search(garments, text: "chaquetas azules"))
        #expect(results == ["Chaqueta vaquera"])
        #expect(names(GarmentSearch.search(garments, text: "plumifero")) == ["Plumífero azul marino"])
    }

    @Test func searchesByLocation() {
        let results = names(GarmentSearch.search(garments, text: "caja nieve"))
        #expect(Set(results) == ["Plumífero azul marino", "Botas de montaña"])
    }

    @Test func nameMatchesComeFirst() {
        let results = names(GarmentSearch.search(garments, text: "azul"))
        #expect(results.first == "Americana azul" || results.first == "Plumífero azul marino")
        #expect(results.contains("Chaqueta vaquera")) // azul por color, no por nombre
    }

    @Test func tokensFilter() {
        let results = GarmentSearch.search(garments, text: "", tokens: [.color(.blue), .category(.jacket)])
        #expect(names(results) == ["Chaqueta vaquera"])
        let lent = GarmentSearch.search(garments, text: "", tokens: [.status(.lent)])
        #expect(names(lent) == ["Polo rojo"])
    }

    @Test func stopWordsAreIgnored() {
        let results = names(GarmentSearch.search(garments, text: "dónde está mi abrigo camel"))
        #expect(results == ["Abrigo camel"])
    }

    @Test func suggestedTokens() {
        let suggestions = GarmentSearch.suggestedTokens(for: "chaqueta az", excluding: [])
        #expect(suggestions.contains(.color(.blue)))
        #expect(suggestions.contains(.color(.navy)))
        #expect(GarmentSearch.removingLastWord(from: "chaqueta az") == "chaqueta ")
    }

    @Test func singularization() {
        #expect(GarmentSearch.singular("pantalones") == "pantalon")
        #expect(GarmentSearch.singular("zapatillas") == "zapatilla")
        #expect(GarmentSearch.singular("gris") == "gri")
        #expect(GarmentSearch.singular("mes") == "mes")
    }
}
