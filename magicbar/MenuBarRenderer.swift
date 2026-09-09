import AppKit
import SwiftUI

/// Draws the menu bar item.
///
/// **Why AppKit drawing and not SwiftUI.** `MenuBarExtra` repaints a `Text` label to the
/// system's flat monochrome tint no matter what `.foregroundColor` asks for, and SwiftUI's
/// `ImageRenderer` produces a black glyph mask rather than coloured text. Both were
/// measured in Range and written up in its menu bar recipe. Drawing an `NSImage` through
/// AppKit is the path that has always honoured an explicit colour.
///
/// **Why not `lockFocus`.** Range uses it, but Apple deprecates it as "incompatible with
/// resolution-independent drawing": it snapshots at the main screen's scale at the moment
/// of the call. `NSImage(size:flipped:drawingHandler:)` re-invokes the handler per backing
/// scale instead, so the item stays sharp when displays of different scale are attached.
/// The handler may run later and more than once, so it captures values, never a reference.
enum MenuBarRenderer {

    /// Content height, deliberately below `NSStatusBar.system.thickness`. The bar pads a
    /// correctly sized image and scales an oversized one, which is the usual cause of a
    /// soft-looking menu bar item.
    private static let contentHeight: CGFloat = 18
    private static let symbolPointSize: CGFloat = 16
    /// 14pt, up from 12. The percentage sat noticeably smaller than the system clock beside
    /// it, which made the one number the item exists to show the hardest thing on it to read.
    private static let fontSize: CGFloat = 14

    /// Everything is fine: one glyph, no reading, no colour.
    ///
    /// Marked as a template so macOS inverts it for light and dark menu bars. That is the
    /// opposite of `alertImage`, and the difference is the point: a template image is
    /// *meant* to be recoloured by the system, which is right for a monochrome glyph and
    /// destroys a coloured one.
    static func idleImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        guard let symbol = symbol(named: ["magicmouse", "computermouse", "questionmark.circle"],
                                  configuration: configuration,
                                  description: "magicbar") else {
            return textImage("mb", color: .labelColor, isTemplate: true)
        }
        symbol.isTemplate = true
        return symbol
    }

    /// A device is low: its own glyph, a level bar, and the percentage, in colour.
    ///
    /// `isTemplate` is set false explicitly rather than left at its default. Symbols come
    /// back from `NSImage(systemSymbolName:)` already marked as templates, so an image
    /// composed from one can silently inherit that and lose every colour drawn here.
    static func alertImage(device: Device, color: Color) -> NSImage {
        let nsColor = NSColor(color)

        let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
            .applying(.init(paletteColors: [nsColor]))
        let deviceSymbol = symbol(named: device.symbolCandidates,
                                  configuration: configuration,
                                  description: device.shortName)

        // Monospaced digits, so the item keeps a constant width as the number changes.
        // Proportional digits make the whole right-hand side of the menu bar twitch on
        // every update.
        let text = NSAttributedString(string: "\(device.percent)%", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: nsColor,
        ])

        // A bolt when the device is on a cable, which is the whole charging cue. Drawn
        // beside the gauge rather than inside it: at 8pt tall the bar has no room for a
        // glyph that would still read as lightning.
        let bolt: NSImage? = device.isCharging
            ? Self.symbol(named: ["bolt.fill", "bolt"],
                          configuration: NSImage.SymbolConfiguration(pointSize: fontSize - 2, weight: .bold)
                             .applying(.init(paletteColors: [nsColor])),
                          description: "charging")
            : nil

        let symbolSize = deviceSymbol?.size ?? .zero
        let boltSize = bolt?.size ?? .zero
        let textSize = text.size()
        let barWidth: CGFloat = 24
        let barThickness: CGFloat = 9
        let gap: CGFloat = 4
        let height = contentHeight
        let boltRun = bolt == nil ? 0 : boltSize.width + gap
        let totalWidth = symbolSize.width + gap + boltRun + barWidth + gap + textSize.width

        // Captured as plain values: the drawing handler outlives this call.
        let percent = device.percent

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            var x: CGFloat = 0

            if let deviceSymbol {
                deviceSymbol.draw(in: NSRect(x: x,
                                             y: (height - symbolSize.height) / 2,
                                             width: symbolSize.width,
                                             height: symbolSize.height))
                x += symbolSize.width + gap
            }

            if let bolt {
                bolt.draw(in: NSRect(x: x, y: (height - boltSize.height) / 2,
                                     width: boltSize.width, height: boltSize.height))
                x += boltSize.width + gap
            }

            // Track, then fill. Rounded to match the popover bars, so the two readings of
            // the same number look like the same control.
            let track = NSRect(x: x,
                               y: (height - barThickness) / 2,
                               width: barWidth,
                               height: barThickness)
            nsColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()

            // Clamped at both ends: a spurious reading over 100 must not draw past the
            // track, and a zero-width rounded rect would render as a smear.
            let fraction = CGFloat(min(max(percent, 0), 100)) / 100

            // Floored at 1pt, which is two physical pixels on a 2x display: enough to be
            // seen, small enough that it still reads as "nearly empty". An earlier version
            // floored this at the bar's thickness instead, which made every level below 36%
            // draw identically — and since the bar only appears below the alert threshold,
            // that was every level it was ever visible at.
            let fillWidth = percent > 0 ? max(track.width * fraction, 1) : 0

            if fillWidth > 0 {
                // The corner radius has to shrink with the fill. A 2pt radius on a sub-2pt
                // wide rect consumes the whole shape, which is why a low reading looked like
                // an empty track and prompted the wrong fix above.
                let radius = min(2, fillWidth / 2)
                nsColor.setFill()
                NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY,
                                                 width: fillWidth, height: track.height),
                             xRadius: radius, yRadius: radius).fill()
            }
            x += barWidth + gap

            text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            return true
        }

        image.isTemplate = false
        return image
    }

    /// The square gauge attached to a notification.
    ///
    /// Notification content has no tint API, so an attached image is the only way to make an
    /// alert itself carry the urgency of the reading.
    ///
    /// **The urgency colour is the background, not the fill.** Filling only the level was
    /// tried first and failed the whole purpose: at 5% the coloured part is a sliver a few
    /// pixels tall, so the thumbnail read as plain white at exactly the reading that most
    /// needed to look alarming. Flooding the tile means the colour is unmissable and the
    /// silhouette still carries the level.
    static func gaugeImage(device: Device, color: Color, size: CGFloat) -> NSImage {
        let tint = NSColor(color)
        let percent = device.percent
        let charging = device.isCharging
        let u = size / 256

        return NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let deep = tint.blended(withFraction: 0.30, of: .black) ?? tint
            deep.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                         xRadius: 56 * u, yRadius: 56 * u).fill()

            let bodyW = 96 * u, bodyH = 168 * u, stroke = 12 * u
            let body = NSRect(x: (size - bodyW) / 2, y: (size - bodyH) / 2, width: bodyW, height: bodyH)
            let inset = stroke / 2 + 5 * u
            let inner = body.insetBy(dx: inset, dy: inset)
            let shell = NSColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)

            // Level in the shell colour against the tinted ground, so the reading stays
            // legible whatever the urgency colour is.
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: inner, xRadius: inner.width / 2 - 2 * u, yRadius: 34 * u).addClip()
            let level = CGFloat(min(max(percent, 0), 100)) / 100
            let fillHeight = max(inner.height * level, percent > 0 ? 4 * u : 0)
            if fillHeight > 0 {
                shell.setFill()
                NSBezierPath(rect: NSRect(x: inner.minX, y: inner.minY,
                                          width: inner.width, height: fillHeight)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()

            let outline = NSBezierPath(roundedRect: body, xRadius: bodyW / 2, yRadius: 46 * u)
            outline.lineWidth = stroke
            shell.setStroke()
            outline.stroke()

            if charging, let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 44 * u, weight: .bold)
                    .applying(.init(paletteColors: [shell]))) {
                let b = bolt.size
                bolt.draw(in: NSRect(x: (size - b.width) / 2, y: size * 0.14,
                                     width: b.width, height: b.height))
            }
            return true
        }
    }

    /// First symbol in the list that this macOS actually has.
    ///
    /// `NSImage(systemSymbolName:)` returns nil rather than crashing for a withdrawn or
    /// unavailable name, so a chain costs nothing and keeps the app visible on hardware
    /// whose glyph does not exist. Logs which tier resolved, because a silently degraded
    /// icon is otherwise invisible from a terminal.
    private static func symbol(named candidates: [String],
                               configuration: NSImage.SymbolConfiguration,
                               description: String) -> NSImage? {
        for (index, name) in candidates.enumerated() {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
                .withSymbolConfiguration(configuration) {
                if index > 0 { NSLog("[magicbar] symbol fell back to '\(name)' for \(description)") }
                return image
            }
        }
        NSLog("[magicbar] no symbol resolved for \(description) from \(candidates)")
        return nil
    }

    private static func textImage(_ string: String, color: NSColor, isTemplate: Bool) -> NSImage {
        let attributed = NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color,
        ])
        let size = attributed.size()
        let image = NSImage(size: size, flipped: false) { _ in
            attributed.draw(at: .zero)
            return true
        }
        image.isTemplate = isTemplate
        return image
    }
}
