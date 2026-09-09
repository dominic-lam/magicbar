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

    /// Which macOS alert sound a notification plays. "Default" means the system default.
    @Published var alertSound: String {
        didSet { UserDefaults.standard.set(alertSound, forKey: "alertSound") }
    }

    /// Unlocks the controls for firing an arbitrary alert. Off by default because the only
    /// reason to reach for them is to test the app, not to use it.
    @Published var developerMode: Bool {
        didSet { UserDefaults.standard.set(developerMode, forKey: "developerMode") }
    }

    /// Developer-mode dials. Not persisted: they describe one throwaway test, and carrying
    /// them across launches would only be confusing.
    @Published var testDeviceID: String = ""
    @Published var testPercent: Int = 5

    /// The alert sounds macOS ships, plus the default. Read from `/System/Library/Sounds`
    /// rather than hardcoded, so the list matches whatever this machine actually has.
    static let availableSounds: [String] = {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds"))?
            .filter { $0.hasSuffix(".aiff") }
            .map { String($0.dropLast(5)) }
            .sorted() ?? []
        return ["Default"] + names
    }()

    private var firedLaunchTest = false
    private var timer: Timer?
    private let watcher = RegistryWatcher()
    private var coalesceTask: Task<Void, Never>?
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

    /// Levels themselves move over tens of minutes, but *connection* changes are instant and
    /// a user who has just plugged something in is looking at the menu bar right then. The
    /// registry read costs about ten milliseconds, so the old 60s interval bought nothing and
    /// made charging look ignored. The interest notification below usually beats this anyway;
    /// the timer is the safety net for whatever it misses.
    private let pollInterval: TimeInterval = 5

    private let marksDefaultsKey = "lowWaterMarks"

    init() {
        let defaults = UserDefaults.standard
        // `integer(forKey:)` returns 0 for an absent key, which would mean "never alert".
        // Register defaults so a first run behaves like the documented 20 and 10.
        defaults.register(defaults: ["alertThreshold": 20, "nagThreshold": 10])
        defaults.register(defaults: ["alertSound": "Hero"])
        alertThreshold = defaults.integer(forKey: "alertThreshold")
        nagThreshold = defaults.integer(forKey: "nagThreshold")
        alertSound = defaults.string(forKey: "alertSound") ?? "Default"
        developerMode = defaults.bool(forKey: "developerMode")
        lowWaterMarks = defaults.dictionary(forKey: marksDefaultsKey) as? [String: Int] ?? [:]

        SimulatedReadings.parseLaunchArguments()
        // `--test-notification` runs the same path the popover button does. It has to wait
        // for authorization, which resolves asynchronously, so it hangs off the same hook.
        let wantsTest = ProcessInfo.processInfo.arguments.contains("--test-notification")
        notifier.onAuthorizationResolved = { [weak self] in
            guard let self else { return }
            self.refresh()
            if wantsTest, !self.firedLaunchTest {
                self.firedLaunchTest = true
                self.sendTestNotification()
            }
        }
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

        // The system tells us when a peripheral changes, which is what makes plugging a cable
        // in show up at once rather than at the next tick. Bursts are coalesced: one physical
        // event raises several registry notifications.
        watcher.start { [weak self] in self?.scheduleCoalescedRefresh() }

        // Read once before scheduling, or the menu bar shows nothing for a full interval.
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
        coalesceTask?.cancel()
    }

    /// Collapses a burst of registry notifications into a single read.
    private func scheduleCoalescedRefresh() {
        coalesceTask?.cancel()
        coalesceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// The device driving the menu bar, or nil when there is nothing worth showing.
    ///
    /// A charging device wins outright, at any level: plugging something in is a thing you
    /// just did, and watching it climb is the reason to look. Otherwise it is the lowest
    /// device, and only once it is under the alert threshold. `devices` is sorted
    /// lowest-first, so that case is simply the head of the list.
    var menuBarDevice: Device? {
        if let charging = devices.first(where: { $0.isCharging }) { return charging }
        guard let lowest = devices.first, lowest.percent < alertThreshold else { return nil }
        return lowest
    }

    func refresh() {
        notifier.refreshAuthorization()
        notificationsAllowed = notifier.isAuthorized
        devices = BatteryReader.read()
        if devices.first(where: { $0.id == testDeviceID }) == nil {
            testDeviceID = devices.first?.id ?? ""
        }
        for device in devices { evaluateNotification(for: device) }
    }

    /// Fires at most one alert per device per call, and only on a genuine new low.
    private func evaluateNotification(for device: Device) {
        // Nothing to warn about while it is on a cable. The mark still tracks upward
        // through the recharge branch below, so the device re-arms as it fills.
        guard !device.isCharging else {
            if let mark = lowWaterMarks[device.id], device.percent > mark {
                lowWaterMarks[device.id] = device.percent
                persistMarks()
            }
            return
        }

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
        //
        // The mark moves only if the alert was actually accepted. Recording it regardless
        // would mean an alert dropped for a reason outside the user's control — chiefly
        // authorization not having resolved yet on the first poll after launch — was lost
        // for good rather than retried.
        if mark == nil || device.percent < mark! {
            if notifier.notifyLowBattery(device: device, urgency: urgency(for: device.percent),
                                         sound: alertSound) {
                lowWaterMarks[device.id] = device.percent
                persistMarks()
            }
        }
    }

    private func persistMarks() {
        UserDefaults.standard.set(lowWaterMarks, forKey: marksDefaultsKey)
    }

    /// How alarming a reading is, given the current thresholds. Everything that expresses
    /// urgency — menu bar colour, notification tint, the dot in the alert title — comes from
    /// this one call.
    func urgency(for percent: Int) -> Urgency {
        if percent < nagThreshold { return .critical }
        if percent < alertThreshold { return .low }
        return .ok
    }

    func color(for percent: Int) -> Color { urgency(for: percent).color }

    /// Sends one notification for the lowest device, whatever its level.
    ///
    /// Exists so the popover can prove the whole delivery path end to end. Everything about
    /// notifications is invisible until one actually arrives — authorization, the frontmost
    /// suppression rule, Do Not Disturb — and each fails silently on its own.
    func sendTestNotification() {
        let device = devices.first ?? Device(id: "test", name: "Magic Mouse", percent: 5,
                                             isCharging: false, statusFlags: 0, productID: 617)
        notifier.notifyLowBattery(device: device, urgency: urgency(for: device.percent),
                                  sound: alertSound, isTest: true)
    }

    /// Fires an alert for a chosen device at a chosen level, without touching the real
    /// reading or the notification state. Developer mode only.
    ///
    /// Deliberately does not move the low-water mark: a test must not be able to silence a
    /// genuine warning that would otherwise have fired later.
    func fireDeveloperNotification() {
        let template = devices.first(where: { $0.id == testDeviceID }) ?? devices.first
        let device = Device(id: template?.id ?? "test",
                            name: template?.name ?? "Magic Mouse",
                            percent: testPercent,
                            isCharging: false,
                            statusFlags: 0,
                            productID: template?.productID ?? 617)
        notifier.notifyLowBattery(device: device, urgency: urgency(for: testPercent),
                                  sound: alertSound, isTest: true)
    }

    /// Mirrored rather than read through to `notifier`: a nested observable object does not
    /// republish to this object's observers, so the popover would never notice the user
    /// granting permission in System Settings.
    @Published private(set) var notificationsAllowed = false

    func openNotificationSettings() { notifier.openNotificationSettings() }

    /// Re-reads permission, so the popover stops claiming a denial once the user has fixed
    /// it in System Settings. Nothing else in the app notices that change.
    func refreshAuthorization() { notifier.refreshAuthorization() }
}
