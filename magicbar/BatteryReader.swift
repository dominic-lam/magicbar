import Foundation
import IOKit

/// Reads peripheral battery levels out of the IO registry.
///
/// **Why the registry and not the power-sources API.** `IOPSCopyPowerSourcesInfo` plus
/// `IOPSCopyPowerSourcesList` is the public, documented route to battery data, and it
/// was tried first. Measured 2026-09-08 on this machine: it returns **zero** power
/// sources. Bluetooth accessories are a separate power-source type that the public API
/// does not enumerate — `pmset -g accps` can see them only because it reaches through
/// `IOPSCopyPowerSourcesByType` with `kIOPSAccessoryType`, and neither the function nor
/// the constant exists in the public SDK.
///
/// So the registry it is, which is also what the bash implementation used via `ioreg`.
/// This does the same query in-process instead of spawning a subprocess every tick.
enum BatteryReader {

    /// The IOKit class every Apple HID peripheral with a battery publishes under.
    /// Verified against both a Magic Mouse and a Magic Keyboard.
    private static let serviceClass = "AppleDeviceManagementHIDEventService"

    /// Every connected peripheral that currently reports a battery level.
    ///
    /// A device that is asleep, disconnected or otherwise unreadable simply does not
    /// appear. That absence must never be read as 0% — see `BatteryStore`, which leaves
    /// a vanished device's notification state untouched rather than treating it as a
    /// drain to zero.
    static func read() -> [Device] {
        if let simulated = SimulatedReadings.current { return simulated }

        var iterator: io_iterator_t = 0
        // IOServiceGetMatchingServices consumes the matching dictionary, so it must not
        // be released here — passing it in is handing over ownership.
        let matching = IOServiceMatching(serviceClass)
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [Device] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = device(from: service) { devices.append(device) }
        }

        // Lowest first, so "the device that matters" is always the head of the list and
        // both the menu bar and the popover agree on ordering without sorting twice.
        return devices.sorted { $0.percent < $1.percent }
    }

    private static func device(from service: io_service_t) -> Device? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = unmanaged?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // Both checks matter. `HasBattery` excludes peripherals that publish the service
        // without a cell; the `BatteryPercent` cast excludes a device that has one but is
        // not currently reporting, which is what a sleeping mouse looks like.
        guard properties["HasBattery"] as? Bool == true,
              let percent = properties["BatteryPercent"] as? Int,
              let name = properties["Product"] as? String else {
            return nil
        }

        // SerialNumber is the Bluetooth address and is stable across reconnects. Falling
        // back to the name keeps a device usable rather than dropping it, at the cost of
        // state colliding if two peripherals somehow share a name.
        let id = properties["SerialNumber"] as? String ?? name

        return Device(id: id, name: name, percent: percent, productID: properties["ProductID"] as? Int)
    }
}

/// Injected readings for `--simulate`.
///
/// Battery levels cannot be dialled to order, and waiting for a real device to reach 19%
/// is not a test strategy. This lets every menu bar state and every notification rule be
/// driven from a terminal. Parsed once at launch; absent in normal operation.
enum SimulatedReadings {
    private(set) static var current: [Device]?

    /// Parses `--simulate "Magic Mouse:19,Magic Keyboard:8"` out of the process arguments.
    ///
    /// Names are matched loosely so the argument stays short — "mouse:19" is enough. The
    /// synthetic id is the name itself, which keeps notification state separate per
    /// simulated device the same way a real serial number would.
    static func parseLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let flagIndex = arguments.firstIndex(of: "--simulate"),
              arguments.count > flagIndex + 1 else { return }

        let devices = arguments[flagIndex + 1]
            .split(separator: ",")
            .compactMap { pair -> Device? in
                let parts = pair.split(separator: ":")
                guard parts.count == 2, let percent = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
                    return nil
                }
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                // A numeric name is read as a ProductID, so `--simulate "617:9"` picks the
                // same icon the real mouse would. Anything else is used as a display name.
                let productID = Int(name)
                let display = productID == 620 ? "Magic Keyboard" : productID == 617 ? "Magic Mouse" : name
                return Device(id: name, name: display, percent: percent, productID: productID)
            }

        current = devices.isEmpty ? nil : devices.sorted { $0.percent < $1.percent }
    }

    /// Replaces the simulated set at runtime, so a single launched instance can be walked
    /// through a sequence of readings instead of being relaunched per step.
    static func override(_ devices: [Device]) {
        current = devices.sorted { $0.percent < $1.percent }
    }
}
