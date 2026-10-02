import SwiftUI
import UIKit

/// Caché de imágenes decodificadas, para no decodificar las miniaturas en cada redibujado.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for garment: Garment, fullSize: Bool) -> UIImage? {
        let key = "\(garment.uuid.uuidString)-\(garment.imageRevision)-\(fullSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let data = fullSize ? (garment.photo ?? garment.thumbnail) : (garment.thumbnail ?? garment.photo)
        guard let data, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Foto de la prenda (o su ilustración) sobre un fondo teñido con su color.
/// Se adapta al tamaño que le dé el contenedor.
struct GarmentImage: View {
    let garment: Garment
    var fullSize = false
    /// Margen interior relativo para fotos recortadas e ilustraciones.
    var inset: CGFloat = 0.12

    var body: some View {
        GeometryReader { proxy in
            let padding = min(proxy.size.width, proxy.size.height) * inset
            ZStack {
                garment.primaryColor.tint
                if let image = ImageCache.shared.image(for: garment, fullSize: fullSize) {
                    if garment.hasCutout {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                            .padding(padding)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                } else {
                    GarmentArtwork(category: garment.category, color: garment.primaryColor)
                        .padding(padding)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}
