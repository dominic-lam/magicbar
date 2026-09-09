import Foundation
import IOKit

/// Listens for the system telling us a peripheral changed, instead of only asking on a timer.
///
/// **Yes, it broadcasts.** IOKit publishes two kinds of event this app cares about, and both
/// are public API:
///
/// - `IOServiceAddMatchingNotification` with `kIOMatchedNotification` fires when a matching
///   service appears — a peripheral waking or reconnecting.
/// - `IOServiceAddInterestNotification` with `kIOGeneralInterest` fires when an existing
///   service's state changes. The device entries advertise this themselves: an
///   `IOGeneralInterest` key is visible in their registry properties.
///
/// Plugging a cable in changes the device's properties, so the interest notification is what
/// makes charging appear in the menu bar immediately rather than at the next poll. The timer
/// in `BatteryStore` stays as a safety net for anything this misses — a property change that
/// does not raise general interest would otherwise be invisible until something else happened.
///
/// The public power-source notification, `IOPSNotificationCreateRunLoopSource`, is **not**
/// usable here: it reports the sources `IOPSCopyPowerSourcesList` returns, and that list is
/// empty on this machine because Bluetooth accessories are a separate, private source type.
/// See `BatteryReader` for the measurement.
final class RegistryWatcher {

    private var port: IONotificationPortRef?
    private var matchIterator: io_iterator_t = 0
    private var interests: [io_object_t] = []
    private var onChange: (() -> Void)?

    private let serviceClass = "AppleDeviceManagementHIDEventService"

    deinit { stop() }

    /// Begins watching. The callback fires on the main queue, coalesced by the caller.
    func start(onChange: @escaping () -> Void) {
        stop()
        self.onChange = onChange

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            NSLog("[magicbar] could not create IOKit notification port; falling back to polling")
            return
        }
        self.port = port
        // Dispatching to main means the callbacks land where the store already lives, so no
        // hopping and no locking.
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let context = Unmanaged.passUnretained(self).toOpaque()

        // Fires for every service present now, and again whenever one appears. Draining the
        // iterator is not optional: an undrained iterator never fires again.
        let matchCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<RegistryWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.drainAndWatch(iterator)
        }

        let matching = IOServiceMatching(serviceClass)
        let result = IOServiceAddMatchingNotification(port,
                                                      kIOMatchedNotification,
                                                      matching,
                                                      matchCallback,
                                                      context,
                                                      &matchIterator)
        guard result == KERN_SUCCESS else {
            NSLog("[magicbar] matching notification failed (\(result)); falling back to polling")
            return
        }

        // The first drain both arms the notification and registers interest in the devices
        // that are already connected.
        drainAndWatch(matchIterator)
        NSLog("[magicbar] watching IOKit for peripheral changes")
    }

    func stop() {
        for interest in interests { IOObjectRelease(interest) }
        interests.removeAll()
        if matchIterator != 0 {
            IOObjectRelease(matchIterator)
            matchIterator = 0
        }
        if let port {
            IONotificationPortDestroy(port)
            self.port = nil
        }
    }

    /// Consumes every service the iterator holds, registering a property-change watch on each.
    private func drainAndWatch(_ iterator: io_iterator_t) {
        var sawService = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            sawService = true
            addInterest(to: service)
            // Not released here: the interest notification keeps its own reference and the
            // service object is released when that notification is torn down.
            IOObjectRelease(service)
        }
        if sawService { notifyChanged() }
    }

    private func addInterest(to service: io_service_t) {
        guard let port else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()

        let interestCallback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            let watcher = Unmanaged<RegistryWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.notifyChanged()
        }

        var notification: io_object_t = 0
        let result = IOServiceAddInterestNotification(port,
                                                      service,
                                                      kIOGeneralInterest,
                                                      interestCallback,
                                                      context,
                                                      &notification)
        if result == KERN_SUCCESS {
            interests.append(notification)
        } else {
            NSLog("[magicbar] interest notification failed (\(result))")
        }
    }

    private func notifyChanged() {
        // Already on main, because the port dispatches there.
        onChange?()
    }
}
