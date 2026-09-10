# magicbar — Feature Catalogue

Every feature by status. New ideas go **here**, not in `TODO.md`. Sequencing is in
[`ROADMAP.md`](./ROADMAP.md); open work with a known next action is in [`TODO.md`](./TODO.md).

**Statuses:** Shipped · Committed · Idea · Blocked · Declined

*Rewritten 2026-09-08.*

---

## Summary — everything not yet shipped

| Feature | Status | Next step |
|---|---|---|
| Charge-complete alert | Idea | Needs a charged state, which needs the flag pinned |
| Keep a sleeping device visible | Committed | Decide the staleness cutoff |
| Both devices in the menu bar at once | Idea | Decide how wide is too wide |
| Notification actions (snooze) | Idea | Confirm actions survive from an agent app |

---

## Shipped

### Drain estimate — 2026-09-09

"About three days left" under each device in the popover, and inside the daily reminder so it
says something the menu bar does not. A least-squares slope through readings sampled on change
rather than on the timer, cleared by a charge, and silent until three samples span six hours.
`--dump-estimate` prints the series and the fit. Detail in `ARCHITECTURE.md`.

### Sleep reminder — built and removed, 2026-09-09

Warning the user as they put the Mac to sleep is not possible: the display and the audio device
are both already off when an app is told a sleep is happening, measured twice. Delivering it at
wake instead worked, but a Magic Mouse charges port-down and cannot be used while charging, so
wake is the one moment the user cannot act. Removed rather than left half-useful. The
measurements are kept in `ARCHITECTURE.md` so it is not attempted again.

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

### App icon — v1.0.0

A Magic Mouse silhouette acting as the battery gauge, drawn by `scripts/render-icon.swift` and
rendered natively at each size. Same idea as the menu bar: a device shape carrying a level.

### Level slider and reworked alert rules — v1.1.0

Two handles on one 0–50 track with coloured bands, replacing two steppers whose bounds moved
against each other invisibly. Notifications gained a master switch and two independently
targeted rules, finer-wins.

### Reminders tied to a moment — v1.1.0

One as the Mac sleeps, one at a chosen hour. The answer to the review's central finding: the
app knew the level but not the moment, so every warning landed mid-task.

### High contrast alerts — v1.1.0

Optional solid badge with dark content and a warning symbol at the urgent level. Answers a
2.20:1 contrast failure on light menu bars and the fact that the two levels are the same colour
under deuteranopia.

### Launch at login — v1.0.0

`SMAppService`, registered on first launch, revocable from the popover.

---

## Committed

### Keep a sleeping device visible

A disconnected peripheral vanishes from the registry, so it vanishes from the popover, which
looks like a bug rather than a sleeping mouse. Show the last known level with a timestamp
instead. Needs a staleness cutoff decision.

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

---

## Blocked

Nothing.

## Declined

### Configuration file

Considered and rejected during the rewrite. The two thresholds are the only settings, and a
popover control beats a file that needs a re-install to take effect — which is exactly what
the bash version required.
