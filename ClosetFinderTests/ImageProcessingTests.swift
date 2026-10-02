import CoreGraphics
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import ClosetFinder

struct ImageProcessingTests {

    @Test func nearestColor() {
        #expect(GarmentColor.nearest(r: 0.05, g: 0.05, b: 0.08) == .black)
        #expect(GarmentColor.nearest(r: 0.98, g: 0.98, b: 0.97) == .white)
        #expect(GarmentColor.nearest(r: 0.15, g: 0.22, b: 0.40) == .navy)
        #expect(GarmentColor.nearest(r: 0.80, g: 0.20, b: 0.20) == .red)
    }

    @Test func dominantColorOfSolidImage() throws {
        let image = try #require(Self.solidImage(red: 0.37, green: 0.55, blue: 0.38))
        #expect(ImageProcessor.dominantColors(in: image, isCutout: false) == [.green])
    }

    @Test func processProducesPhotoAndThumbnail() async throws {
        let image = try #require(Self.solidImage(red: 0.25, green: 0.42, blue: 0.71, size: 2000))
        let data = try #require(ImageProcessor.encode(image, type: .jpeg))
        let result = try #require(await ImageProcessor.process(data))
        let thumbnail = try #require(ImageProcessor.downsample(result.thumbnail, maxPixelSize: 10_000))
        #expect(max(thumbnail.width, thumbnail.height) <= ImageProcessor.thumbnailDimension)
        #expect(result.colors.first == .blue)
    }

    @Test func svgPathParsesRelativeCommands() {
        let path = SVGPath.parse("M10 10h20v20H10z")
        #expect(path.boundingRect == CGRect(x: 10, y: 10, width: 20, height: 20))
        let curve = SVGPath.parse("M0 0c0 10 10 10 10 0l5-5")
        #expect(curve.boundingRect.maxX == 15)
    }

    static func solidImage(red: CGFloat, green: CGFloat, blue: CGFloat, size: Int = 64) -> CGImage? {
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }
}
