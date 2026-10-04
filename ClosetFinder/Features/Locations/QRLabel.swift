import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum QRCodeGenerator {
    /// Código QR nítido (sin suavizado) del tamaño pedido, en píxeles.
    static func image(for string: String, pixelSize: CGFloat = 600) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = (pixelSize / output.extent.width).rounded(.down)
        let scaled = output.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Etiqueta imprimible para pegar en una caja, maleta o mueble. Siempre en blanco y negro.
struct LocationLabel: View {
    let location: StorageLocation
    let qrImage: UIImage

    var body: some View {
        VStack(spacing: 14) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
            VStack(spacing: 4) {
                Text(location.name)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                if let parentPath = location.parentPath {
                    Text(parentPath)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(white: 0.35))
                        .multilineTextAlignment(.center)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "hanger")
                Text("Escanéalo para ver qué hay dentro · Closet Finder")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(white: 0.4))
        }
        .foregroundStyle(.black)
        .padding(26)
        .frame(width: 320)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}

/// Muestra la etiqueta QR de una ubicación y permite compartirla o imprimirla.
struct QRLabelSheet: View {
    let location: StorageLocation
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                            .accessibilityLabel("Etiqueta QR de \(location.name)")

                        ShareLink(item: Image(uiImage: rendered),
                                  preview: SharePreview("Etiqueta de \(location.name)", image: Image(uiImage: rendered))) {
                            Label("Compartir o imprimir", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary)
                        .controlSize(.large)
                        .fontWeight(.semibold)
                    } else {
                        ProgressView()
                    }

                    Text("Pega la etiqueta en la caja. Al escanearla con la cámara del iPhone, o con el botón de escanear de Ubicaciones, se abre directamente su contenido.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Etiqueta QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", systemImage: "checkmark") { dismiss() }
                }
            }
            .task { render() }
        }
    }

    private func render() {
        guard let qr = QRCodeGenerator.image(for: DeepLink.location(location.uuid).url.absoluteString) else { return }
        let renderer = ImageRenderer(content: LocationLabel(location: location, qrImage: qr))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
