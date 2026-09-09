import Foundation
import SwiftUI

/// One Apple peripheral that reports a battery level.
///
/// Everything here comes from the IO registry rather than being hardcoded, which is why
/// the keyboard is supported without a line of device-specific code.
struct Device: Identifiable, Equatable {
    /// Stable across reboots and reconnections. The registry's `SerialNumber` is the
    /// Bluetooth address, so two of the same model do not collide the way a shared
    /// ProductID would.
    let id: String

    /// The registry's own `Product` string, e.g. "Dominic's Magic Mouse".
    ///
    /// Note this is **user-editable** and its punctuation is not consistent: on this
    /// machine the keyboard uses an ASCII apostrophe and the mouse uses U+2019. Never
    /// split it on punctuation, and never rely on it for identity.
    let name: String

    let percent: Int

    /// True while the device is on a cable.
    ///
    /// Derived from `BatteryStatusFlags`, which reads 0 on every device observed so far
    /// while discharging. The bit layout is not documented and was decoded by watching the
    /// value change — see `BatteryReader`, which logs any non-zero value it sees.
    let isCharging: Bool

    /// The raw flag, kept only so it can be logged. Not used for anything else.
    let statusFlags: Int

    /// USB product ID. 617 is a Magic Mouse, 620 a Magic Keyboard, both verified here.
    let productID: Int?

    /// SF Symbol candidates for this device, best first.
    ///
    /// ProductID leads because it is stable and machine-assigned; the name is only a
    /// fallback for hardware whose ID is unknown. Every name here was checked against
    /// this machine's symbol catalogue — `trackpad` and
    /// `magicmouse.radiowaves.left.and.right` do **not** exist, so neither is offered.
    var symbolCandidates: [String] {
        switch productID {
        case 620: return ["keyboard", "questionmark.circle"]
        case 617: return ["magicmouse", "computermouse", "questionmark.circle"]
        default: break
        }

        let lowered = name.lowercased()
        if lowered.contains("keyboard") { return ["keyboard", "questionmark.circle"] }
        if lowered.contains("mouse") { return ["magicmouse", "computermouse", "questionmark.circle"] }
        return ["battery.50percent", "questionmark.circle"]
    }

    /// A short label for notifications: "Magic Mouse" rather than "Dominic's Magic Mouse".
    ///
    /// The registry prefixes the owner's name, which reads oddly in an alert addressed to
    /// that same owner. Matches on the family word rather than the possessive, precisely
    /// because the apostrophe character varies between devices.
    var shortName: String {
        for family in ["Magic Keyboard", "Magic Mouse", "Magic Trackpad"] where name.contains(family) {
            return family
        }
        return name
    }
}

/// How alarming a reading is.
///
/// The colour, the notification wording and the coloured dot in the alert title all come
/// from here, so a level can never look urgent in one place and calm in another.
enum Urgency {
    case critical   // below the nag threshold
    case low        // below the alert threshold
    case ok

    var color: Color {
        switch self {
        case .critical: return .red
        case .low: return .orange
        case .ok: return .green
        }
    }

    var word: String {
        switch self {
        case .critical: return "battery critical"
        case .low: return "battery low"
        case .ok: return "battery"
        }
    }
}
