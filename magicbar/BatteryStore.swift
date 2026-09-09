import Foundation
import SwiftUI

/// Polls the peripherals, decides what the menu bar shows, and decides when to notify.
///
/// Owned as a `@StateObject` by the `App` and passed down. It must not be created inside
/// a view: the menu bar label only re-renders when the object it observes is the one the
/// scene holds, and a view-created store leaves the label frozen at its first value.
@MainActor
final class BatteryStore: ObservableObject {

    @Published private(set) var devices: [Device] = []

    /// Below this, a device takes over the menu bar with its own icon and a level bar.
    /// Above it for every device, the menu bar is just the idle glyph.
    @Published var alertThreshold: Int {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: "alertThreshold") }
    }

    /// Below this, every further percent lost produces a notification.
    @Published var nagThreshold: Int {
        didSet { UserDefaults.standard.set(nagThreshold, forKey: "nagThreshold") }
    }

    /// Mirrors the real registration rather than a remembered preference: the setter asks
    /// the system and then reads back what the system actually did, so a failed
    /// registration shows as an unticked box instead of a lie.
    @Published var launchAtLogin: Bool = LoginItem.isEnabled {
        didSet {
            guard launchAtLogin != oldValue else { return }
            LoginItem.setEnabled(launchAtLogin)
            let actual = LoginItem.isEnabled
            if actual != launchAtLogin { launchAtLogin = actual }
        }
    }

    private var timer: Timer?
    private let notifier = Notifier()

    /// The lowest level seen per device since its last real recharge, keyed by device id.
    ///
    /// This is the whole fix for the bug the bash version shipped with. That version
    /// stored the *threshold* it last fired at and re-armed the entire ladder whenever a
    /// reading rose above it, so a one-point Bluetooth wobble produced a cascade of
    /// alerts for a battery that had not moved. Storing the lowest reading instead means
    /// a rise cannot re-arm anything unless it is large enough to be a real charge.
    private var lowWaterMarks: [String: Int] = [:]

    /// How far a reading must climb before it counts as a recharge rather than noise.
    ///
    /// Bluetooth levels wobble by a point routinely. Anything at or below that wobble
    /// must not reset the marks, or the cascade comes straight back.
    private let rechargeDelta = 5

    /// Battery levels move over tens of minutes, so this is about responsiveness after a
    /// wake rather than resolution. A tighter interval would only burn cycles.
    private let pollInterval: TimeInterval = 60

    private let marksDefaultsKey = "lowWaterMarks"

    init() {
        let defaults = UserDefaults.standard
        // `integer(forKey:)` returns 0 for an absent key, which would mean "never alert".
        // Register defaults so a first run behaves like the documented 20 and 10.
        defaults.register(defaults: ["alertThreshold": 20, "nagThreshold": 10])
        alertThreshold = defaults.integer(forKey: "alertThreshold")
        nagThreshold = defaults.integer(forKey: "nagThreshold")
        lowWaterMarks = defaults.dictionary(forKey: marksDefaultsKey) as? [String: Int] ?? [:]

        SimulatedReadings.parseLaunchArguments()
        notifier.start()
        LoginItem.log()

        // Register once, on the very first launch only. The launchd agent this app
        // replaces started at login without being asked, and an app that has to be opened
        // by hand after every restart is a monitor that quietly is not monitoring.
        // Recorded so that turning the toggle off stays off rather than being undone here
        // on the next launch.
        if !defaults.bool(forKey: "didOfferLoginItem") {
            defaults.set(true, forKey: "didOfferLoginItem")
            LoginItem.setEnabled(true)
            launchAtLogin = LoginItem.isEnabled
        }

        // Read once before scheduling, or the menu bar shows nothing for a full interval.
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    /// The device driving the menu bar, or nil when everything is healthy.
    /// `devices` is sorted lowest-first, so this is simply the head when it qualifies.
    var alertingDevice: Device? {
        guard let lowest = devices.first, lowest.percent < alertThreshold else { return nil }
        return lowest
    }

    func refresh() {
        devices = BatteryReader.read()
        for device in devices { evaluateNotification(for: device) }
    }

    /// Fires at most one alert per device per call, and only on a genuine new low.
    private func evaluateNotification(for device: Device) {
        let mark = lowWaterMarks[device.id]

        // A real recharge re-arms this device. Anything smaller is treated as noise and
        // deliberately leaves the mark where it is.
        if let mark, device.percent >= mark + rechargeDelta {
            lowWaterMarks[device.id] = device.percent
            persistMarks()
            return
        }

        guard device.percent < nagThreshold else {
            // Above the nag line there is nothing to announce, but the mark still tracks
            // downward so the first alert below the line is not a duplicate of a level
            // already passed silently.
            if mark == nil || device.percent < mark! {
                lowWaterMarks[device.id] = device.percent
                persistMarks()
            }
            return
        }

        // Below the nag line: notify only on a level never announced before.
        if mark == nil || device.percent < mark! {
            lowWaterMarks[device.id] = device.percent
            persistMarks()
            notifier.notifyLowBattery(device: device)
        }
    }

    private func persistMarks() {
        UserDefaults.standard.set(lowWaterMarks, forKey: marksDefaultsKey)
    }

    /// Colour for a level, shared by the menu bar and the popover so they cannot disagree.
    func color(for percent: Int) -> Color {
        if percent < nagThreshold { return .red }
        if percent < alertThreshold { return .orange }
        return .green
    }
}
