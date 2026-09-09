import Foundation
import SwiftUI
import AppKit

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

    /// Which level a notification rule watches. Naming the levels rather than repeating a
    /// number keeps the two settings honest: change a level once and everything follows.
    enum Level: String, CaseIterable, Identifiable {
        case warn, urgent
        var id: String { rawValue }
        var label: String { self == .warn ? "warn" : "urgent" }
    }

    /// Where the menu bar starts showing a reading rather than the plain glyph.
    enum MenuBarVisibility: String, CaseIterable, Identifiable {
        case belowWarn, belowUrgent, always
        var id: String { rawValue }
        var label: String {
            switch self {
            // Short enough to fit the picker without truncating. The key beneath the slider
            // already says what each level's number is.
            case .belowWarn: return "below warn"
            case .belowUrgent: return "below urgent"
            case .always: return "always"
            }
        }
    }

    /// Draws the menu bar alert as a filled capsule with dark content, plus a warning mark at
    /// the urgent level.
    ///
    /// Named for what it does rather than for who needs it. It answers two measured problems —
    /// the standard style's warn orange is 2.20:1 against a light menu bar where text wants
    /// 4.5:1, and orange and red simulate to nearly the same olive-yellow for red-green
    /// colourblind users, so hue alone cannot separate the two levels. Both are contrast
    /// problems, and a setting called after an impairment labels the reader rather than the
    /// feature, so anyone who would benefit has to identify themselves to find it.
    @Published var boldAlerts: Bool {
        didSet { UserDefaults.standard.set(boldAlerts, forKey: "boldAlerts") }
    }

    @Published var menuBarVisibility: MenuBarVisibility {
        didSet { UserDefaults.standard.set(menuBarVisibility.rawValue, forKey: "menuBarVisibility") }
    }

    /// The master switch. Off means the app watches and shows but never interrupts.
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var coarseEnabled: Bool {
        didSet { UserDefaults.standard.set(coarseEnabled, forKey: "coarseEnabled") }
    }
    @Published var coarseLevel: Level {
        didSet { UserDefaults.standard.set(coarseLevel.rawValue, forKey: "coarseLevel") }
    }
    @Published var fineEnabled: Bool {
        didSet { UserDefaults.standard.set(fineEnabled, forKey: "fineEnabled") }
    }
    @Published var fineLevel: Level {
        didSet { UserDefaults.standard.set(fineLevel.rawValue, forKey: "fineLevel") }
    }

    /// Warn when the machine goes to sleep, so the message is waiting when the user next sits
    /// down — which is when a cable costs them nothing.
    @Published var notifyOnSleep: Bool {
        didSet { UserDefaults.standard.set(notifyOnSleep, forKey: "notifyOnSleep") }
    }

    /// A daily check at a chosen hour. The scheduled version of the same idea, for the evenings
    /// the machine never sleeps.
    @Published var eveningReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(eveningReminderEnabled, forKey: "eveningReminderEnabled") }
    }
    @Published var eveningReminderHour: Int {
        didSet { UserDefaults.standard.set(eveningReminderHour, forKey: "eveningReminderHour") }
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
        return ["None", "Default"] + names
    }()

    /// Readings kept for devices that have dropped out of the registry.
    ///
    /// A sleeping peripheral disappears entirely, which used to mean an alarming red item
    /// reverted to the calm idle glyph — the alarm silencing itself at the end of the drain
    /// curve, which is the worst possible moment.
    ///
    /// **Only devices that were already low are remembered.** Nothing in the registry
    /// distinguishes "asleep" from "unpaired", so remembering every device meant a mouse
    /// removed in Bluetooth settings sat in the list claiming to be asleep. Narrowing it to
    /// devices worth warning about removes that for the ordinary case — a healthy device that
    /// goes away simply goes away — and keeps the memory exactly where it was needed.
    private var lastSeen: [String: Device] = [:]

    /// How long a vanished low device keeps its last reading. Long enough to cover a mouse
    /// sleeping between uses, short enough that it stops being claimed as news.
    private let staleAfter: TimeInterval = 30 * 60

    /// The day the evening reminder last fired, so it fires once per day rather than on every
    /// tick after the hour passes.
    private var lastEveningReminder: Date?

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
        defaults.register(defaults: [
            "alertSound": "Hero",
            "boldAlerts": false,
            "menuBarVisibility": MenuBarVisibility.belowWarn.rawValue,
            "notificationsEnabled": true,
            "coarseEnabled": true,
            "coarseLevel": Level.warn.rawValue,
            "fineEnabled": true,
            "fineLevel": Level.urgent.rawValue,
            "notifyOnSleep": true,
            "eveningReminderEnabled": true,
            "eveningReminderHour": 18,
        ])
        alertThreshold = defaults.integer(forKey: "alertThreshold")
        nagThreshold = defaults.integer(forKey: "nagThreshold")
        alertSound = defaults.string(forKey: "alertSound") ?? "Hero"
        developerMode = defaults.bool(forKey: "developerMode")
        boldAlerts = defaults.bool(forKey: "boldAlerts")
        menuBarVisibility = MenuBarVisibility(rawValue: defaults.string(forKey: "menuBarVisibility") ?? "") ?? .belowWarn
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        coarseEnabled = defaults.bool(forKey: "coarseEnabled")
        coarseLevel = Level(rawValue: defaults.string(forKey: "coarseLevel") ?? "") ?? .warn
        fineEnabled = defaults.bool(forKey: "fineEnabled")
        fineLevel = Level(rawValue: defaults.string(forKey: "fineLevel") ?? "") ?? .urgent
        notifyOnSleep = defaults.bool(forKey: "notifyOnSleep")
        eveningReminderEnabled = defaults.bool(forKey: "eveningReminderEnabled")
        eveningReminderHour = defaults.integer(forKey: "eveningReminderHour")
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

        // Warn as the machine goes to sleep. The message will not be read until the user next
        // sits down — which is the point: that is when a cable is free, rather than mid-task
        // when flipping a mouse over costs them the mouse.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.warnBeforeSleep() }
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
        // A dying device outranks a charging one. Charging used to win outright, which meant
        // a keyboard on a cable at 90% hid a mouse at 4% — while a notification was
        // simultaneously calling that mouse critical. The app contradicted itself on screen.
        // Charging still takes over, but only when nothing is actually running out.
        let visibleBelow: Int
        switch menuBarVisibility {
        case .always: visibleBelow = 101
        case .belowWarn: visibleBelow = alertThreshold
        case .belowUrgent: visibleBelow = nagThreshold
        }
        if let dying = devices.first(where: { !$0.isCharging && $0.percent < visibleBelow }) {
            return dying
        }
        if let charging = devices.first(where: { $0.isCharging }) { return charging }
        return nil
    }

    /// A second low device, so "one is dying" and "both are dying" are not the same picture.
    var secondaryLowDevice: Device? {
        let low = devices.filter { !$0.isCharging && $0.percent < alertThreshold }
        return low.count > 1 ? low[1] : nil
    }

    /// Re-reads notification permission. Called when the popover opens, not on every tick:
    /// `getNotificationSettings` is an XPC round trip to `usernoted`, and doing it on a
    /// 5-second timer is some seventeen thousand inter-process calls a day to keep one
    /// checkbox honest.
    func refreshAuthorizationNow() {
        notifier.refreshAuthorization()
        notificationsAllowed = notifier.isAuthorized
    }

    func refresh() {
        var fresh = BatteryReader.read()

        // Remember what is present, then re-add anything that has gone missing recently.
        let now = Date.now
        for device in fresh {
            if device.percent < alertThreshold && !device.isCharging {
                lastSeen[device.id] = device
            } else {
                // Healthy, or on a cable. If this one disappears there is nothing to warn
                // about, so it should disappear from the list too.
                lastSeen.removeValue(forKey: device.id)
            }
        }
        let present = Set(fresh.map(\.id))
        for (id, remembered) in lastSeen where !present.contains(id) {
            guard now.timeIntervalSince(remembered.lastSeen) < staleAfter else {
                lastSeen.removeValue(forKey: id)
                continue
            }
            var stale = remembered
            stale.isStale = true
            // A remembered device is never reported as charging: the cable state is exactly
            // what we can no longer see.
            fresh.append(Device(id: stale.id, name: stale.name, percent: stale.percent,
                                isCharging: false, statusFlags: 0, productID: stale.productID,
                                lastSeen: remembered.lastSeen, isStale: true))
        }
        fresh.sort { $0.percent < $1.percent }
        // Publishing an identical list still fires objectWillChange, which recomposes the
        // menu bar image every 5 seconds forever. `Device` is Equatable precisely so this
        // comparison is available.
        if fresh != devices { devices = fresh }
        if devices.first(where: { $0.id == testDeviceID }) == nil {
            testDeviceID = devices.first?.id ?? ""
        }
        for device in devices where !device.isStale { evaluateNotification(for: device) }
        checkEveningReminder()
    }

    func threshold(for level: Level) -> Int {
        level == .warn ? alertThreshold : nagThreshold
    }

    /// How far a level must fall before it is worth saying again, or nil for silence.
    ///
    /// **The finer rule takes all.** Where both rules apply the smaller step wins outright,
    /// rather than both firing — so pointing them at the same level is redundant rather than
    /// contradictory, and there is no configuration that produces two alerts for one drop.
    func notifyStep(for percent: Int) -> Int? {
        guard notificationsEnabled else { return nil }
        if fineEnabled, percent < threshold(for: fineLevel) { return 1 }
        if coarseEnabled, percent < threshold(for: coarseLevel) { return 5 }
        return nil
    }

    /// What to do about a reading, given the level last announced for that device.
    ///
    /// Pure, and deliberately separate from delivery. The rule used to be entangled with
    /// notification authorization and `UserDefaults`, which made it untestable: a scripted
    /// check reported the cadence broken when what had actually happened is that
    /// authorization never resolved in a short-lived probe, so nothing was ever recorded.
    enum AlertDecision: Equatable {
        case notify
        case rearm      // a real recharge; forget what was announced
        case stayQuiet
    }

    func decide(percent: Int, lastAnnounced: Int?) -> AlertDecision {
        if let lastAnnounced, percent >= lastAnnounced + rechargeDelta { return .rearm }
        guard let step = notifyStep(for: percent) else { return .stayQuiet }
        guard let lastAnnounced else { return .notify }
        return percent <= lastAnnounced - step ? .notify : .stayQuiet
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

        switch decide(percent: device.percent, lastAnnounced: lowWaterMarks[device.id]) {
        case .rearm:
            lowWaterMarks.removeValue(forKey: device.id)
            persistMarks()
        case .stayQuiet:
            break
        case .notify:
            // The mark moves only if the alert was accepted. Recording it regardless would
            // lose an alert dropped for a reason outside the user's control — chiefly
            // authorization not having resolved yet on the first poll after launch — rather
            // than retrying it on the next tick.
            if notifier.notifyLowBattery(device: device, urgency: urgency(for: device.percent),
                                         sound: alertSound) {
                lowWaterMarks[device.id] = device.percent
                persistMarks()
            }
        }
    }

    /// Fired as the machine sleeps, if anything is below the warn level.
    ///
    /// Deliberately outside the low-water-mark rule: this is not a new low, it is the same
    /// reading delivered at a better moment, so it neither consumes nor is suppressed by the
    /// ordinary cadence.
    private func warnBeforeSleep() {
        guard notificationsEnabled, notifyOnSleep else { return }
        guard let device = devices.first(where: { !$0.isCharging && !$0.isStale
                                                  && $0.percent < alertThreshold }) else { return }
        NSLog("%@", "[magicbar] sleep warning for \(device.shortName) at \(device.percent)%")
        notifier.notifyChargeReminder(device: device, urgency: urgency(for: device.percent),
                                      sound: alertSound,
                                      reason: "Charge it while you are away")
    }

    /// The scheduled twin of the sleep warning, for evenings the machine never sleeps.
    ///
    /// Checked on the ordinary poll rather than by its own timer: a timer that has to survive
    /// sleep, clock changes and time zones is a whole mechanism, where a comparison against the
    /// wall clock is correct by construction.
    private func checkEveningReminder() {
        guard notificationsEnabled, eveningReminderEnabled else { return }

        let calendar = Calendar.current
        let now = Date.now
        guard calendar.component(.hour, from: now) >= eveningReminderHour else { return }
        if let last = lastEveningReminder, calendar.isDate(last, inSameDayAs: now) { return }

        guard let device = devices.first(where: { !$0.isCharging && !$0.isStale
                                                  && $0.percent < alertThreshold }) else { return }
        lastEveningReminder = now
        NSLog("%@", "[magicbar] evening reminder for \(device.shortName) at \(device.percent)%")
        notifier.notifyChargeReminder(device: device, urgency: urgency(for: device.percent),
                                      sound: alertSound,
                                      reason: "Charge it tonight")
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

    /// True while the app is showing injected readings rather than real hardware. Surfaced in
    /// the popover: the two are otherwise indistinguishable, which has already produced one
    /// false bug report against a forgotten test instance.
    var isSimulated: Bool { SimulatedReadings.isActive }

    func openNotificationSettings() { notifier.openNotificationSettings() }

    /// Re-reads permission, so the popover stops claiming a denial once the user has fixed
    /// it in System Settings. Nothing else in the app notices that change.
    func refreshAuthorization() { notifier.refreshAuthorization() }
}
