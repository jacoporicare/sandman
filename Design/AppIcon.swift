// Draws the Sandman app icon. Not part of the app target.
//
// Regenerate the icon set:
//   swiftc -parse-as-library Design/AppIcon.swift -o /tmp/appicon && /tmp/appicon /tmp
//   then scale /tmp/final-1024.png into Sandman/Assets.xcassets/AppIcon.appiconset (sips -z <px> <px>).

import AppKit
import SwiftUI

// 1024×1024 canvas, macOS icon grid: an 824×824 rounded square inset by 100.
let canvas: CGFloat = 1024
let bodySize: CGFloat = 824
let gold = Color(red: 1.0, green: 0.82, blue: 0.40)
let deepGold = Color(red: 0.95, green: 0.64, blue: 0.22)
let bulbCenter = CGPoint(x: 512, y: 410)
let bulbRadius: CGFloat = 146

struct RNG {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), R = r.width / 2, k = R * 0.18
        p.move(to: CGPoint(x: c.x, y: c.y - R))
        p.addQuadCurve(to: CGPoint(x: c.x + R, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + R), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - R, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - R), control: CGPoint(x: c.x - k, y: c.y - k))
        return p
    }
}

struct Glass: Shape {
    func path(in r: CGRect) -> Path {
        let c = bulbCenter, radius = bulbRadius
        let round = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
        var neck = Path()
        neck.move(to: CGPoint(x: c.x - 134, y: c.y + 60))
        neck.addCurve(to: CGPoint(x: c.x - 72, y: c.y + 196), control1: CGPoint(x: c.x - 110, y: c.y + 116), control2: CGPoint(x: c.x - 74, y: c.y + 156))
        neck.addLine(to: CGPoint(x: c.x + 72, y: c.y + 196))
        neck.addCurve(to: CGPoint(x: c.x + 134, y: c.y + 60), control1: CGPoint(x: c.x + 74, y: c.y + 156), control2: CGPoint(x: c.x + 110, y: c.y + 116))
        neck.closeSubpath()
        return round.union(neck)
    }
}

struct Filament: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = bulbCenter.x, top = bulbCenter.y + 20, bottom = bulbCenter.y + 196
        p.move(to: CGPoint(x: cx - 34, y: bottom)); p.addLine(to: CGPoint(x: cx - 34, y: top))
        p.move(to: CGPoint(x: cx + 34, y: bottom)); p.addLine(to: CGPoint(x: cx + 34, y: top))
        p.move(to: CGPoint(x: cx - 34, y: top))
        for i in 0..<4 {
            let x0 = cx - 34 + CGFloat(i) * 17
            p.addQuadCurve(to: CGPoint(x: x0 + 17, y: top), control: CGPoint(x: x0 + 8.5, y: i.isMultiple(of: 2) ? top - 34 : top + 34))
        }
        return p
    }
}

struct Rays: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for degrees in stride(from: -150.0, through: -30.0, by: 30.0) {
            let a = degrees * .pi / 180
            let inner = bulbRadius + 44, outer = bulbRadius + 96
            p.move(to: CGPoint(x: bulbCenter.x + cos(a) * inner, y: bulbCenter.y + sin(a) * inner))
            p.addLine(to: CGPoint(x: bulbCenter.x + cos(a) * outer, y: bulbCenter.y + sin(a) * outer))
        }
        return p
    }
}

/// A dune's crest from the left edge, over a peak, to the right edge.
func crest(start: CGFloat, peak: CGPoint, end: CGFloat) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 80, y: start))
    p.addQuadCurve(to: peak, control: CGPoint(x: (80 + peak.x) / 2, y: peak.y - 12))
    p.addQuadCurve(to: CGPoint(x: 944, y: end), control: CGPoint(x: (peak.x + 944) / 2, y: peak.y + 8))
    return p
}

struct Dune: Shape {
    let start: CGFloat, peak: CGPoint, end: CGFloat
    func path(in r: CGRect) -> Path {
        var p = crest(start: start, peak: peak, end: end)
        p.addLine(to: CGPoint(x: 944, y: 944)); p.addLine(to: CGPoint(x: 80, y: 944))
        p.closeSubpath()
        return p
    }
}

struct Crest: Shape {
    let start: CGFloat, peak: CGPoint, end: CGFloat
    func path(in r: CGRect) -> Path { crest(start: start, peak: peak, end: end) }
}

struct Ripples: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (y, x0, x1) in [(780.0, 200.0, 470.0), (830.0, 300.0, 620.0), (760.0, 560.0, 800.0)] as [(CGFloat, CGFloat, CGFloat)] {
            p.move(to: CGPoint(x: x0, y: y))
            p.addQuadCurve(to: CGPoint(x: x1, y: y + 6), control: CGPoint(x: (x0 + x1) / 2, y: y - 18))
        }
        return p
    }
}

struct Stars: View {
    var body: some View {
        var rng = RNG(state: 5)
        let stars = (0..<40).map { _ in (x: 130 + rng.next() * 764, y: 130 + rng.next() * 460, r: 2.5 + rng.next() * 4, o: 0.45 + rng.next() * 0.5) }
            .filter { hypot($0.x - bulbCenter.x, $0.y - bulbCenter.y) > 330 }
        return ZStack {
            ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                Circle().fill(.white.opacity(s.o)).frame(width: s.r * 2, height: s.r * 2).position(x: s.x, y: s.y)
            }
        }
    }
}

struct MagicSand: View {
    var body: some View {
        var rng = RNG(state: 77)
        // Evenly spread around the sides of the bulb, drifting up from the dunes.
        let grains = (0..<18).map { i -> (x: CGFloat, y: CGFloat, r: CGFloat, o: Double) in
            let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
            let t = CGFloat(i / 2) / 8 + rng.next() * 0.08
            let x = bulbCenter.x + side * (bulbRadius + 50 + rng.next() * 110)
            let y = 620 - t * 330
            return (x, y, 3 + rng.next() * 4, 0.55 + rng.next() * 0.4)
        }
        return ZStack {
            ForEach(Array(grains.enumerated()), id: \.offset) { _, g in
                Circle().fill(gold).opacity(g.o).frame(width: g.r * 2, height: g.r * 2).position(x: g.x, y: g.y)
            }
            ForEach([(296.0, 470.0, 34.0), (742.0, 400.0, 28.0), (700.0, 560.0, 20.0), (330.0, 330.0, 18.0)], id: \.0) { s in
                Sparkle().fill(Color(red: 1, green: 0.95, blue: 0.78)).frame(width: s.2, height: s.2).position(x: s.0, y: s.1)
            }
        }
    }
}

struct Icon: View {
    let back = (start: CGFloat(706), peak: CGPoint(x: 770, y: 604), end: CGFloat(650))
    let front = (start: CGFloat(684), peak: CGPoint(x: 320, y: 662), end: CGFloat(806))

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.19, blue: 0.46), Color(red: 0.05, green: 0.06, blue: 0.17)], startPoint: .top, endPoint: .bottom))
                .frame(width: bodySize, height: bodySize)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 10)

            ZStack {
                Stars()
                Circle().fill(RadialGradient(colors: [gold.opacity(0.55), gold.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 400))
                    .frame(width: 800, height: 800).position(bulbCenter)
                Rays().stroke(gold.opacity(0.9), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                MagicSand()
                Glass().fill(RadialGradient(colors: [Color(red: 1, green: 0.98, blue: 0.87), gold, deepGold], center: UnitPoint(x: 0.47, y: 0.34), startRadius: 8, endRadius: 300))
                Filament().stroke(Color(red: 0.82, green: 0.45, blue: 0.08).opacity(0.5), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                Ellipse().fill(.white.opacity(0.6)).frame(width: 48, height: 90).rotationEffect(.degrees(28)).position(x: bulbCenter.x - 82, y: bulbCenter.y - 62).blur(radius: 5)
                VStack(spacing: 7) {
                    ForEach([150.0, 140.0, 130.0], id: \.self) { w in
                        Capsule().fill(LinearGradient(colors: [Color(white: 0.88), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing)).frame(width: w, height: 24)
                    }
                }
                .position(x: bulbCenter.x, y: bulbCenter.y + 196 + 46)

                // Back dune, lit from the bulb side.
                Dune(start: back.start, peak: back.peak, end: back.end)
                    .fill(LinearGradient(colors: [Color(red: 0.52, green: 0.38, blue: 0.40), Color(red: 0.25, green: 0.18, blue: 0.27)], startPoint: .top, endPoint: .bottom))
                Crest(start: back.start, peak: back.peak, end: back.end)
                    .stroke(LinearGradient(colors: [.clear, gold.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing), lineWidth: 5)

                // Front dune.
                Dune(start: front.start, peak: front.peak, end: front.end)
                    .fill(LinearGradient(colors: [Color(red: 0.97, green: 0.78, blue: 0.50), Color(red: 0.78, green: 0.52, blue: 0.27)], startPoint: .top, endPoint: .bottom))
                Ripples().stroke(Color(red: 0.70, green: 0.45, blue: 0.22).opacity(0.45), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Crest(start: front.start, peak: front.peak, end: front.end)
                    .stroke(LinearGradient(colors: [gold.opacity(0.2), Color(red: 1, green: 0.93, blue: 0.75), gold.opacity(0.2)], startPoint: .leading, endPoint: .trailing), lineWidth: 6)
            }
            .frame(width: canvas, height: canvas)
            .mask(RoundedRectangle(cornerRadius: 185, style: .continuous).frame(width: bodySize, height: bodySize))
        }
        .frame(width: canvas, height: canvas)
    }
}

struct Preview: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            Icon().scaleEffect(512 / canvas).frame(width: 512, height: 512)
            VStack(alignment: .leading, spacing: 18) {
                Icon().scaleEffect(128 / canvas).frame(width: 128, height: 128)
                HStack(alignment: .bottom, spacing: 18) {
                    Icon().scaleEffect(64 / canvas).frame(width: 64, height: 64)
                    Icon().scaleEffect(32 / canvas).frame(width: 32, height: 32)
                    Icon().scaleEffect(16 / canvas).frame(width: 16, height: 16)
                }
            }
        }
        .padding(28)
        .background(Color(white: 0.95))
    }
}

@MainActor func writePNG(_ view: some View, scale: CGFloat, to path: String) {
    let r = ImageRenderer(content: view); r.scale = scale
    try! NSBitmapImageRep(data: r.nsImage!.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: URL(filePath: path))
}

@main struct Render {
    static func main() {
        _ = NSApplication.shared
        let out = CommandLine.arguments[1]
        writePNG(Preview(), scale: 2, to: "\(out)/final-preview.png")
        writePNG(Icon(), scale: 1, to: "\(out)/final-1024.png")
    }
}
