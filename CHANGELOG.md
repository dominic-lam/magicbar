# Changelog

User-facing changes. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Internal session history is in `docs/claude/PROGRESS.md`.

## [1.1.0] — 2026-09-09

Reshaped after a design review. Fifteen of 37 findings closed; the rest are triaged in
`docs/claude/debriefs/2026-09-08-design-review.md`.

### Added
- **Two reminders tied to a moment rather than a level** — one as the Mac goes to sleep, one at
  a chosen hour each day. Both fire only if something is below the warn level, and neither
  consumes the ordinary cadence. This was the half the app was missing: a percentage arriving
  mid-task is a more detailed ambush, where the same reading at bedtime is actionable.
- **"High contrast alerts"**, off by default. Draws the menu bar alert as a solid badge with
  dark content and marks the urgent level with a warning symbol as well as a colour.
- The menu bar reading can now be shown below either level, or always.
- The alert sound plays when you pick it, and "None" is an option, so notifications can be
  silenced without going near System Settings.

### Changed
- **The two levels are set on one two-handle slider** with coloured bands instead of two
  steppers. The handles cannot cross, so the interdependency that used to block a press
  silently is now physical, and the bands show what each level means without a sentence.
- **Notifications have a master switch and two independent rules** — every 5% and every 1%,
  each pointed at either level. Where both apply the finer one wins outright, so no
  configuration produces two alerts for one drop. Turning off the 1% rule is the standing
  "stop nagging me" setting.
- The panel says when it is showing simulated readings instead of real hardware.

### Fixed
- **A charging device no longer hides a dying one.** Charging used to win the menu bar outright,
  so a keyboard on a cable at 90% hid a mouse at 4% while a notification called that same mouse
  critical.
- **A low device that goes quiet no longer cancels its own alarm.** A peripheral vanishes from
  the system when it sleeps, which turned a red warning back into the calm idle glyph at the end
  of the drain curve. Only devices that were already low are remembered, so unpairing a healthy
  one removes it from the list at once.
- **The notification image collapsed every level at or below 6%** into an identical picture, the
  same fill-floor mistake already fixed in the menu bar.
- **Device state survives a cable.** The same mouse reports a different serial and a different
  name over Bluetooth and over USB, so its alert history used to reset when plugged in.
- The menu bar alert has an accessibility description, so VoiceOver announces the device, level
  and state rather than nothing.
- Notification permission was re-checked every 5 seconds, an inter-process call about seventeen
  thousand times a day. It now happens when the panel opens.
- The device list was republished every tick even when unchanged, recomposing the menu bar image
  forever.

### Known issues
- The sleep and daily reminders are built but have never fired.
- macOS posts its own low-battery warnings at 6% and 3%, so two alerts arrive near the end until
  Apple's are silenced separately in System Settings.
- No signed build and no release. Installing means building from source.

## [1.0.0] — 2026-09-08

Rewritten as a native macOS menu bar app. The bash implementation is preserved at the
`bash-final` tag.

### Added
- Menu bar app with two states: a plain glyph while every device is healthy, and the low
  device's own icon with a level bar and percentage below the alert threshold.
- Popover listing every discovered device with a level bar.
- Adjustable thresholds, replacing the old config file.
- Automatic device discovery. Any Apple peripheral reporting a battery is picked up and named
  from the system, so the Magic Keyboard is monitored without configuration.
- Charging state in the menu bar, shown at any percentage, with a white bolt in the gauge.
- Starts at login, with a toggle to turn that off.
- An app icon: a Magic Mouse silhouette used as the battery gauge.
- Notifications carry a gauge image tinted by the level, and are grouped per device.
- Diagnostics: `--dump-devices`, `--dump-label`, `--simulate` and `--test-notification`.

### Changed
- Warnings start at the upper threshold. Crossing it used to change only the menu bar, so the
  first thing that actually interrupted arrived at 9%.
- Charging appears immediately: the app listens for IOKit's own notifications rather than
  waiting for a poll, and the poll dropped from 60 seconds to 5.
- One text size throughout the popover, with the footer the only deliberate exception.

### Fixed
- **Repeated alerts for a battery that had not moved.** A one-point rise in a Bluetooth reading
  was treated as a recharge and re-armed every warning level, producing an alert per tick all
  the way back down. Alerts now track the lowest level seen, so noise cannot re-arm anything.
- Notifications and menu bar text named the wrong device when the monitored device was changed.
  Names now come from the system.
- The menu bar level bar drew the same width for every reading below a third full.

### Removed
- SwiftBar, `terminal-notifier`, the launchd agent and the shell installer. The app has no
  third-party dependencies and no background job.

## [0.1.0] — 2026-04-21

Initial bash scaffold. Never tagged, released or installed.
