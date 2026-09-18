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
| Keep a sleeping device visible | Committed | Low devices done; decide whether healthy ones stay too |
| Both devices in the menu bar at once | Idea | Decide how wide is too wide |
| Notification actions (snooze) | Idea | Confirm actions survive from an agent app |
| Homebrew tap | Idea | Decide whether one extra repo is worth it |
| Battery wear from the drain-rate trend | Idea | Needs months of kept rates first |
| Per-level drain correction | Idea | Needs 3–5 recorded cycles to separate battery from habit |
| Measure device use directly | Idea | Confirm the idle-time call needs no permission |

---

## Shipped

### Update check — v1.2.0

Once a day, and on a "Check now" click, the app asks GitHub for the newest non-prerelease tag.
A newer one turns the popover footer into "Version … available", linking to the Releases page.
It never downloads or installs anything. The app's only network access, on by default, one
checkbox to turn off. The footer also shows the version number, replacing "Updates live", which
read as a claim about software updates. Detail in `ARCHITECTURE.md`.

### Drain estimate — 2026-09-09, reworked 2026-09-13

"About three days left" under each device in the popover, and inside the daily reminder so it
says something the menu bar does not. One least-squares rate fitted across every run between
charges, because use habits outlast a battery: a top-up no longer blanks the estimate. Quiet
time up to now counts, and nothing is shown until a full day of history exists.
`--check-estimate` runs the rule on synthetic cases; detail in `ARCHITECTURE.md`.

### Use estimate — 2026-09-18, unreleased

"About 84 hours of use left", shown under the clock estimate at every level so the two can be
judged against each other. The median time per 1% drop, over drops under 1.5 hours apart — the
ones quick enough to have been continuous use. Added because the first real run showed the clock
estimate limited by a sixfold swing in daily use that no model could predict, while drain per
hour of use held within about 2×. A keyboard never qualifies. Both estimates are logged at every
recorded change. Detail in `ARCHITECTURE.md`.

### Charge estimate — 2026-09-18, unreleased

"About 1 hr 3 min to full" while on the cable. Charges are recorded as their own runs (the last
ten kept), and each remaining percent costs the median it cost on earlier charges, falling back
to the median of all steps for a level never seen — so the first charge reads as a straight line
and runs optimistic, and later ones know the taper. To the minute, unlike the drain phrases. Not
yet scored against a completed charge.

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

A disconnected peripheral vanishes from the registry. A device that vanishes below the warn
level already stays listed for 30 minutes marked "last seen" (confirmed 2026-09-12); a healthy
one still disappears, which looks like a bug rather than a sleeping mouse. Open: whether
healthy devices should stay too.

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

### Homebrew tap

A personal tap (`dominic-lam/homebrew-tap`) would give `brew install dominic-lam/tap/magicbar`
and updates through `brew upgrade`, with the release workflow bumping the cask on each tag. It
would not remove the Gatekeeper step. The official `homebrew-cask` is closed to this app twice
over: casks failing Gatekeeper lose support from 2026-09-01, and a self-submitted cask needs
225 stars, 90 forks and 90 watchers (checked 2026-09-12 against Homebrew's docs).

### Per-level drain correction

The first real run drained about twice as fast in use below 10% and above 30% as in between,
which is what a voltage-derived gauge with an imperfect table would produce. A small table of how
long each percent takes relative to the average — learned slowly across cycles, separate from the
fast-moving rate — would stop the estimates running optimistic near empty. One run cannot separate
the battery from the week it happened in: the fast top band fell on the heaviest day. The charge
estimate already works this way, because a charge is repeatable.

### Measure device use directly

The use estimate infers "in use" from gaps between readings. macOS reports seconds since the last
mouse movement (`CGEventSource.secondsSinceLastEventType`), believed to need no permission —
unchecked. Logging active hours would give percent per hour of use directly, and a time-of-day
pattern at five-second rather than one-percent resolution. It counts any pointing device, so a
trackpad would muddy it.

### Battery wear from the drain-rate trend

*Recorded 2026-09-14.* macOS exposes no health reading for these peripherals — no cycle count,
no maximum capacity. Their registry entries carry only `BatteryPercent` and
`BatteryStatusFlags`; the `CycleCount` and `MaxCapacity` found in the registry belong to the
Mac's own `AppleSmartBattery`, which reads `BatteryInstalled = No` on this desktop. Wear would
have to be inferred: habits are steady, so if the fitted percent-per-day creeps up over months,
the battery holds less. The storage obstacle is gone as of 2026-09-16 — the history is no longer
trimmed, so months of rates now accumulate — but the hard one remains: a change of habit looks
exactly like wear, and whole-percent readings hide a 10–20% drift for a long time. A second weak signal is charge speed — a worn battery fills its smaller capacity
faster — but charger, cable and use during charging move it as much.

---

## Blocked

Nothing.

## Declined

### Updates that install themselves — declined 2026-09-12

Chosen instead: a notice that links to the Releases page. A self-written download-and-replace
would hand every installed copy to whoever controls the GitHub account. Sparkle guards against
that with a separate signing key, but it is a third-party dependency and needs that key in CI.
Release builds are also ad-hoc signed, so each version may look like a new app to macOS —
unverified.

### Configuration file

Considered and rejected during the rewrite. The two thresholds are the only settings, and a
popover control beats a file that needs a re-install to take effect — which is exactly what
the bash version required.
