import SwiftUI

// Liquid Glass solo existe desde iOS 26. Estos modificadores lo usan cuando está disponible y,
// en iOS 17–25, caen a los materiales translúcidos clásicos para que la app se vea coherente.

extension View {
    /// Fondo de cristal con la forma dada.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
                .background {
                    if let tint {
                        shape.fill(tint)
                    } else {
                        shape.fill(.regularMaterial)
                    }
                }
                .overlay { shape.stroke(.white.opacity(0.25), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
    }

    /// La barra de pestañas se encoge al hacer scroll (iOS 26).
    @ViewBuilder
    func minimizingTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

/// Agrupa elementos de cristal para que se fusionen al acercarse (iOS 26).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Botón redondo de cristal para flotar sobre fotos.
struct GlassCircleButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassBackground(in: Circle(), interactive: true)
        .accessibilityLabel(title)
    }
}
