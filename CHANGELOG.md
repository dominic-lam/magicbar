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

### Fixed
- **Repeated alerts for a battery that had not moved.** A one-point rise in a Bluetooth reading
  was treated as a recharge and re-armed every warning level, producing an alert per tick all
  the way back down. Alerts now track the lowest level seen, so noise cannot re-arm anything.
- Notifications and menu bar text named the wrong device when the monitored device was changed.
  Names now come from the system.

### Removed
- SwiftBar, `terminal-notifier`, the launchd agent and the shell installer. The app has no
  third-party dependencies and no background job.

### Changed
- Alerts default to the Hero sound.
- The notification image uses the device's own symbol, so a keyboard alert no longer shows a
  mouse, and centres the glyph and level bar as a group.
- The charging bolt sits in the middle of the menu bar gauge, knocked out of it so it reads
  against both the filled and empty parts.
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
