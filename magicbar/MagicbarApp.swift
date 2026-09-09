import SwiftUI
import AppKit

@main
struct MagicbarApp: App {
    /// Held by the `App`, not created inside a view. A store constructed in a view leaves
    /// the menu bar label observing a different object and it never updates again.
    @StateObject private var store = BatteryStore()

    @NSApplicationDelegateAdaptor(MagicbarAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            // The label re-renders whenever the observed store publishes, which is what
            // drives the idle/alert switch.
            Image(nsImage: currentImage)
        }
        // `.menu`, the default, applies NSMenu semantics and renders bars and steppers
        // wrongly or not at all. `.window` hosts arbitrary SwiftUI, at the cost of having
        // to supply the frame and the Quit button.
        .menuBarExtraStyle(.window)
    }

    private var currentImage: NSImage {
        guard let device = store.alertingDevice else { return MenuBarRenderer.idleImage() }
        return MenuBarRenderer.alertImage(device: device, color: store.color(for: device.percent))
    }
}

/// Handles the diagnostic launch arguments.
///
/// These exist because the app is often built and driven from a terminal with nobody
/// watching the menu bar. Anything that cannot be observed has to log itself.
final class MagicbarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments

        // Records the number once, since a wrongly sized menu bar image looks soft and
        // there is no way to inspect it visually from here.
        NSLog("[magicbar] status bar thickness=\(NSStatusBar.system.thickness) policy=\(NSApp.activationPolicy().rawValue)")

        // Samples the rendered menu bar image. The composed alert image is the one part
        // of this app with no working example behind it, and it cannot be inspected from
        // a terminal any other way — a wrong `isTemplate` or a failed palette colour comes
        // out as a grey blob that looks deliberate.
        if arguments.contains("--dump-label") {
            let idle = MenuBarRenderer.idleImage()
            NSLog("[magicbar] label idle size=\(idle.size) isTemplate=\(idle.isTemplate)")

            let device = Device(id: "probe", name: "Magic Mouse", percent: 19, productID: 617)
            let alert = MenuBarRenderer.alertImage(device: device, color: .orange)
            NSLog("[magicbar] label alert size=\(alert.size) isTemplate=\(alert.isTemplate)")

            if let tiff = alert.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                NSLog("[magicbar] label alert pixels=\(rep.pixelsWide)x\(rep.pixelsHigh) (scale \(Double(rep.pixelsHigh) / alert.size.height))")
                var coloured = 0
                var sampled = 0
                for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                        guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 else { continue }
                        sampled += 1
                        // Grey means the colour was lost, which is what a leaked
                        // isTemplate or a failed palette configuration looks like.
                        if abs(c.redComponent - c.blueComponent) > 0.15 { coloured += 1 }
                    }
                }
                NSLog("[magicbar] label alert opaque=\(sampled) coloured=\(coloured)")
            }
            exit(0)
        }

        if arguments.contains("--dump-devices") {
            SimulatedReadings.parseLaunchArguments(arguments)
            for device in BatteryReader.read() {
                NSLog("[magicbar] device name=\(device.name) pct=\(device.percent) id=\(device.id) productID=\(device.productID.map(String.init) ?? "nil") symbol=\(device.symbolCandidates.first ?? "none")")
                print("\(device.name)\t\(device.percent)\t\(device.productID.map(String.init) ?? "-")\t\(device.id)")
            }
            // Deliberately exits before the notification centre is ever touched, so this
            // path stays usable from the bare executable inside the bundle.
            exit(0)
        }
    }
}
