import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func makeIcon(_ size: CGFloat) -> NSImage {
    let s = size
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let inset = s * 0.085
    let body = rect.insetBy(dx: inset, dy: inset)
    let radius = body.width * 0.225

    // shadow plate
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()

    // gradient body
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    path.addClip()
    let grad = NSGradient(colors: [
        NSColor(srgbRed: 1.00, green: 0.47, blue: 0.36, alpha: 1),
        NSColor(srgbRed: 0.88, green: 0.16, blue: 0.20, alpha: 1),
    ])!
    grad.draw(in: body, angle: -70)

    // soft highlight
    let hl = NSBezierPath(ovalIn: NSRect(x: body.minX - body.width * 0.25,
                                         y: body.midY + body.height * 0.02,
                                         width: body.width * 1.5,
                                         height: body.height * 1.1))
    NSColor.white.withAlphaComponent(0.12).setFill()
    hl.fill()

    // equalizer bars
    let heights: [CGFloat] = [0.26, 0.46, 0.62, 0.40, 0.30]
    let barW = body.width * 0.088
    let gap = body.width * 0.045
    let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = body.midX - totalW / 2
    for h in heights {
        let barH = body.height * h
        let r = NSRect(x: x, y: body.midY - barH / 2, width: barW, height: barH)
        NSColor.white.withAlphaComponent(0.97).setFill()
        NSBezierPath(roundedRect: r, xRadius: barW / 2, yRadius: barW / 2).fill()
        x += barW + gap
    }

    img.unlockFocus()
    return img
}

let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in variants {
    let img = makeIcon(px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("iconset written to \(outDir)")
