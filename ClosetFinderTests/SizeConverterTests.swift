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

    @Test func trousersFitUsesWaist() {
        let fit = SizeConverter.fit(category: .trousers, chestWidthCm: nil, waistWidthCm: 43, bodyChestCm: 98, bodyWaistCm: 84)
        #expect(fit?.result == .good)
        #expect(fit?.bodyPart == "cintura")
        #expect(SizeConverter.fit(category: .shoes, chestWidthCm: 50, waistWidthCm: 40, bodyChestCm: 98, bodyWaistCm: 84) == nil)
    }
}
