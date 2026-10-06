// Junta varias imágenes en una sola hoja, para revisarlas de un vistazo.
// Uso: swift montage.swift salida.png columnas ancho_miniatura imagen1.png imagen2.png …
import AppKit

let arguments = CommandLine.arguments
let output = arguments[1]
let columns = Int(arguments[2])!
let thumbWidth = CGFloat(Double(arguments[3])!)
let images = arguments.dropFirst(4).compactMap { NSImage(contentsOfFile: $0) }
let ratio = images.map { $0.size.height / $0.size.width }.max() ?? 2
let thumbHeight = thumbWidth * ratio
let gap: CGFloat = 12
let rows = Int((Double(images.count) / Double(columns)).rounded(.up))
let size = NSSize(width: CGFloat(columns) * (thumbWidth + gap) + gap, height: CGFloat(rows) * (thumbHeight + gap) + gap)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.85, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
for (index, image) in images.enumerated() {
    let column = index % columns, row = index / columns
    let height = thumbWidth * image.size.height / image.size.width
    let rect = NSRect(x: gap + CGFloat(column) * (thumbWidth + gap),
                      y: size.height - CGFloat(row + 1) * (thumbHeight + gap) + (thumbHeight - height),
                      width: thumbWidth, height: height)
    image.draw(in: rect)
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
