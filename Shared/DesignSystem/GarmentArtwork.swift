import SwiftUI

/// Ilustración de una prenda para cuando todavía no hay foto.
struct GarmentArtwork: View {
    let category: GarmentCategory
    let color: GarmentColor
    @Environment(\.colorScheme) private var colorScheme

    /// Contorno: oscuro para prendas claras; en modo oscuro, claro para las oscuras (si no,
    /// unas zapatillas negras desaparecen sobre el fondo).
    private var outline: Color {
        if colorScheme == .dark, color.isDark { return .white.opacity(0.35) }
        return .black.opacity(color == .white || color == .beige ? 0.14 : 0.05)
    }

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(1, min(proxy.size.width, proxy.size.height) * 0.016)
            ZStack {
                GarmentSilhouette(category: category, part: .body).fill(color.fill)
                GarmentSilhouette(category: category, part: .body)
                    .stroke(outline, lineWidth: lineWidth * (colorScheme == .dark && color.isDark ? 1.2 : 1))
                GarmentSilhouette(category: category, part: .sole).fill(.white)
                GarmentSilhouette(category: category, part: .strap)
                    .stroke(color.swatch, style: StrokeStyle(lineWidth: lineWidth * 3.5, lineCap: .round))
                GarmentSilhouette(category: category, part: .detail)
                    .stroke(.black.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.16), radius: 6, y: 5)
        .accessibilityHidden(true)
    }
}

/// Silueta vectorial de cada categoría, dibujada sobre una caja de 100×100.
nonisolated struct GarmentSilhouette: Shape {
    enum Part: Sendable { case body, detail, sole, strap }

    let category: GarmentCategory
    let part: Part

    func path(in rect: CGRect) -> Path {
        guard let path = GarmentSilhouette.paths[category]?[part] else { return Path() }
        let scale = min(rect.width, rect.height) / 100
        let transform = CGAffineTransform(translationX: rect.midX - 50 * scale, y: rect.midY - 50 * scale)
            .scaledBy(x: scale, y: scale)
        return path.applying(transform)
    }

    private static let paths: [GarmentCategory: [Part: Path]] = {
        let shirtBody = "M32 14 42 10l8 6 8-6 10 4 14 14 7 50-10 2-8-34v44H28V48l-8 34-10-2 7-50z"
        let shortsBody = "M29 22h42l5 46H55l-5-24-5 24H24z"
        let definitions: [GarmentCategory: [Part: String]] = [
            .tShirt: [.body: "M31 17 42 12c2 5 14 5 16 0l11 5 17 15-10 12-6-5v49H30V39l-6 5-10-12z",
                      .detail: "M42 12c2 5 14 5 16 0"],
            .shirt: [.body: shirtBody, .detail: "M42 10l4 9 4-3 4 3 4-9M50 16v74"],
            .sweater: [.body: "M31 15 42 11c2 6 14 6 16 0l11 4 14 14 7 50-10 2-8-34v42H28V47l-8 34-10-2 7-50z",
                       .detail: "M28 84h44M12 75l9 2M88 75l-9 2M42 11c2 6 14 6 16 0"],
            .jacket: [.body: "M32 13 43 9l7 12 7-12 11 4 14 13 6 55-11 2-6-38v46H29V45l-6 38-11-2 6-55z",
                      .detail: "M50 21v69M43 9l-4 20 8 6M57 9l4 20-8 6M36 52h9M55 52h9"],
            .coat: [.body: "M33 10 43 7l7 10 7-10 10 3 14 14 6 52-10 2-7-36v52H30V42l-7 36-10-2 6-52z",
                    .detail: "M50 17v77M43 7l-5 22 9 7M57 7l5 22-9 7M30 60h40"],
            .blazer: [.body: "M32 12 43 9l7 16 7-16 11 3 14 13 6 55-11 2-6-38v46H29V44l-6 38-11-2 6-55z",
                      .detail: "M43 9l-6 14 9 5-4 4 8 18M57 9l6 14-9 5 4 4-8 18M50 50v40"],
            .trousers: [.body: "M31 10h38l4 80H56l-6-50-6 50H27z",
                        .detail: "M31 17h38M50 17v22M38 17c0 6-3 9-6 10M62 17c0 6 3 9 6 10"],
            .shorts: [.body: shortsBody, .detail: "M29 29h42M50 29v15"],
            .swimwear: [.body: shortsBody, .detail: "M29 29h42M47 29l-2 6M53 29l2 6"],
            .skirt: [.body: "M33 20h34l15 64H18z", .detail: "M33 27h34M42 27l-6 57M58 27l6 57"],
            .dress: [.body: "M40 8h3l2 12h10l2-12h3l-1 16 6 15 15 51H20l15-51 6-15z", .detail: "M36 40h28"],
            .shoes: [.body: "M10 64V44c7-1 14 2 18 7l14-10c4-3 9-2 12 1l16 14c9 1 18 4 20 10v4H10z",
                     .sole: "M10 64h80v8c0 2-1 3-3 3H13c-2 0-3-1-3-3z",
                     .detail: "M36 48l5 5M42 44l5 5M48 41l5 5M10 64h80"],
            .underwear: [.body: "M24 30h52l2 34c-9 1-17 0-22-4l-6-8-6 8c-5 4-13 5-22 4z", .detail: "M24 37h52"],
            .accessories: [.body: "M22 42h56l-5 44H27z", .strap: "M37 42V33c0-15 26-15 26 0v9", .detail: "M22 50h56"],
        ]
        return definitions.mapValues { parts in parts.mapValues(SVGPath.parse) }
    }()
}

/// Intérprete mínimo de rutas SVG (M, L, H, V, C, Q, Z, absolutas y relativas).
nonisolated enum SVGPath {
    private enum Token: Equatable {
        case command(Character)
        case number(CGFloat)
    }

    static func parse(_ string: String) -> Path {
        let tokens = tokenize(string)
        var path = Path()
        var index = 0
        var command: Character = " "
        var current = CGPoint.zero
        var start = CGPoint.zero

        func numbers(_ count: Int) -> [CGFloat]? {
            guard index + count <= tokens.count else { return nil }
            var values: [CGFloat] = []
            for token in tokens[index..<(index + count)] {
                guard case .number(let value) = token else { return nil }
                values.append(value)
            }
            index += count
            return values
        }

        while index < tokens.count {
            if case .command(let letter) = tokens[index] {
                command = letter
                index += 1
                if letter == "Z" || letter == "z" {
                    path.closeSubpath()
                    current = start
                    continue
                }
            }
            let relative = command.isLowercase
            let origin = relative ? current : .zero

            switch command.uppercased() {
            case "M":
                guard let v = numbers(2) else { return path }
                current = CGPoint(x: origin.x + v[0], y: origin.y + v[1])
                start = current
                path.move(to: current)
                command = relative ? "l" : "L" // las coordenadas siguientes son líneas
            case "L":
                guard let v = numbers(2) else { return path }
                current = CGPoint(x: origin.x + v[0], y: origin.y + v[1])
                path.addLine(to: current)
            case "H":
                guard let v = numbers(1) else { return path }
                current.x = relative ? current.x + v[0] : v[0]
                path.addLine(to: current)
            case "V":
                guard let v = numbers(1) else { return path }
                current.y = relative ? current.y + v[0] : v[0]
                path.addLine(to: current)
            case "C":
                guard let v = numbers(6) else { return path }
                let c1 = CGPoint(x: origin.x + v[0], y: origin.y + v[1])
                let c2 = CGPoint(x: origin.x + v[2], y: origin.y + v[3])
                current = CGPoint(x: origin.x + v[4], y: origin.y + v[5])
                path.addCurve(to: current, control1: c1, control2: c2)
            case "Q":
                guard let v = numbers(4) else { return path }
                let control = CGPoint(x: origin.x + v[0], y: origin.y + v[1])
                current = CGPoint(x: origin.x + v[2], y: origin.y + v[3])
                path.addQuadCurve(to: current, control: control)
            default:
                index += 1 // número suelto sin comando: se ignora
            }
        }
        return path
    }

    private static func tokenize(_ string: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""

        func flush() {
            if let value = Double(buffer) { tokens.append(.number(CGFloat(value))) }
            buffer = ""
        }

        for character in string {
            if character.isLetter {
                flush()
                tokens.append(.command(character))
            } else if character == "-" {
                flush()
                buffer.append(character)
            } else if character == "." {
                if buffer.contains(".") { flush() }
                buffer.append(character)
            } else if character.isNumber {
                buffer.append(character)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
        ForEach(Array(GarmentCategory.allCases.enumerated()), id: \.offset) { index, category in
            GarmentArtwork(category: category, color: GarmentColor.allCases[index % GarmentColor.allCases.count])
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    .padding()
}
