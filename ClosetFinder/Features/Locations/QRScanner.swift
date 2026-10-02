import SwiftData
import SwiftUI
import Vision
import VisionKit

/// Escáner de códigos QR con la cámara (VisionKit).
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    /// Requiere un iPhone con chip A12 o posterior y permiso de cámara. No existe en el simulador.
    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                    return
                }
            }
        }
    }
}

/// Hoja con el escáner: al leer una etiqueta de Closet Finder abre esa ubicación.
struct QRScannerSheet: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var message = "Apunta a la etiqueta de una caja"
    @State private var foundFeedback = 0

    var body: some View {
        NavigationStack {
            QRScannerView(onScan: handle)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    Label(message, systemImage: "qrcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassBackground(in: Capsule())
                        .padding(.bottom, 40)
                }
                .navigationTitle("Escanear etiqueta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar", systemImage: "xmark") { dismiss() }
                    }
                }
                .sensoryFeedback(.success, trigger: foundFeedback)
        }
    }

    private func handle(_ payload: String) {
        guard let link = DeepLink(string: payload) else {
            message = "Este código no es de Closet Finder"
            return
        }
        guard router.open(link, in: modelContext) else {
            message = "Esa ubicación ya no existe"
            return
        }
        foundFeedback += 1
        dismiss()
    }
}
