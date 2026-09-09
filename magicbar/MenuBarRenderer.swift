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
    private static let symbolPointSize: CGFloat = 14
    private static let fontSize: CGFloat = 12

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
        let symbol = symbol(named: device.symbolCandidates,
                            configuration: configuration,
                            description: device.shortName)

        // Monospaced digits, so the item keeps a constant width as the number changes.
        // Proportional digits make the whole right-hand side of the menu bar twitch on
        // every update.
        let text = NSAttributedString(string: "\(device.percent)%", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: nsColor,
        ])

        let symbolSize = symbol?.size ?? .zero
        let textSize = text.size()
        let barWidth: CGFloat = 22
        let barThickness: CGFloat = 8
        let gap: CGFloat = 4
        let height = contentHeight
        let totalWidth = symbolSize.width + gap + barWidth + gap + textSize.width

        // Captured as plain values: the drawing handler outlives this call.
        let percent = device.percent

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            var x: CGFloat = 0

            if let symbol {
                symbol.draw(in: NSRect(x: x,
                                       y: (height - symbolSize.height) / 2,
                                       width: symbolSize.width,
                                       height: symbolSize.height))
                x += symbolSize.width + gap
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
            // Floored at the bar's own thickness. Below about 10% the true fill is thinner
            // than a pixel, so the bar renders as an empty track at exactly the moment it
            // matters most — a stub keeps "nearly empty" distinguishable from "no reading".
            let fillWidth = percent > 0 ? max(track.width * fraction, barThickness) : 0
            if fillWidth > 0 {
                nsColor.setFill()
                NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY,
                                                 width: fillWidth, height: track.height),
                             xRadius: 2, yRadius: 2).fill()
            }
            x += barWidth + gap

            text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            return true
        }

        image.isTemplate = false
        return image
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
