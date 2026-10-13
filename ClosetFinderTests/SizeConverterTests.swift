import Testing
@testable import ClosetFinder

struct SizeConverterTests {

    @Test(arguments: [(86.0, "XS"), (92, "S"), (98, "M"), (104, "L"), (115, "XL"), (124, "XXL")])
    func menswearTopLetter(chest: Double, expected: String) {
        #expect(SizeConverter.topLetter(chestCm: chest, sizing: .menswear) == expected)
    }

    @Test(arguments: [(80.0, "XS"), (86, "S"), (94, "M"), (100, "L")])
    func womenswearTopLetter(bust: Double, expected: String) {
        #expect(SizeConverter.topLetter(chestCm: bust, sizing: .womenswear) == expected)
    }

    @Test func menswearTopEquivalents() {
        #expect(SizeConverter.topEU(chestCm: 98, sizing: .menswear) == 48)
        #expect(SizeConverter.topUS(chestCm: 98, sizing: .menswear) == 38)
    }

    @Test func womenswearTopEquivalents() {
        #expect(SizeConverter.topEU(chestCm: 88, sizing: .womenswear) == 38)
        #expect(SizeConverter.topUS(chestCm: 88, sizing: .womenswear) == 8)
    }

    @Test func trousers() {
        #expect(SizeConverter.trousersEU(waistCm: 84, hipCm: nil, sizing: .menswear) == 42)
        #expect(SizeConverter.trousersEU(waistCm: nil, hipCm: 98, sizing: .womenswear) == 38)
        #expect(SizeConverter.trousersEU(waistCm: nil, hipCm: nil, sizing: .menswear) == nil)
        #expect(SizeConverter.jeans(waistCm: 84, inseamCm: 82) == "33/32")
        #expect(SizeConverter.jeans(waistCm: 81, inseamCm: nil) == "W32")
    }

    @Test func shoes() {
        #expect(SizeConverter.shoeEU(footCm: 27) == 43)
        #expect(SizeConverter.shoeUS(footCm: 27, sizing: .menswear) == 9)
        #expect(SizeConverter.shoeUK(footCm: 27, sizing: .menswear) == 8)
        #expect(SizeConverter.shoeEU(footCm: 24) == 38)
        #expect(SizeConverter.shoeUS(footCm: 24, sizing: .womenswear) == 7)
        #expect(SizeConverter.shoeUK(footCm: 24, sizing: .womenswear) == 4.5)
        #expect(SizeConverter.shoeUS(footCm: 26.3, sizing: .menswear) == 8.5)
    }

    @Test func recommendationsOnlyIncludeKnownMeasurements() {
        let onlyFoot = SizeConverter.recommendations(chestCm: nil, waistCm: nil, hipCm: nil, inseamCm: nil, footCm: 27, sizing: .menswear)
        #expect(onlyFoot.map(\.id) == ["shoes"])
        let full = SizeConverter.recommendations(chestCm: 98, waistCm: 84, hipCm: 100, inseamCm: 82, footCm: 27, sizing: .menswear)
        #expect(full.map(\.id) == ["tops", "trousers", "shoes"])
        #expect(full[0].size == "M")
    }

    @Test func outerwearNeedsMoreEase() {
        // Pecho de la prenda 54 cm en plano = 108 de contorno, 10 cm de holgura sobre 98.
        let jacket = SizeConverter.fit(category: .jacket, chestWidthCm: 54, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        #expect(jacket?.result == .good)
        let tee = SizeConverter.fit(category: .tShirt, chestWidthCm: 50, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        #expect(tee?.result == .snug)
        let tightCoat = SizeConverter.fit(category: .coat, chestWidthCm: 50, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        #expect(tightCoat?.result == .snug)
        let tiny = SizeConverter.fit(category: .sweater, chestWidthCm: 45, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        #expect(tiny?.result == .tooSmall)
    }

    @Test func measuredCircumferenceIsNotDoubled() {
        // Camiseta medida en contorno (104 cm) en vez de en plano (52 cm): mismo resultado.
        let flat = SizeConverter.fit(category: .tShirt, chestWidthCm: 52, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        let around = SizeConverter.fit(category: .tShirt, chestWidthCm: 104, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)
        #expect(flat?.result == .good)
        #expect(around?.result == .good)
        #expect(around?.garmentCm == 104)
        #expect(around?.easeCm == 6)
        #expect(flat?.garmentCm == 104)
        // Pantalón con cintura medida en contorno (86 cm) para una cintura de 84.
        let trousers = SizeConverter.fit(category: .trousers, chestWidthCm: nil, waistWidthCm: 86, bodyChestCm: nil, bodyWaistCm: 84)
        #expect(trousers?.result == .good)
        #expect(trousers?.easeCm == 2)
        // Una prenda de verdad grande sigue saliendo grande, se mida como se mida.
        #expect(SizeConverter.fit(category: .tShirt, chestWidthCm: 64, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)?.result == .tooBig)
        #expect(SizeConverter.fit(category: .tShirt, chestWidthCm: 128, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)?.result == .tooBig)
        // Y una pequeña, pequeña.
        #expect(SizeConverter.fit(category: .tShirt, chestWidthCm: 90, waistWidthCm: nil, bodyChestCm: 98, bodyWaistCm: nil)?.result == .tooSmall)
    }

    @Test func circumferenceThresholdIsThreeQuartersOfTheBody() {
        #expect(SizeConverter.garmentCircumference(measured: 54, bodyCm: 98) == 108)
        #expect(SizeConverter.garmentCircumference(measured: 74, bodyCm: 98) == 74)
        #expect(SizeConverter.garmentCircumference(measured: 72, bodyCm: 98) == 144)
    }

    @Test func trousersFitUsesWaist() {
        let fit = SizeConverter.fit(category: .trousers, chestWidthCm: nil, waistWidthCm: 43, bodyChestCm: 98, bodyWaistCm: 84)
        #expect(fit?.result == .good)
        #expect(fit?.bodyPart == "cintura")
        #expect(SizeConverter.fit(category: .shoes, chestWidthCm: 50, waistWidthCm: 40, bodyChestCm: 98, bodyWaistCm: 84) == nil)
    }
}
