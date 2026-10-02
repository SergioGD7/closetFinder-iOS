import Foundation
import Testing
@testable import ClosetFinder

/// Comprueba el catálogo compilado de la app: todos los idiomas existen y cada clave tiene
/// traducción. Si se añade un texto nuevo sin traducir, este test falla.
struct LocalizationTests {
    nonisolated static let languages = ["en", "fr", "de", "it", "pt-BR"]

    static func bundle(_ language: String) -> Bundle? {
        Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    static func table(_ language: String) -> [String: String] {
        guard let path = bundle(language)?.path(forResource: "Localizable", ofType: "strings"),
              let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return table
    }

    @Test(arguments: languages)
    func everyKeyIsTranslated(language: String) throws {
        let source = Self.table("es").isEmpty ? Self.table("en") : Self.table("es")
        let translated = Self.table(language)
        #expect(!translated.isEmpty)
        let english = Self.table("en")
        let missing = english.keys.filter { translated[$0] == nil }
        #expect(missing.isEmpty, "Faltan en \(language): \(missing.prefix(5))")
        #expect(source.count <= english.count)
    }

    @Test func englishWordOrderAndText() throws {
        let en = try #require(Self.bundle("en"))
        #expect(en.localizedString(forKey: "Armario", value: nil, table: nil) == "Closet")
        #expect(en.localizedString(forKey: "garment.generatedName", value: nil, table: nil) == "%2$@ %1$@")
        #expect(en.localizedString(forKey: "category.singular.tShirt", value: nil, table: nil) == "T-shirt")
    }

    @Test func frenchAgreesInGender() throws {
        let fr = try #require(Self.bundle("fr"))
        // «Veste» es femenino en francés: se usa el adjetivo femenino.
        #expect(fr.localizedString(forKey: "category.gender.jacket", value: nil, table: nil) == "f")
        #expect(fr.localizedString(forKey: "color.blue.feminine", value: nil, table: nil) == "bleue")
    }
}
