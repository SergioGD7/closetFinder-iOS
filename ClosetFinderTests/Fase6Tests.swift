import CoreImage
import SwiftData
import Testing
import UIKit
@testable import ClosetFinder

struct DeepLinkTests {
    @Test func roundTrip() throws {
        let id = UUID()
        #expect(DeepLink(url: DeepLink.garment(id).url) == .garment(id))
        #expect(DeepLink(url: DeepLink.location(id).url) == .location(id))
        #expect(DeepLink.location(id).url.absoluteString == "closetfinder://location/\(id.uuidString)")
    }

    @Test func rejectsForeignLinks() {
        #expect(DeepLink(string: "https://apple.com/location/\(UUID().uuidString)") == nil)
        #expect(DeepLink(string: "closetfinder://box/\(UUID().uuidString)") == nil)
        #expect(DeepLink(string: "closetfinder://location/no-es-un-uuid") == nil)
        #expect(DeepLink(string: "  closetfinder://garment/\(UUID().uuidString)\n") != nil)
    }

    @Test @MainActor func qrLabelEncodesTheLink() throws {
        let link = DeepLink.location(UUID()).url.absoluteString
        let image = try #require(QRCodeGenerator.image(for: link))
        let ciImage = try #require(CIImage(image: image))
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let decoded = detector.features(in: ciImage).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        #expect(decoded == [link])
    }
}

@MainActor
struct InsightsAndTokenTests {
    let container = AppModelContainer.preview()
    var garments: [Garment] { (try? container.mainContext.fetch(FetchDescriptor<Garment>())) ?? [] }

    @Test func forgottenGarments() {
        let names = WardrobeInsights.forgotten(garments).map(\.displayName)
        #expect(names == ["Plumífero azul marino", "Botas de montaña", "Jersey de punto burdeos"])
    }

    @Test func lentGarmentsAreNotForgotten() {
        let polo = garments.first { $0.name == "Polo rojo" }!
        polo.lastWornAt = .distantPast
        #expect(!WardrobeInsights.leastRecentlyWorn(garments).contains { $0 === polo })
    }

    @Test func wornDescription() {
        let garment = Garment(name: "Prueba")
        #expect(WardrobeInsights.wornDescription(garment) == "Sin estrenar")
        garment.lastWornAt = Calendar.current.date(byAdding: .day, value: -3, to: .now)
        #expect(WardrobeInsights.wornDescription(garment) == "Hace 3 días")
    }

    @Test func sameKindTokensAreAlternatives() {
        let results = GarmentSearch.search(garments, text: "", tokens: [.category(.coat), .category(.sweater), .season(.autumnWinter)])
        let names = Set(results.map(\.displayName))
        #expect(names == ["Abrigo camel", "Plumífero azul marino", "Sudadera verde", "Jersey de punto burdeos"])
    }
}
