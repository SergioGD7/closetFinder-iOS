import Foundation

/// Enlaces `closetfinder://` que abren una prenda o una ubicación. Los usan el widget y las
/// etiquetas QR de las cajas (escaneadas desde la app o desde la Cámara del sistema).
nonisolated enum DeepLink: Equatable, Sendable {
    case garment(UUID)
    case location(UUID)

    static let scheme = "closetfinder"

    var url: URL {
        switch self {
        case .garment(let id): URL(string: "\(Self.scheme)://garment/\(id.uuidString)")!
        case .location(let id): URL(string: "\(Self.scheme)://location/\(id.uuidString)")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let id = UUID(uuidString: url.lastPathComponent) else { return nil }
        switch url.host() {
        case "garment": self = .garment(id)
        case "location": self = .location(id)
        default: return nil
        }
    }

    init?(string: String) {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.init(url: url)
    }
}
