import Foundation
import ServiceManagement

/// Registers the app to start at login.
///
/// The bash implementation got this free from a launchd agent with `RunAtLoad`. Without an
/// equivalent, the app would have to be opened by hand after every restart, and a battery
/// monitor that is not running is worse than useless — it is quietly reassuring.
///
/// `SMAppService` rather than a hand-written LaunchAgent: macOS 13+ surfaces manually
/// installed agents in Login Items anyway, so nothing is gained by hiding, and this gives a
/// status that can be logged and a toggle the popover can drive.
enum LoginItem {

    /// Registration binds to the app's **current path**. An app registered from a build
    /// directory leaves a dangling login item as soon as that directory is cleaned, so the
    /// app should live somewhere permanent before this is switched on.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func log() {
        NSLog("[magicbar] login item status=\(SMAppService.mainApp.status.rawValue) path=\(Bundle.main.bundlePath)")
    }

    /// Returns whether the request succeeded, so the UI can reflect reality rather than
    /// the intent. Registration requires a signed app; it fails otherwise.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                // Re-registering a changed executable is documented as unreliable unless
                // the old registration is removed first, and unregistering something that
                // was never registered is harmless.
                try? SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            NSLog("[magicbar] login item set to \(enabled), status=\(SMAppService.mainApp.status.rawValue)")
            return true
        } catch {
            NSLog("[magicbar] login item change failed: \(error.localizedDescription)")
            return false
        }
    }
}
