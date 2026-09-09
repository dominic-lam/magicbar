import Foundation
import AppKit
import SwiftUI
import UserNotifications

/// Delivers the low-battery alerts.
///
/// The bash implementation shelled out to `terminal-notifier` because notifications posted
/// from a launchd job have no owning app bundle and macOS drops them silently. A real app
/// bundle is its own owner, so that dependency disappears here.
///
/// **`UNUserNotificationCenter.current()` terminates the process when there is no bundle.**
/// It asserts `bundleProxyForCurrentProcess is nil` and raises, which is what happens if the
/// raw executable inside the `.app` is run directly. Every entry point below is guarded by
/// `isBundled`, so diagnostic launch arguments stay usable from a bare binary.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {

    @Published private(set) var isAuthorized = false

    /// Called once authorization is known. The store uses it to re-evaluate immediately,
    /// rather than leaving the user without an alert until the next poll a minute later.
    var onAuthorizationResolved: (() -> Void)?

    private let isBundled = Bundle.main.bundleIdentifier != nil

    /// Asks once at launch. A refusal is not fatal and is never retried — the menu bar still
    /// shows every level, so a user who declines keeps the monitoring and loses the nagging.
    ///
    /// There is no way back from a denial in code: `requestAuthorization` will not re-prompt,
    /// and notification permission lives in `ncprefs` rather than TCC, so there is no reset
    /// command either. Only System Settings can undo it, which is why the popover offers a
    /// button straight to that pane.
    func start() {
        guard isBundled else {
            NSLog("[magicbar] not running from a bundle, notifications disabled")
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
                NSLog("[magicbar] notification status=\(settings.authorizationStatus.rawValue) authorized=\(self.isAuthorized)")
                if self.isAuthorized { self.onAuthorizationResolved?() }
            }
        }

        // No `.badge`: there is no Dock icon to badge.
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if let error {
                    NSLog("[magicbar] authorization failed: \(error.localizedDescription)")
                } else {
                    NSLog("[magicbar] authorization granted=\(granted)")
                }
                if granted { self.onAuthorizationResolved?() }
            }
        }
    }

    /// Re-reads the real state, so the popover can stop claiming a denial after the user has
    /// fixed it in System Settings. Nothing else notices that change.
    func refreshAuthorization() {
        guard isBundled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func openNotificationSettings() {
        // The deep link to the Notifications pane. Falls back to the pane's own bundle id if
        // the URL scheme ever stops resolving.
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        NSWorkspace.shared.open(url)
    }

    /// Returns false when the alert could not be handed to the system, so the caller can
    /// leave its state alone and try again rather than recording a warning that never
    /// reached anyone. Authorization resolves asynchronously after launch, so the first poll
    /// of every run would otherwise silently swallow an alert.
    @discardableResult
    func notifyLowBattery(device: Device, color: Color, isTest: Bool = false) -> Bool {
        guard isBundled, isAuthorized else {
            NSLog("%@", "[magicbar] suppressed alert for \(device.shortName) at \(device.percent)%: authorized=\(isAuthorized)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = isTest
            ? "\(device.shortName) — test alert"
            : "\(device.shortName) \(urgencyWord(for: device.percent))"
        content.body = "\(device.percent)% remaining"
        content.sound = .default

        // Notification content carries no colour of its own — there is no tint API. An
        // attached image is the only way to make the alert itself look urgent, so the same
        // gauge the menu bar draws is rendered in the same colour and attached here.
        if let attachment = gaugeAttachment(device: device, color: color) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "magicbar.\(device.id).\(isTest ? "test-\(Date().timeIntervalSince1970)" : String(device.percent))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[magicbar] delivery failed: \(error.localizedDescription)")
            } else {
                NSLog("%@", "[magicbar] notified \(device.shortName) at \(device.percent)% test=\(isTest)")
            }
        }
        return true
    }

    /// Escalating wording, so the text carries urgency even where the image does not show —
    /// the notification list, the lock screen, or a summary.
    private func urgencyWord(for percent: Int) -> String {
        if percent <= 5 { return "battery critical" }
        if percent <= 10 { return "battery very low" }
        return "battery low"
    }

    /// Writes the gauge to a temp PNG and wraps it as an attachment.
    ///
    /// The file has to outlive this call: the notification centre copies it asynchronously,
    /// so it is written to the temp directory under a unique name rather than reused.
    private func gaugeAttachment(device: Device, color: Color) -> UNNotificationAttachment? {
        let image = MenuBarRenderer.gaugeImage(device: device, color: color, size: 256)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("magicbar-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return try UNNotificationAttachment(identifier: "gauge", url: url, options: nil)
        } catch {
            NSLog("[magicbar] attachment failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// macOS suppresses notifications while the posting app is frontmost.
    ///
    /// An agent app is normally never frontmost, but a `.window`-style `MenuBarExtra`
    /// activates the app for as long as its popover is open — which is exactly when the user
    /// might press the test button. Without this, that test would silently do nothing.
    ///
    /// `.alert` is deprecated in favour of `.banner` and `.list`.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
