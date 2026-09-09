# magicbar — Feature Catalogue

Every feature by status. New ideas go **here**, not in `TODO.md`. Sequencing is in
[`ROADMAP.md`](./ROADMAP.md); open work with a known next action is in [`TODO.md`](./TODO.md).

**Statuses:** Shipped · Committed · Idea · Blocked · Declined

*Rewritten 2026-09-08.*

---

## Summary — everything not yet shipped

| Feature | Status | Next step |
|---|---|---|
| Suppress alerts while charging | Committed | Decode `BatteryStatusFlags` with a device plugged in |
| Keep a sleeping device visible | Committed | Decide the staleness cutoff |
| App icon | Committed | Adapt Range's Core Graphics battery script |
| Both devices in the menu bar at once | Idea | Decide how wide is too wide |
| Notification actions (snooze) | Idea | Confirm actions survive from an agent app |
| Sleep/wake awareness | Idea | Measure how late the first post-wake reading is |

---

## Shipped

### Native menu bar app — v1.0.0

SwiftUI `MenuBarExtra` in window style. Two label states, both drawn as `NSImage` through
AppKit because SwiftUI cannot colour a menu bar label. Detail in `ARCHITECTURE.md`.

### Automatic device discovery — v1.0.0

Every peripheral publishing a battery in the IO registry is picked up and named from the
system. Replaced the hardcoded product IDs, and delivered keyboard support as a side effect
rather than as a feature.

### Low-water-mark alerting — v1.0.0

One notification per percent lost below the nag threshold, and none at all for a reading that
wobbles upward. Replaced the threshold ladder that caused the original alert cascade.

### Adjustable thresholds — v1.0.0

Both live in the popover and persist in `UserDefaults`, replacing `config.sh`.

### Launch at login — v1.0.0

`SMAppService`, registered on first launch, revocable from the popover.

---

## Committed

### Suppress alerts while charging

A device on a cable is still nagged about. `BatteryStatusFlags` reads 0 for both devices and its
bit meanings are undecoded — decoding needs a device actually plugged in.

### Keep a sleeping device visible

A disconnected peripheral vanishes from the registry, so it vanishes from the popover, which
looks like a bug rather than a sleeping mouse. Show the last known level with a timestamp
instead. Needs a staleness cutoff decision.

### App icon

`Assets.xcassets/AppIcon.appiconset` is empty. Range's `scripts/render-icon.swift` already
draws a battery with Core Graphics and takes fill colours as arguments.

---

## Idea

### Both devices in the menu bar at once

Currently the lower device wins and the other is one click away. Showing both is wider and
was explicitly not chosen, but it would remove the click.

### Notification actions

A "snooze" button on the alert. Whether actions behave from an agent app with no Dock icon is
unverified.

### Sleep/wake awareness

After a long sleep the first reading is up to a poll interval late. An `NSWorkspace`
wake observer would make it immediate.

### Charge-rate estimate

"About 3 days left" rather than a percentage, from the observed drain rate. Needs history,
which nothing currently keeps.

---

## Blocked

Nothing.

## Declined

### Configuration file

Considered and rejected during the rewrite. The two thresholds are the only settings, and a
popover control beats a file that needs a re-install to take effect — which is exactly what
the bash version required.
