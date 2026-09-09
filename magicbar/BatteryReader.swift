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

        // `DeviceAddress`, not `SerialNumber`. Measured 2026-09-08 when a Magic Mouse was
        // put on a cable: the same physical device reports
        //
        //   Bluetooth  SerialNumber "BC:89:A7:E3:B9:51"  Product "Dominic's Magic Mouse"
        //   USB        SerialNumber "J84436504T127CGB4"  Product "Magic Mouse"
        //
        // so keying on the serial gives one device two identities and its notification state
        // does not survive being plugged in. `DeviceAddress` stayed "bc-89-a7-e3-b9-51" across
        // both transports, and the display name is not identity at all — it changes too.
        let id = (properties["DeviceAddress"] as? String)?.lowercased()
            ?? properties["SerialNumber"] as? String
            ?? name

        // Confirmed 2026-09-08 against a Magic Mouse actually on a cable: the flag reads 0
        // while discharging and 3 while charging, and `pmset -g accps` agreed ("charging
        // present: true"). The full bit layout is still undocumented, so anything non-zero is
        // treated as charging and logged.
        let flags = properties["BatteryStatusFlags"] as? Int ?? 0
        if flags != 0 {
            NSLog("%@", "[magicbar] BatteryStatusFlags=\(flags) on \(name) at \(percent)%")
        }

        return Device(id: id,
                      name: name,
                      percent: percent,
                      isCharging: flags != 0,
                      statusFlags: flags,
                      productID: properties["ProductID"] as? Int)
    }
}

/// Injected readings for `--simulate`.
///
/// Battery levels cannot be dialled to order, and waiting for a real device to reach 19%
/// is not a test strategy. This lets every menu bar state and every notification rule be
/// driven from a terminal. Parsed once at launch; absent in normal operation.
enum SimulatedReadings {
    private(set) static var current: [Device]?

    /// True while the app is showing injected readings. Surfaced in the popover, because a
    /// simulated state is otherwise indistinguishable from the real hardware — which has
    /// already caused one false bug report against a leftover test instance.
    static var isActive: Bool { current != nil }

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
                guard parts.count == 2 else { return nil }
                var value = parts[1].trimmingCharacters(in: .whitespaces)
                let charging = value.hasSuffix("+")
                if charging { value.removeLast() }
                guard let percent = Int(value) else { return nil }
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                // A numeric name is read as a ProductID, so `--simulate "617:9"` picks the
                // same icon the real mouse would. Anything else is used as a display name.
                let productID = Int(name)
                let display = productID == 620 ? "Magic Keyboard" : productID == 617 ? "Magic Mouse" : name
                // A trailing "+" marks the device as charging: --simulate "617:40+"
                return Device(id: name, name: display, percent: percent,
                              isCharging: charging, statusFlags: charging ? 1 : 0,
                              productID: productID)
            }

        current = devices.isEmpty ? nil : devices.sorted { $0.percent < $1.percent }
    }

    /// Replaces the simulated set at runtime, so a single launched instance can be walked
    /// through a sequence of readings instead of being relaunched per step.
    static func override(_ devices: [Device]) {
        current = devices.sorted { $0.percent < $1.percent }
    }
}
