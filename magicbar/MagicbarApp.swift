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
        guard let device = store.menuBarDevice else { return MenuBarRenderer.idleImage() }
        return MenuBarRenderer.alertImage(device: device,
                                          urgency: store.urgency(for: device.percent),
                                          bold: store.boldAlerts)
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
        // Walks a sequence of readings through the alert rule and prints each decision.
        // Needs no notification permission, no hardware and no persistence, which is what
        // makes the cadence checkable at all.
        if let i = arguments.firstIndex(of: "--dump-cadence"), arguments.count > i + 1 {
            let store = BatteryStore()
            var announced: Int?
            var count = 0
            print("reading\tdecision\tannounced-after")
            for token in arguments[i + 1].split(separator: ",") {
                guard let pct = Int(token.trimmingCharacters(in: .whitespaces)) else { continue }
                let decision = store.decide(percent: pct, lastAnnounced: announced)
                switch decision {
                case .notify: announced = pct; count += 1
                case .rearm: announced = nil
                case .stayQuiet: break
                }
                print("\(pct)%\t\(decision)\t\(announced.map(String.init) ?? "-")")
            }
            print("total alerts: \(count)")
            exit(0)
        }

        // Walks device sets through the store to show which vanished devices are remembered.
        if arguments.contains("--dump-retention") {
            let store = BatteryStore()
            func show(_ label: String, _ spec: String) {
                SimulatedReadings.parseLaunchArguments(["x", "--simulate", spec])
                store.refresh()
                let listed = store.devices.map { "\($0.shortName) \($0.percent)%\($0.isStale ? " [remembered]" : "")" }
                print("\(label.padding(toLength: 34, withPad: " ", startingAt: 0))\(listed.joined(separator: ", "))")
            }
            show("healthy mouse + keyboard", "617:61,620:61")
            show("then mouse disappears", "620:61")
            show("low mouse + keyboard", "617:8,620:61")
            show("then mouse disappears", "620:61")
            exit(0)
        }

        if arguments.contains("--dump-label") {
            let idle = MenuBarRenderer.idleImage()
            NSLog("[magicbar] label idle size=\(idle.size) isTemplate=\(idle.isTemplate)")

            let device = Device(id: "probe", name: "Magic Mouse", percent: 19,
                                isCharging: false, statusFlags: 0, productID: 617)
            let alert = MenuBarRenderer.alertImage(device: device, urgency: .low, bold: false)
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
            // Writes the notification tile so its composition can be measured rather than
            // judged by eye off a screenshot.
            for (name, pid) in [("mouse", 617), ("keyboard", 620)] {
                let probe = Device(id: name, name: name, percent: 18,
                                   isCharging: false, statusFlags: 0, productID: pid)
                let tile = MenuBarRenderer.gaugeImage(device: probe, urgency: .low, size: 256)
                if let tiff = tile.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    let url = URL(fileURLWithPath: "/tmp/magicbar-tile-\(name).png")
                    try? png.write(to: url)
                    NSLog("[magicbar] wrote \(url.path)")
                }
            }
            exit(0)
        }

        if arguments.contains("--dump-devices") {
            SimulatedReadings.parseLaunchArguments(arguments)
            // Which device the menu bar picks, so the ranking rule can be checked from a
            // terminal instead of by squinting at a screenshot.
            let store = BatteryStore()
            let chosen = store.menuBarDevice
            print("menu bar: \(chosen.map { "\($0.shortName) \($0.percent)%\($0.isCharging ? " charging" : "")" } ?? "idle glyph")")
            for device in BatteryReader.read() {
                NSLog("[magicbar] device name=\(device.name) pct=\(device.percent) id=\(device.id) productID=\(device.productID.map(String.init) ?? "nil") symbol=\(device.symbolCandidates.first ?? "none")")
                print("\(device.name)\t\(device.percent)\t\(device.productID.map(String.init) ?? "-")\t\(device.id)")
            }
            // UserDefaults writes are asynchronous, and exit(0) can outrun them — which made
            // a scripted sequence of these probes look stateless and reported a working
            // notification cadence as broken.
            UserDefaults.standard.synchronize()
            // Deliberately exits before the notification centre is ever touched, so this
            // path stays usable from the bare executable inside the bundle.
            exit(0)
        }
    }
}
