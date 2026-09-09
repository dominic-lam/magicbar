// render-icon.swift — draws the magicbar app icon.
//
// The mouse silhouette *is* the battery gauge, which is the same idea the menu bar
// uses: a device shape carrying a level. Adapted from Range's equivalent script,
// which draws a plain horizontal battery — deliberately different, since both apps
// live in the same menu bar and dock.
//
//   swift scripts/render-icon.swift <out.png> [size]
//
// Rendered natively at each size rather than downscaled from 1024: the stroke and
// the dot are thin enough that resampling turns them to mush at 16pt.

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

let out = CommandLine.arguments[1]
let S = CGFloat(CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1024 : 1024)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 0xff) / 255,
                                         CGFloat((h >> 8) & 0xff) / 255,
                                         CGFloat(h & 0xff) / 255, a])!
}
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

/// Everything below is expressed as a fraction of the canvas, so one set of numbers
/// renders correctly at 16pt and at 1024pt.
let u = S / 1024

// --- The macOS icon tile: 824 square inset 100, with Apple's ~22.4% corner radius ---
let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
let tilePath = rr(tile, 185 * u)

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
// Cool slate, so the warm battery fill reads against it and so it does not collide
// with Range's rust-orange tile in the same dock.
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x46597C), rgb(0x1E2739)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512 * u, y: 924 * u), end: CGPoint(x: 512 * u, y: 100 * u), options: [])
let highlight = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0.0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(highlight, start: CGPoint(x: 512 * u, y: 924 * u), end: CGPoint(x: 512 * u, y: 560 * u), options: [])
ctx.restoreGState()

// --- The mouse body ---
// A capsule was tried first and read as a medicine pill. What makes the shape say
// "Magic Mouse" is the asymmetry: a fully domed top and a distinctly flatter base,
// on a footprint about twice as tall as it is wide. Equal radii lose that entirely.
let bodyW: CGFloat = 300 * u
let bodyH: CGFloat = 580 * u
let stroke: CGFloat = 36 * u
let body = CGRect(x: (S - bodyW) / 2, y: (S - bodyH) / 2, width: bodyW, height: bodyH)
let topRadius = bodyW / 2      // fully domed
let baseRadius = bodyW * 0.30  // flatter, which is the whole cue

/// A rounded rect with a different radius top and bottom.
func mouseShape(_ r: CGRect, top: CGFloat, base: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX, y: r.minY + base))
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY),
             tangent2End: CGPoint(x: r.midX, y: r.maxY), radius: top)
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY),
             tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: top)
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY),
             tangent2End: CGPoint(x: r.midX, y: r.minY), radius: base)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY),
             tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: base)
    p.closeSubpath()
    return p
}

let shell = rgb(0xF5F1E8)

// --- Battery fill, from the bottom, inside the stroke ---
// 62%: a healthy reading. The icon says "watching", not "warning" — the alarm states
// belong in the menu bar, where they mean something.
let level: CGFloat = 0.62
let bleed = stroke / 2 + 16 * u
let inner = body.insetBy(dx: bleed, dy: bleed)

ctx.saveGState()
ctx.addPath(mouseShape(inner, top: topRadius - bleed, base: baseRadius - bleed))
ctx.clip()
// Clipped to the capsule, then filled as a plain rect up to the level, so the fill's
// top edge is flat and the sides follow the shell — the way a filling gauge looks.
let fillRect = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: inner.height * level)
ctx.saveGState()
ctx.clip(to: fillRect)
let fill = CGGradient(colorsSpace: cs, colors: [rgb(0x7BD95C), rgb(0x3F9E37)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(fill, start: CGPoint(x: 0, y: fillRect.maxY), end: CGPoint(x: 0, y: fillRect.minY), options: [])
let gloss = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.30), rgb(0xFFFFFF, 0.0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: fillRect.maxY), end: CGPoint(x: 0, y: fillRect.midY), options: [])
ctx.restoreGState()
ctx.restoreGState()

// --- The shell outline, drawn over the fill so the fill is contained by it ---
ctx.addPath(mouseShape(body, top: topRadius, base: baseRadius))
ctx.setLineWidth(stroke)
ctx.setStrokeColor(shell)
ctx.strokePath()

// --- The seam: the one detail that says "Magic Mouse" rather than "pill" ---
// Dropped below 64pt, where it is under a pixel wide and only muddies the silhouette.
// A short vertical groove near the top, which is where a Magic Mouse's touch surface
// visually divides. A horizontal dash was tried and read as a stray line floating in
// the fill rather than as part of the device.
if S >= 64 {
    let grooveW = max(14 * u, 1)
    let grooveH = bodyH * 0.20
    let groove = CGRect(x: (S - grooveW) / 2, y: body.maxY - bleed - grooveH - 40 * u,
                        width: grooveW, height: grooveH)
    ctx.addPath(rr(groove, grooveW / 2))
    ctx.setFillColor(rgb(0xF5F1E8, 0.30))
    ctx.fillPath()
}

let image = ctx.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(out) at \(Int(S))px")
