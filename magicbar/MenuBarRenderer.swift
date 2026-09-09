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

    /// The standard alert: the device's glyph, a level bar and the percentage, drawn in the
    /// urgency colour directly on the menu bar.
    ///
    /// Lighter and narrower than the high-contrast style, and the default because it is what
    /// the menu bar's own items look like. Its weakness is measured rather than theoretical —
    /// the warn orange is 2.20:1 against a light bar where text wants 4.5:1 — which is what
    /// `boldAlertImage` exists to answer for anyone that affects.
    ///
    /// `isTemplate` is set false explicitly rather than left at its default. Symbols come
    /// back from `NSImage(systemSymbolName:)` already marked as templates, so an image
    /// composed from one can silently inherit that and lose every colour drawn here.
    static func standardAlertImage(device: Device, urgency: Urgency) -> NSImage {
        let nsColor = NSColor(urgency.color)

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

        // A bolt when the device is on a cable, drawn *over* the middle of the gauge the way
        // the system's own battery indicator does. It is stroked in the background colour
        // first so it stays legible against both the filled and unfilled parts of the bar.
        let bolt: NSImage? = device.isCharging
            ? Self.symbol(named: ["bolt.fill", "bolt"],
                          configuration: NSImage.SymbolConfiguration(pointSize: fontSize, weight: .black)
                             .applying(.init(paletteColors: [.white])),
                          description: "charging")
            : nil

        let symbolSize = deviceSymbol?.size ?? .zero
        let boltSize = bolt?.size ?? .zero
        let textSize = text.size()
        let barWidth: CGFloat = 24
        let barThickness: CGFloat = 9
        let gap: CGFloat = 4
        let height = contentHeight
        // The bolt overlays the bar, so it costs no width of its own. The bar widens a little
        // when charging so the glyph has room to sit inside it.
        let gaugeWidth = bolt == nil ? barWidth : barWidth + 6
        let totalWidth = symbolSize.width + gap + gaugeWidth + gap + textSize.width

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

            // Track, then fill. Rounded to match the popover bars, so the two readings of
            // the same number look like the same control.
            let track = NSRect(x: x,
                               y: (height - barThickness) / 2,
                               width: gaugeWidth,
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
            if let bolt {
                // White, drawn on top. It was knocked out of the bar before, which shows the
                // menu bar through the glyph — dark on a green fill, and nearly invisible
                // against the unfilled track when the reading is low. White reads against
                // every fill colour and against the track.
                let b = boltSize
                bolt.draw(in: NSRect(x: track.midX - b.width / 2, y: track.midY - b.height / 2,
                                     width: b.width, height: b.height))
            }

            x += gaugeWidth + gap

            text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            return true
        }

        image.isTemplate = false
        image.accessibilityDescription =
            "\(device.shortName), \(device.percent) percent, \(urgency.word)\(device.isCharging ? ", charging" : "")"
        return image
    }

    /// The high-contrast alert: the same reading as a filled capsule with dark content, and a
    /// warning mark at the urgent level.
    ///
    /// **Why a filled capsule and not coloured content on the bare bar.** Coloured content was
    /// only ever checked against a dark menu bar. Measured against a light one, the warn orange
    /// comes out at 2.20:1 where text needs 4.5:1 — and because the alert image is deliberately
    /// not a template, macOS does none of the inversion it does for the idle glyph. An opaque
    /// capsule carries its own background, so near-black content on it is 9.55:1 on orange and
    /// 5.92:1 on red whatever is behind the menu bar, including a translucent wallpaper.
    ///
    /// **Why the warning mark.** Orange and red are the same colour to red-green colourblind
    /// users — both simulate to olive-yellow about 13% apart — so hue alone cannot carry the
    /// difference between the two levels. The mark is a second channel that does not depend on
    /// seeing colour at all, and it changes the item's silhouette rather than only its tint.
    static func boldAlertImage(device: Device, urgency: Urgency) -> NSImage {
        let tint = NSColor(urgency.color)
        // Near-black rather than pure black: matches the system's own dark surfaces and stays
        // legible if the capsule colour is ever lightened.
        let ink = NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)

        let inkConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
            .applying(.init(paletteColors: [ink]))
        let deviceSymbol = symbol(named: device.symbolCandidates,
                                  configuration: inkConfig,
                                  description: device.shortName)

        let warning: NSImage? = urgency == .critical
            // Outlined, not filled. A filled triangle drawn in one colour loses the
            // exclamation mark inside it and reads as an anonymous solid shape.
            ? symbol(named: ["exclamationmark.triangle", "exclamationmark"],
                     configuration: NSImage.SymbolConfiguration(pointSize: fontSize + 1, weight: .bold)
                        .applying(.init(paletteColors: [ink])),
                     description: "critical")
            : nil

        let bolt: NSImage? = device.isCharging
            ? symbol(named: ["bolt.fill", "bolt"],
                     configuration: NSImage.SymbolConfiguration(pointSize: fontSize, weight: .bold)
                        .applying(.init(paletteColors: [ink])),
                     description: "charging")
            : nil

        let text = NSAttributedString(string: "\(device.percent)%", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: ink,
        ])

        let symbolSize = deviceSymbol?.size ?? .zero
        let warnSize = warning?.size ?? .zero
        let boltSize = bolt?.size ?? .zero
        let textSize = text.size()
        let gap: CGFloat = 3
        let padding: CGFloat = 6
        let height = contentHeight

        let extras = (warning == nil ? 0 : warnSize.width + gap) + (bolt == nil ? 0 : boltSize.width + gap)
        let totalWidth = padding + symbolSize.width + gap + extras + textSize.width + padding

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            tint.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: totalWidth, height: height),
                         xRadius: height / 2, yRadius: height / 2).fill()

            var x = padding
            if let warning {
                warning.draw(in: NSRect(x: x, y: (height - warnSize.height) / 2,
                                        width: warnSize.width, height: warnSize.height))
                x += warnSize.width + gap
            }
            if let deviceSymbol {
                deviceSymbol.draw(in: NSRect(x: x, y: (height - symbolSize.height) / 2,
                                             width: symbolSize.width, height: symbolSize.height))
                x += symbolSize.width + gap
            }
            if let bolt {
                bolt.draw(in: NSRect(x: x, y: (height - boltSize.height) / 2,
                                     width: boltSize.width, height: boltSize.height))
                x += boltSize.width + gap
            }
            text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            return true
        }

        image.isTemplate = false
        image.accessibilityDescription =
            "\(device.shortName), \(device.percent) percent, \(urgency.word)\(device.isCharging ? ", charging" : "")"
        return image
    }

    /// Picks the style. Kept here rather than at the call site so both drawing functions stay
    /// interchangeable and neither becomes the special case.
    static func alertImage(device: Device, urgency: Urgency, bold: Bool) -> NSImage {
        bold ? boldAlertImage(device: device, urgency: urgency)
             : standardAlertImage(device: device, urgency: urgency)
    }

    /// The square gauge attached to a notification.
    ///
    /// Notification content has no tint API, so an attached image is the only way to make an
    /// alert itself carry the urgency of the reading.
    ///
    /// **The urgency colour is the ground, not the fill.** Filling only the level was tried
    /// first and defeated the purpose: at 5% the coloured part is a few pixels tall, so the
    /// thumbnail read as plain white at exactly the reading that most needed to look alarming.
    ///
    /// **The device's own symbol, not a fixed silhouette.** An earlier version drew a mouse
    /// capsule whatever the device was, so a keyboard alert showed a mouse.
    static func gaugeImage(device: Device, urgency: Urgency, size: CGFloat) -> NSImage {
        let tint = NSColor(urgency.color)
        let percent = min(max(device.percent, 0), 100)
        let charging = device.isCharging
        let u = size / 256
        let shell = NSColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1)

        let glyph = symbol(named: device.symbolCandidates,
                           configuration: NSImage.SymbolConfiguration(pointSize: 104 * u, weight: .regular)
                              .applying(.init(paletteColors: [shell])),
                           description: device.shortName)
        let bolt: NSImage? = charging
            ? symbol(named: ["bolt.fill", "bolt"],
                     configuration: NSImage.SymbolConfiguration(pointSize: 30 * u, weight: .bold)
                        .applying(.init(paletteColors: [tint.blended(withFraction: 0.45, of: .black) ?? tint])),
                     description: "charging")
            : nil

        return NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            (tint.blended(withFraction: 0.28, of: .black) ?? tint).setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                         xRadius: 56 * u, yRadius: 56 * u).fill()

            // The glyph is centred on the tile, full stop. An earlier version centred the
            // glyph and the level bar together as a group, which is arithmetically centred
            // and looks wrong: the eye reads the glyph as the subject, so pairing it with a
            // bar underneath pushes the thing you actually look at above the middle.
            let glyphSize = glyph?.size ?? NSSize(width: 110 * u, height: 110 * u)
            glyph?.draw(in: NSRect(x: (size - glyphSize.width) / 2,
                                   y: (size - glyphSize.height) / 2,
                                   width: glyphSize.width,
                                   height: glyphSize.height))

            // The level rides along the bottom edge like a progress strip, so it never
            // competes with the glyph for the centre. The number is in the notification text
            // anyway; this is a glance cue, not the reading.
            let stripH = 12 * u
            let inset = 26 * u
            let strip = NSRect(x: inset, y: inset,
                               width: size - inset * 2, height: stripH)
            shell.withAlphaComponent(0.30).setFill()
            NSBezierPath(roundedRect: strip, xRadius: stripH / 2, yRadius: stripH / 2).fill()

            // Floored at 1pt with the radius shrinking to match, exactly as the menu bar bar
            // does. Flooring at the strip's own height — which this did — made every level at
            // or below 5.9% draw identically, and the tile only appears below the nag
            // threshold, so most of its live range collapsed. Same bug, second place.
            let fillW = percent > 0 ? max(strip.width * CGFloat(percent) / 100, 1) : 0
            if fillW > 0 {
                let radius = min(stripH / 2, fillW / 2)
                shell.setFill()
                NSBezierPath(roundedRect: NSRect(x: strip.minX, y: strip.minY,
                                                 width: fillW, height: stripH),
                             xRadius: radius, yRadius: radius).fill()
            }

            if let bolt {
                let b = bolt.size
                bolt.draw(in: NSRect(x: (size - b.width) / 2, y: strip.midY - b.height / 2,
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
