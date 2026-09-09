# Changelog

User-facing changes. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Internal session history is in `docs/claude/PROGRESS.md`.

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
- Starts at login, with a toggle to turn that off.
- Diagnostics: `--dump-devices`, `--dump-label` and `--simulate` for driving states by hand.
- App icon: a Magic Mouse silhouette used as the battery gauge.
- Charging state in the menu bar: a bolt beside the level, shown at any percentage rather than
  only below the alert threshold, so a device put on a cable can be watched filling.
- A Notifications section in the popover: alert sound picker, and a developer mode that fires
  an alert for any device at any level, so a warning can be seen at 3% without draining a
  device to 3%.
- A `--test-notification` argument that runs the same path from a terminal.
- Notifications carry a gauge image tinted by the level.

### Changed — settings and alerts reworked
- The two levels are set on one two-handle slider with coloured bands instead of two steppers.
  The handles cannot cross, so the interdependency that used to block a press silently is now
  physical, and the bands show what each level means without a sentence.
- The menu bar reading can be shown below either level, or always.
- Notifications have a master switch and two independent rules — every 5% and every 1%, each
  pointed at either level. Where both apply the finer one wins outright, so no configuration
  produces two alerts for one drop. Turning off the 1% rule is the "stop nagging me" setting.
- **Two reminders tied to a moment rather than a level**: one as the Mac goes to sleep, one at
  a chosen hour each day. Both fire only if something is below the warn level, and neither
  consumes the ordinary cadence. This is the half the app was missing — a percentage arriving
  mid-task is a more detailed ambush, where the same reading at bedtime is actionable.
- The alert sound plays when you pick it, and "None" is now an option, so notifications can be
  silenced without going near System Settings.

### Fixed
- **"High contrast alerts", off by default**, draws the menu bar alert as a solid badge with
  dark content and marks the urgent level with a warning symbol as well as a colour. It answers
  two measured problems for anyone they affect: the standard style's warn orange is 2.20:1
  against a light menu bar where text wants 4.5:1, and orange and red simulate to nearly the
  same olive-yellow for red-green colourblind users, so hue alone cannot separate the two
  levels. Named for what it does, not for who needs it.
- The menu bar alert image has an accessibility description, so VoiceOver announces the device,
  level and state rather than nothing.
- **Repeated alerts for a battery that had not moved.** A one-point rise in a Bluetooth reading
  was treated as a recharge and re-armed every warning level, producing an alert per tick all
  the way back down. Alerts now track the lowest level seen, so noise cannot re-arm anything.
- Notifications and menu bar text named the wrong device when the monitored device was changed.
  Names now come from the system.

### Removed
- SwiftBar, `terminal-notifier`, the launchd agent and the shell installer. The app has no
  third-party dependencies and no background job.

### Fixed
- **A charging device no longer hides a dying one.** Charging used to win the menu bar
  outright, so a keyboard on a cable at 90% hid a mouse at 4% while a notification called that
  same mouse critical. A device below the warn level now outranks a charging one.
- **A low device that goes quiet no longer cancels its own alarm.** A peripheral drops out of
  the system entirely when it sleeps, which turned a red warning back into the calm idle glyph
  at the end of the drain curve. Its last reading is kept and shown dimmed for half an hour.
  Only devices that were already low are remembered, so unpairing a healthy one removes it
  from the list at once.
- **The notification image collapsed every level at or below 6%** into an identical picture,
  the same fill-floor mistake already fixed in the menu bar.
- Notification permission was re-checked every 5 seconds, an inter-process call about
  seventeen thousand times a day. It now happens when the panel opens.
- The device list was republished every tick even when unchanged, recomposing the menu bar
  image forever.

### Changed
- **Warnings now start at the upper threshold.** Crossing it used to change only the menu bar,
  so the first thing that actually interrupted arrived at 9%. One alert on crossing, then every
  5% down to the lower threshold, then every 1% below it.
- A device's alerts are grouped, so a full drain is one expandable stack rather than eleven
  separate rows to dismiss.
- The panel says when it is showing simulated readings instead of real hardware.
- Alerts default to the Hero sound.
- The notification image uses the device's own symbol, so a keyboard alert no longer shows a
  mouse, and the symbol is centred on the tile with the level moved to a strip along the
  bottom edge.
- The charging bolt sits white in the middle of the menu bar gauge, legible against every fill
  colour and against the empty track.
- Charging appears immediately. The app now listens for IOKit's own notifications rather than
  waiting for a poll, and the poll itself dropped from 60 seconds to 5.
- Threshold labels say what they mean: "Show battery level in menu bar when below" and
  "Notify on every % drop below".
- One text size throughout the popover, with the footer the only deliberate exception.
  Hierarchy now comes from weight and colour rather than from size.

### Known issues
- Charging detection reads an undocumented flag that has only ever been observed at rest.
  Believed correct, not yet confirmed against a device on a cable.
- macOS posts its own low-battery warnings at 6% and 3%, so two alerts arrive near the end
  until Apple's are silenced separately in System Settings.

## [0.1.0] — 2026-04-21

Initial bash scaffold. Never tagged, released or installed.
