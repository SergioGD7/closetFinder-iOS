import Foundation
import Testing
@testable import ClosetFinder

/// Lectura de etiquetas, medidas en pulgadas y precios.
struct LabelAndUnitsTests {

    // MARK: Etiquetas

    @Test func readsATypicalMultilingualLabel() {
        let info = LabelParser.parse([
            "M",
            "EU 38 · UK 10 · US 6",
            "100% COTTON / ALGODÓN / COTON",
            "MADE IN PORTUGAL",
            "MACHINE WASH 30°C",
            "DO NOT BLEACH",
            "DO NOT TUMBLE DRY",
            "IRON MEDIUM",
        ])
        #expect(info.size == "M")
        #expect(info.sizeEquivalents == "EU 38 · UK 10 · US 6")
        #expect(info.fibers == [FiberShare(fiber: .cotton, percent: 100)])
        #expect(info.care == [.wash30, .noBleach, .noTumbleDry, .ironMedium])
    }

    @Test func readsBlendsInAnyOrderAndLanguage() {
        let spanish = LabelParser.parse(["60% algodón 40% poliéster", "Lavar a mano", "No planchar", "No limpiar en seco"])
        #expect(spanish.fibers == [FiberShare(fiber: .cotton, percent: 60), FiberShare(fiber: .polyester, percent: 40)])
        #expect(spanish.care == [.handWash, .noIron, .noDryClean])

        // En alemán el porcentaje va detrás: «Baumwolle 95%».
        let german = LabelParser.parse(["Baumwolle 95%", "Elasthan 5%", "40°"])
        #expect(german.fibers == [FiberShare(fiber: .cotton, percent: 95), FiberShare(fiber: .elastane, percent: 5)])
        #expect(german.care == [.wash40])
    }

    @Test func usesTheEuropeanSizeWhenThereIsNoLetter() {
        let info = LabelParser.parse(["EUR 42", "USA 10", "100% WOOL"])
        #expect(info.size == "42")
        #expect(info.sizeEquivalents == "EU 42 · US 10")
        #expect(info.fibers.first?.fiber == .wool)
    }

    @Test func ignoresLettersInsideLongLinesAndTemperaturesAsSizes() {
        let info = LabelParser.parse(["THIS GARMENT IS MADE OF S GRADE FIBRES AND M QUALITY", "40", "40°C"])
        #expect(info.size == "40")
        let onlyCare = LabelParser.parse(["30°"])
        #expect(onlyCare.size == nil)
        #expect(onlyCare.care == [.wash30])
    }

    @Test func emptyTextReadsNothing() {
        #expect(LabelParser.parse([]).isEmpty)
        #expect(LabelParser.parse(["RN 54321", "CA 12345"]).isEmpty)
    }

    @Test func compositionTextIsLocalizedAndCareKeepsOnePerGroup() {
        var info = LabelInfo()
        info.fibers = [FiberShare(fiber: .cotton, percent: 60), FiberShare(fiber: .polyester, percent: 40)]
        // El esquema de los tests usa español.
        #expect(info.compositionText.contains("algodón"))
        #expect(info.compositionText.contains("poliéster"))

        #expect(CareInstruction.sorted([.wash30, .wash40, .noBleach]) == [.wash40, .noBleach])
        #expect(CareInstruction.toggling(.wash60, in: [.wash30, .noIron]) == [.wash60, .noIron])
        #expect(CareInstruction.toggling(.noIron, in: [.wash30, .noIron]) == [.wash30])
    }

    @Test func modelFillsOnlyWhatIsMissing() {
        let parsed = LabelInfo(size: "M", fibers: [], care: [.wash30])
        let model = LabelInfo(size: "L", fibers: [FiberShare(fiber: .linen, percent: 100)], care: [.noIron])
        let merged = parsed.filling(from: model)
        #expect(merged.size == "M")
        #expect(merged.fibers.first?.fiber == .linen)
        #expect(merged.care == [.wash30])
    }

    // MARK: Pulgadas

    @Test func unitFollowsTheRegion() {
        #expect(LengthUnit.resolve(.automatic, locale: Locale(identifier: "es_ES")) == .centimeters)
        #expect(LengthUnit.resolve(.automatic, locale: Locale(identifier: "en_US")) == .inches)
        #expect(LengthUnit.resolve(.automatic, locale: Locale(identifier: "en_GB")) == .inches)
        #expect(LengthUnit.resolve(.centimeters, locale: Locale(identifier: "en_US")) == .centimeters)
        #expect(LengthUnit.resolve(.inches, locale: Locale(identifier: "es_ES")) == .inches)
    }

    @Test func convertsBothWays() throws {
        let inches = LengthUnit.inches
        #expect(inches.value(fromCentimeters: 2.54) == 1)
        let parsed = try #require(inches.parse("38,5"))
        #expect(abs(parsed - 97.79) < 0.001)
        #expect(LengthUnit.centimeters.parse("98") == 98)
        #expect(LengthUnit.centimeters.parse("") == nil)
        #expect(LengthUnit.centimeters.parse("-3") == nil)
        #expect(inches.format(98).hasSuffix(inches.symbol))
        #expect(LengthUnit.centimeters.format(98) == "98 cm")
    }

    // MARK: Precios

    @Test func parsesPricesWrittenAnyWay() {
        #expect(GarmentEditorModel.parsePrice("49") == 49)
        #expect(GarmentEditorModel.parsePrice("49,95") == 49.95)
        #expect(GarmentEditorModel.parsePrice("49.95 €") == 49.95)
        #expect(GarmentEditorModel.parsePrice("1.299") == 1299)
        #expect(GarmentEditorModel.parsePrice("1.299,50") == 1299.5)
        #expect(GarmentEditorModel.parsePrice("1,299.50") == 1299.5)
        #expect(GarmentEditorModel.parsePrice("") == nil)
        #expect(GarmentEditorModel.parsePrice("gratis") == nil)
    }
}
