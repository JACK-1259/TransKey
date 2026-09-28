// 앱 아이콘 생성 스크립트. 사용법: swift Tools/GenerateAppIcon.swift App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let size = 1024
let out = CommandLine.arguments[1]
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
// 배경: 인디고 → 청록 대각선 그라데이션
let bg = CGGradient(colorsSpace: space, colors: [c(0x4F46E5), c(0x0EA5E9), c(0x22D3EE)] as CFArray,
                    locations: [0, 0.65, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// 키캡
let keyRect = CGRect(x: 172, y: 196, width: 680, height: 632)
let keyPath = CGPath(roundedRect: keyRect, cornerWidth: 150, cornerHeight: 150, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 60, color: c(0x1E1B4B, 0.45))
ctx.addPath(keyPath); ctx.setFillColor(c(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()
// 키캡 아래쪽 두께감
ctx.saveGState()
ctx.addPath(keyPath); ctx.clip()
let bottom = CGGradient(colorsSpace: space, colors: [c(0xE0E7FF, 0), c(0xC7D2FE, 0.9)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bottom, start: CGPoint(x: 0, y: 330), end: CGPoint(x: 0, y: 196), options: [])
ctx.restoreGState()

// 글자
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
func draw(_ text: String, font: NSFont, color: NSColor, center: CGPoint) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let s = NSAttributedString(string: text, attributes: attrs)
    let b = s.size()
    s.draw(at: CGPoint(x: center.x - b.width / 2, y: center.y - b.height / 2))
}
let ko = NSFont(name: "AppleSDGothicNeo-Heavy", size: 330) ?? NSFont.systemFont(ofSize: 330, weight: .heavy)
let en = NSFont.systemFont(ofSize: 300, weight: .heavy)
draw("가", font: ko, color: NSColor(cgColor: c(0x4338CA))!, center: CGPoint(x: 372, y: 560))
draw("A", font: en, color: NSColor(cgColor: c(0x0891B2))!, center: CGPoint(x: 660, y: 430))

// 가 → A 방향 화살표(곡선)
ctx.setStrokeColor(c(0x94A3B8)); ctx.setLineWidth(22); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 560, y: 700))
ctx.addQuadCurve(to: CGPoint(x: 700, y: 610), control: CGPoint(x: 680, y: 710))
ctx.strokePath()
ctx.move(to: CGPoint(x: 648, y: 628)); ctx.addLine(to: CGPoint(x: 700, y: 610)); ctx.addLine(to: CGPoint(x: 712, y: 664))
ctx.strokePath()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
