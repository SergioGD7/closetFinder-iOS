// Compone las capturas del App Store: fondo de color, titular y subtítulo arriba, y la captura
// en bruto debajo con las esquinas redondeadas. El tamaño final es el de la captura en bruto
// (iPhone de 6,9": 1320 × 2868; iPad de 13": 2064 × 2752).
//
// Uso: swift frame.swift captions.json carpeta_en_bruto carpeta_final
import AppKit

let arguments = CommandLine.arguments
let captions = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: arguments[1]))) as! [String: [String: [String]]]
let rawRoot = URL(fileURLWithPath: arguments[2])
let outputRoot = URL(fileURLWithPath: arguments[3])

// Colores de la marca (los mismos que el icono de color de la app).
let topColor = NSColor(srgbRed: 0.93, green: 0.94, blue: 0.99, alpha: 1)
let bottomColor = NSColor(srgbRed: 0.80, green: 0.82, blue: 0.97, alpha: 1)
let titleColor = NSColor(srgbRed: 0.09, green: 0.09, blue: 0.17, alpha: 1)
let subtitleColor = NSColor(srgbRed: 0.31, green: 0.36, blue: 0.84, alpha: 1)

func render(raw: URL, title: String, subtitle: String, to output: URL) {
    guard let shot = NSImage(contentsOf: raw), let rawRep = shot.representations.first else { return }
    let width = CGFloat(rawRep.pixelsWide), height = CGFloat(rawRep.pixelsHigh)
    let isPad = width / height > 0.6
    // Sin canal alfa: el App Store rechaza capturas con transparencia.
    let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    NSGradient(starting: topColor, ending: bottomColor)!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    // Titular y subtítulo, centrados y con margen.
    let margin = width * 0.08
    let titleSize = isPad ? width * 0.052 : width * 0.083
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineHeightMultiple = 0.95
    let titleText = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: titleSize, weight: .bold), .foregroundColor: titleColor, .paragraphStyle: paragraph,
        .kern: -titleSize * 0.01,
    ])
    let subtitleText = NSAttributedString(string: subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: titleSize * 0.46, weight: .semibold), .foregroundColor: subtitleColor,
        .paragraphStyle: paragraph,
    ])
    let textWidth = width - margin * 2
    let titleHeight = titleText.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin]).height
    let subtitleHeight = subtitleText.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin]).height
    let top = height * (isPad ? 0.045 : 0.055)
    titleText.draw(with: NSRect(x: margin, y: height - top - titleHeight, width: textWidth, height: titleHeight),
                   options: [.usesLineFragmentOrigin])
    let gap = titleSize * 0.35
    subtitleText.draw(with: NSRect(x: margin, y: height - top - titleHeight - gap - subtitleHeight, width: textWidth,
                                   height: subtitleHeight), options: [.usesLineFragmentOrigin])

    // La captura, más pequeña, bajo el texto; se corta por abajo.
    let scale: CGFloat = isPad ? 0.80 : 0.82
    let shotWidth = width * scale, shotHeight = height * scale
    let shotTop = height - top - titleHeight - gap - subtitleHeight - height * 0.04
    let shotRect = NSRect(x: (width - shotWidth) / 2, y: shotTop - shotHeight, width: shotWidth, height: shotHeight)
    let radius = shotWidth * (isPad ? 0.035 : 0.085)
    let path = NSBezierPath(roundedRect: shotRect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.12, green: 0.14, blue: 0.4, alpha: 0.28)
    shadow.shadowBlurRadius = width * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -width * 0.008)
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: shotRect)
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 0, alpha: 0.08).setStroke()
    path.lineWidth = 2
    path.stroke()

    NSGraphicsContext.restoreGraphicsState()
    let image = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! image.representation(using: .png, properties: [:])!.write(to: output)
}

let fileManager = FileManager.default
for locale in captions.keys.sorted() {
    let rawFolder = rawRoot.appending(path: locale)
    guard let files = try? fileManager.contentsOfDirectory(atPath: rawFolder.path) else { continue }
    let outputFolder = outputRoot.appending(path: locale)
    try! fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    for file in files.sorted() where file.hasSuffix(".png") {
        // «iphone-01-armario.png» → pantalla «01».
        let parts = file.split(separator: "-")
        guard parts.count >= 2, let caption = captions[locale]?[String(parts[1])] else { continue }
        render(raw: rawFolder.appending(path: file), title: caption[0], subtitle: caption[1],
               to: outputFolder.appending(path: file))
        print(outputFolder.appending(path: file).path)
    }
}
