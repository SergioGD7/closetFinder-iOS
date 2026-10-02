import SwiftUI
import UIKit

extension Color {
    /// Color de marca, igual que `AccentColor` del catálogo de la app. El widget no tiene ese
    /// catálogo, así que lo usa directamente.
    static let brand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x8D / 255, green: 0x95 / 255, blue: 0xFF / 255, alpha: 1)
            : UIColor(red: 0x4F / 255, green: 0x5B / 255, blue: 0xD5 / 255, alpha: 1)
    })
}
