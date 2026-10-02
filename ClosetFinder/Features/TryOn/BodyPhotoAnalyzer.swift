import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Lo que se saca de una foto de cuerpo entero para personalizar el maniquí.
/// La foto en sí no se guarda.
nonisolated struct BodyPhotoAnalysis: Sendable {
    /// Distancia entre hombros / altura.
    var shoulderRatio: Double?
    /// Distancia entre caderas / altura.
    var hipRatio: Double?
    /// Tono de piel (r, g, b entre 0 y 1).
    var skinTone: [Double]?
    /// Cara recortada y fundida con el tono de piel en los bordes (PNG, 512 px).
    var faceTexture: Data?
}

/// Analiza la foto en el dispositivo con Vision: postura 3D del cuerpo y cara.
nonisolated enum BodyPhotoAnalyzer {
    enum Failure: Error {
        case unreadable
        case noPerson
    }

    @concurrent
    static func analyze(_ data: Data) async throws -> BodyPhotoAnalysis {
        guard let image = ImageProcessor.downsample(data, maxPixelSize: 2048) else { throw Failure.unreadable }
        var analysis = BodyPhotoAnalysis()

        if let pose = bodyProportions(in: image) {
            analysis.shoulderRatio = pose.shoulder
            analysis.hipRatio = pose.hip
        }
        if let faceBox = largestFace(in: image) {
            let skin = averageColor(in: image, normalizedRect: faceBox.insetBy(dx: faceBox.width * 0.3, dy: faceBox.height * 0.3))
            analysis.skinTone = skin
            analysis.faceTexture = faceTexture(from: image, faceBox: faceBox, skin: skin ?? [0.85, 0.75, 0.68])
        }
        guard analysis.shoulderRatio != nil || analysis.faceTexture != nil else { throw Failure.noPerson }
        return analysis
    }

    // MARK: Postura 3D

    /// Proporciones a partir de la postura 3D (iOS 17). La escala absoluta no hace falta: solo
    /// se usan cocientes, que valen aunque el iPhone no tenga LiDAR.
    static func bodyProportions(in image: CGImage) -> (shoulder: Double, hip: Double)? {
        let request = VNDetectHumanBodyPose3DRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return nil }
        func position(_ joint: VNHumanBodyPose3DObservation.JointName) -> SIMD3<Float>? {
            guard let point = try? observation.recognizedPoint(joint) else { return nil }
            let column = point.position.columns.3
            return SIMD3(column.x, column.y, column.z)
        }
        guard let leftShoulder = position(.leftShoulder), let rightShoulder = position(.rightShoulder),
              let leftHip = position(.leftHip), let rightHip = position(.rightHip)
        else { return nil }
        let height = observation.bodyHeight
        guard height > 0 else { return nil }
        let shoulder = Double(simd_distance(leftShoulder, rightShoulder) / height)
        let hip = Double(simd_distance(leftHip, rightHip) / height)
        // Valores fuera de lo humano: la detección ha fallado.
        guard (0.14...0.3).contains(shoulder), (0.06...0.18).contains(hip) else { return nil }
        return (shoulder, hip)
    }

    // MARK: Cara

    /// Recuadro de la cara más grande, normalizado y con origen arriba a la izquierda.
    static func largestFace(in image: CGImage) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width })
        else { return nil }
        let box = face.boundingBox // Vision: origen abajo a la izquierda
        return CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }

    static func averageColor(in image: CGImage, normalizedRect: CGRect) -> [Double]? {
        let rect = CGRect(x: normalizedRect.minX * CGFloat(image.width), y: normalizedRect.minY * CGFloat(image.height),
                          width: normalizedRect.width * CGFloat(image.width), height: normalizedRect.height * CGFloat(image.height)).integral
        guard let crop = image.cropping(to: rect) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return [Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255]
    }

    /// Cara con pelo y barbilla, fundida con el tono de piel hacia los bordes para que encaje
    /// en la cabeza del maniquí.
    static func faceTexture(from image: CGImage, faceBox: CGRect, skin: [Double]) -> Data? {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        // La cara detectada va de cejas a barbilla: se amplía para incluir frente, pelo y orejas.
        let box = CGRect(x: faceBox.minX * width, y: faceBox.minY * height, width: faceBox.width * width, height: faceBox.height * height)
        let crop = CGRect(x: box.midX - box.width * 0.8, y: box.minY - box.height * 0.65,
                          width: box.width * 1.6, height: box.height * 1.85)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height)).integral
        guard let face = image.cropping(to: crop) else { return nil }

        let side = 512
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let mask = ellipticalMask(side: side)
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        context.setFillColor(red: skin[0], green: skin[1], blue: skin[2], alpha: 1)
        context.fill(bounds)
        context.saveGState()
        context.clip(to: bounds, mask: mask)
        context.draw(face, in: bounds)
        context.restoreGState()
        guard let result = context.makeImage() else { return nil }
        return ImageProcessor.encode(result, type: .png)
    }

    /// Máscara en escala de grises: blanca en el centro y negra en los bordes, con degradado.
    private static func ellipticalMask(side: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                                        colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray,
                                        locations: [0, 0.62, 1])
        else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let center = CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
        // Óvalo un poco más alto que ancho, como una cara.
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 0.82, y: 1)
        context.translateBy(x: -center.x, y: -center.y)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: CGFloat(side) / 2, options: [])
        return context.makeImage()
    }
}
