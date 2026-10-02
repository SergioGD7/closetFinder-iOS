import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Resultado de procesar una foto nueva de una prenda.
nonisolated struct ProcessedImage: Sendable {
    let photo: Data
    let thumbnail: Data
    let isCutout: Bool
    let colors: [GarmentColor]
    let category: GarmentCategory?
}

/// Procesado de fotos en el dispositivo: recorte del fondo, color dominante y categoría sugerida.
/// Todo se ejecuta fuera del hilo principal y con ImageIO/Vision, sin pasar por UIKit.
nonisolated enum ImageProcessor {
    static let maxPhotoDimension = 1600
    static let thumbnailDimension = 480

    @concurrent
    static func process(_ data: Data) async -> ProcessedImage? {
        guard let source = downsample(data, maxPixelSize: maxPhotoDimension) else { return nil }
        let cutout = removeBackground(from: source)
        let image = cutout ?? source
        let isCutout = cutout != nil

        guard let photo = encode(image, transparent: isCutout),
              let thumbnailImage = downsample(photo, maxPixelSize: thumbnailDimension),
              let thumbnail = encode(thumbnailImage, transparent: isCutout)
        else { return nil }

        return ProcessedImage(
            photo: photo,
            thumbnail: thumbnail,
            isCutout: isCutout,
            colors: dominantColors(in: image, isCutout: isCutout),
            category: classify(source))
    }

    // MARK: Tamaño y codificación

    /// Reduce la imagen y aplica la orientación EXIF en un solo paso.
    static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// PNG si tiene transparencia; si no, HEIC (con JPEG como alternativa).
    static func encode(_ image: CGImage, transparent: Bool) -> Data? {
        if transparent { return encode(image, type: .png) }
        return encode(image, type: .heic) ?? encode(image, type: .jpeg)
    }

    static func encode(_ image: CGImage, type: UTType, quality: Double = 0.82) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: Recorte del fondo

    /// Aísla la prenda con Vision. Devuelve `nil` si no hay un objeto claro (o en el simulador,
    /// donde la petición puede no estar disponible); entonces se guarda la foto original.
    static func removeBackground(from image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
            let masked = CIImage(cvPixelBuffer: buffer)
            // Un recorte diminuto suele ser un falso positivo: mejor quedarse con la foto.
            let coverage = (masked.extent.width * masked.extent.height) / CGFloat(image.width * image.height)
            guard coverage > 0.04 else { return nil }
            return CIContext().createCGImage(masked, from: masked.extent)
        } catch {
            return nil
        }
    }

    // MARK: Color dominante

    /// Asigna cada píxel al color de la paleta más cercano y devuelve el más frecuente
    /// (y el segundo, si ocupa más de un cuarto de la prenda).
    static func dominantColors(in image: CGImage, isCutout: Bool) -> [GarmentColor] {
        // Sin recorte, el centro de la foto es lo que más probablemente sea la prenda.
        let region: CGImage
        if isCutout {
            region = image
        } else {
            let inset = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                .insetBy(dx: CGFloat(image.width) * 0.2, dy: CGFloat(image.height) * 0.2)
            region = image.cropping(to: inset) ?? image
        }

        let side = 40
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(region, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return [] }

        var counts: [GarmentColor: Int] = [:]
        var total = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3])
            guard alpha > 200 else { continue }
            let color = GarmentColor.nearest(
                r: Double(pixels[index]) / alpha,
                g: Double(pixels[index + 1]) / alpha,
                b: Double(pixels[index + 2]) / alpha)
            counts[color, default: 0] += 1
            total += 1
        }
        guard total > 0 else { return [] }

        let ranked = counts.sorted { $0.value > $1.value }
        var result = [ranked[0].key]
        if ranked.count > 1, Double(ranked[1].value) / Double(total) > 0.25 {
            result.append(ranked[1].key)
        }
        return result
    }

    // MARK: Categoría

    static func classify(_ image: CGImage) -> GarmentCategory? {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil, let results = request.results else { return nil }
        return results
            .filter { $0.confidence > 0.1 }
            .sorted { $0.confidence > $1.confidence }
            .lazy
            .compactMap { categoryByIdentifier[$0.identifier] }
            .first
    }

    /// Identificadores de la taxonomía de `VNClassifyImageRequest` que corresponden a prendas.
    static let categoryByIdentifier: [String: GarmentCategory] = [
        "t_shirt": .tShirt, "tshirt": .tShirt, "jersey": .tShirt, "tank_top": .tShirt,
        "shirt": .shirt, "blouse": .shirt,
        "sweater": .sweater, "sweatshirt": .sweater, "hoodie": .sweater, "cardigan": .sweater,
        "jacket": .jacket, "denim_jacket": .jacket, "leather_jacket": .jacket, "vest": .jacket,
        "coat": .coat, "overcoat": .coat, "raincoat": .coat, "parka": .coat, "fur_coat": .coat,
        "blazer": .blazer, "suit": .blazer, "tuxedo": .blazer,
        "jeans": .trousers, "pants": .trousers, "trousers": .trousers, "leggings": .trousers,
        "shorts": .shorts,
        "skirt": .skirt, "miniskirt": .skirt,
        "dress": .dress, "gown": .dress, "wedding_dress": .dress,
        "shoes": .shoes, "footwear": .shoes, "sneaker": .shoes, "running_shoe": .shoes, "boot": .shoes,
        "sandal": .shoes, "high_heels": .shoes, "loafer": .shoes, "slipper": .shoes, "clog": .shoes,
        "underwear": .underwear, "bra": .underwear, "lingerie": .underwear, "sock": .underwear, "socks": .underwear,
        "swimsuit": .swimwear, "swimwear": .swimwear, "bikini": .swimwear,
        "handbag": .accessories, "bag": .accessories, "purse": .accessories, "backpack": .accessories,
        "hat": .accessories, "cap": .accessories, "scarf": .accessories, "belt": .accessories,
        "necktie": .accessories, "tie": .accessories, "glove": .accessories, "sunglasses": .accessories,
    ]
}
