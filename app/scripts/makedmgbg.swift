import AppKit
import Foundation

// 生成 DMG 安装窗口的背景图。
// 尺寸：640 x 420（略大于 Finder 内容区，避免底部露白）
// 坐标系为「左上角原点」，与 Finder 图标位置一致，方便对位。
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "bg.png"
let W: CGFloat = 640, H: CGFloat = 420

let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()

// 底色：极浅暖灰渐变（自顶向下）
let bg = NSGradient(colors: [
    NSColor(srgbRed: 0.992, green: 0.984, blue: 0.980, alpha: 1),
    NSColor(srgbRed: 0.945, green: 0.937, blue: 0.941, alpha: 1),
])!
bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// 顶部品牌色细线
NSColor(srgbRed: 0.88, green: 0.16, blue: 0.20, alpha: 1).setFill()
NSRect(x: 0, y: H - 3, width: W, height: 3).fill()

// 顶部光晕
let glow = NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.47, blue: 0.36, alpha: 0.15),
    NSColor(srgbRed: 1.0, green: 0.47, blue: 0.36, alpha: 0.0),
])!
glow.draw(in: NSRect(x: 0, y: H - 150, width: W, height: 150), angle: -90)

func centered(_ text: String, topY: CGFloat, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (text as NSString).size(withAttributes: attrs)
    // topY 为文字顶边距画布顶部的距离
    (text as NSString).draw(at: NSPoint(x: (W - size.width) / 2, y: H - topY - size.height),
                            withAttributes: attrs)
}

// 标题 / 说明
centered("小旋风收音机", topY: 44,
         font: .systemFont(ofSize: 27, weight: .semibold),
         color: NSColor(srgbRed: 0.15, green: 0.13, blue: 0.14, alpha: 1))
centered("把左边的 App 拖到右边的 Applications 文件夹即可安装", topY: 88,
         font: .systemFont(ofSize: 12.5, weight: .regular),
         color: NSColor(srgbRed: 0.42, green: 0.40, blue: 0.41, alpha: 1))

// 中间箭头：图标纵向中心 = 172（与 Finder 图标位置一致）
let cy = H - 186
let ax0: CGFloat = 300, ax1: CGFloat = 342
NSColor(srgbRed: 0.77, green: 0.75, blue: 0.76, alpha: 1).setStroke()
let line = NSBezierPath()
line.move(to: NSPoint(x: ax0, y: cy))
line.line(to: NSPoint(x: ax1 - 8, y: cy))
line.lineWidth = 3
line.lineCapStyle = .round
line.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: ax1 - 8, y: cy + 10))
head.line(to: NSPoint(x: ax1 + 2, y: cy))
head.line(to: NSPoint(x: ax1 - 8, y: cy - 10))
head.lineWidth = 3
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

// 底部提示
centered("首次打开若提示「未验证的开发者」，请右键点击 App → 打开", topY: 300,
         font: .systemFont(ofSize: 11, weight: .regular),
         color: NSColor(srgbRed: 0.55, green: 0.53, blue: 0.54, alpha: 1))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render background\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("background written to \(outPath)")
