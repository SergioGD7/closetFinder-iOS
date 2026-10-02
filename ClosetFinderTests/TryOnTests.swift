import Foundation
import simd
import Testing
@testable import ClosetFinder

struct TryOnTests {
    let body = BodyShape(.init(heightCm: 178, chestCm: 98, waistCm: 84, hipCm: 100, inseamCm: 82, footCm: 27))

    @Test func ellipseKeepsRequestedCircumference() {
        let ellipse = Ellipse.with(circumference: 0.98, ratio: 1.45)
        #expect(abs(ellipse.circumference - 0.98) < 0.0005)
        #expect(abs(ellipse.a / ellipse.b - 1.45) < 0.001)
        #expect(abs(ellipse.scaled(toCircumference: 1.2).circumference - 1.2) < 0.0005)
    }

    @Test func torsoMatchesMeasurements() {
        #expect(abs(body.torsoShape(at: body.yChest).circumference - 0.98) < 0.005)
        #expect(abs(body.torsoShape(at: body.yWaist).circumference - 0.84) < 0.005)
        #expect(abs(body.torsoShape(at: body.yHip).circumference - 1.00) < 0.005)
        #expect(body.assumed.isEmpty)
    }

    @Test func landmarksAreInOrder() {
        let heights = [body.yAnkle, body.yKnee, body.yCrotch, body.yHip, body.yWaist, body.yChest,
                       body.yArmpit, body.yShoulder, body.yNeckBase, body.yChin, body.height]
        #expect(heights == heights.sorted())
        #expect(body.yCrotch == 0.82)
    }

    @Test func missingMeasurementsAreReported() {
        let partial = BodyShape(.init(heightCm: 170, chestCm: 95, sizing: .womenswear))
        #expect(partial.assumed == [.waist, .hip, .inseam, .foot])
        #expect(partial.height == 1.7)
    }

    @Test func garmentNeverGoesInsideTheBody() {
        // Una camiseta dos tallas pequeña: se ajusta al cuerpo y el resumen avisa.
        let tight = GarmentShell(.init(category: .tShirt, chestWidthCm: 44, lengthCm: 70), on: body)
        for ring in tight.shell {
            let skin = body.torsoShape(at: max(ring.y, body.yHip))
            #expect(ring.shape.circumference >= skin.circumference)
        }
        #expect(tight.lines.first?.level == .warning)
    }

    @Test func looseGarmentHangsWithItsOwnWidth() {
        let jacket = GarmentShell(.init(category: .jacket, chestWidthCm: 60, lengthCm: 66, sleeveCm: 63), on: body)
        let chestRing = jacket.shell.min { abs($0.y - body.yChest) < abs($1.y - body.yChest) }!
        #expect(abs(chestRing.shape.circumference - 1.2) < 0.01)
        #expect(jacket.tubes.count == 2)
        #expect(jacket.lines.map(\.title) == ["Pecho", "Largo", "Manga"])
    }

    @Test func trouserLength() {
        let exact = GarmentShell(.init(category: .trousers, waistWidthCm: 42.5, inseamCm: 80), on: body)
        #expect(exact.lines.last?.level == .good)
        let long = GarmentShell(.init(category: .trousers, waistWidthCm: 42.5, inseamCm: 88), on: body)
        #expect(long.lines.last?.detail == "Te sobran 6 cm de largo")
        #expect(long.yHem > 0)
        let short = GarmentShell(.init(category: .trousers, waistWidthCm: 42.5, inseamCm: 66), on: body)
        #expect(short.lines.last?.level == .warning)
        #expect(short.tubes.count == 2)
    }

    @Test func shoeSize() {
        let mine = GarmentShell(.init(category: .shoes, size: "43"), on: body)
        #expect(mine.lines.first?.level == .good)
        let small = GarmentShell(.init(category: .shoes, size: "41"), on: body)
        #expect(small.lines.first?.level == .warning)
        #expect(GarmentShell.style(for: .accessories) == .unsupported)
    }

    @Test func loftMeshTopology() {
        let rings = (0..<5).map { Ring(y: Float($0) * 0.1, shape: .circle(0.1)) }
        let mesh = LoftMesh(rings: rings, segments: 12, capBottom: true)
        #expect(mesh.positions.count == 5 * 13 + 1)
        #expect(mesh.indices.count == (4 * 12 * 2 + 12) * 3) // dos triángulos por cuadrado y una tapa
        // Las normales del lateral apuntan hacia fuera.
        let side = 2 * 13 + 3
        let radial = SIMD3(mesh.positions[side].x, 0, mesh.positions[side].z)
        #expect(simd_dot(mesh.normals[side], radial) > 0)
        let (front, back) = mesh.splitIndicesFrontBack()
        #expect(front.count + back.count == mesh.indices.count)
    }
}
