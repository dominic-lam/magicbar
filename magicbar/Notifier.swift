import Foundation
import UserNotifications

/// Delivers the low-battery alerts.
///
/// The bash implementation shelled out to `terminal-notifier` because notifications posted
/// from a launchd job have no owning app bundle and macOS drops them silently. A real app
/// bundle is its own owner, so that dependency disappears here.
///
/// **`UNUserNotificationCenter.current()` terminates the process when there is no bundle.**
/// It asserts `bundleProxyForCurrentProcess is nil` and raises, which is what happens if
/// the raw executable inside the `.app` is run directly instead of through the bundle.
/// Every entry point below is therefore guarded by `isBundled`, so diagnostic launch
/// arguments stay usable from a bare binary.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {

    private var authorized = false

    /// A bare executable has no bundle identifier. Touching the notification centre in
    /// that state is fatal rather than merely useless, so it is checked before every call.
    private let isBundled = Bundle.main.bundleIdentifier != nil

    /// Asks once at launch. A refusal is not fatal and is never retried — the menu bar
    /// still shows every level, so a user who declines keeps the monitoring and loses only
    /// the nagging.
    ///
    /// There is no way back from a denial: `requestAuthorization` will not re-prompt, and
    /// notification permission lives in `ncprefs` rather than TCC, so there is no reset
    /// command either. The current status is logged at every launch because that is the
    /// only way to see this state from a terminal.
    func start() {
        guard isBundled else {
            NSLog("[magicbar] not running from a bundle, notifications disabled")
            return
        }

        let center = UNUserNotificationCenter.current()
        // Set before requesting, so nothing can arrive without a delegate in place.
        center.delegate = self

        center.getNotificationSettings { settings in
            NSLog("[magicbar] notification authorization status=\(settings.authorizationStatus.rawValue)")
        }

        // No `.badge`: there is no Dock icon to badge.
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                self.authorized = granted
                if let error {
                    NSLog("[magicbar] notification authorization failed: \(error.localizedDescription)")
                } else {
                    NSLog("[magicbar] notification authorization granted=\(granted)")
                }
            }
        }
    }

    func notifyLowBattery(device: Device) {
        guard isBundled, authorized else {
            NSLog("[magicbar] suppressed alert for \(device.shortName) at \(device.percent)%")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(device.shortName) battery low"
        content.body = "\(device.percent)% remaining"
        content.sound = .default

        // A nil trigger delivers immediately. Identifiers are unique per device and level,
        // so each percent stands alone in Notification Center rather than replacing the last.
        let request = UNNotificationRequest(
            identifier: "magicbar.\(device.id).\(device.percent)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[magicbar] notification delivery failed: \(error.localizedDescription)")
            } else {
                NSLog("[magicbar] notified \(device.shortName) at \(device.percent)%")
            }
        }
    }

    /// macOS suppresses notifications while the posting app is frontmost.
    ///
    /// An agent app is normally never frontmost, but a `.window`-style `MenuBarExtra`
    /// activates the app for as long as its popover is open — which is exactly when the
    /// user is looking at battery levels and most likely to cross a threshold. Without
    /// this the alert would be swallowed in that window.
    ///
    /// `.alert` is deprecated in favour of `.banner` and `.list`.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
