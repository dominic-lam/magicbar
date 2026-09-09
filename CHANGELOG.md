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

### Fixed
- **Repeated alerts for a battery that had not moved.** A one-point rise in a Bluetooth reading
  was treated as a recharge and re-armed every warning level, producing an alert per tick all
  the way back down. Alerts now track the lowest level seen, so noise cannot re-arm anything.
- Notifications and menu bar text named the wrong device when the monitored device was changed.
  Names now come from the system.

### Removed
- SwiftBar, `terminal-notifier`, the launchd agent and the shell installer. The app has no
  third-party dependencies and no background job.

### Known issues
- Notification permission must be granted by hand in System Settings › Notifications. macOS
  recorded a refusal during development and will not re-prompt.
- Alerts still fire for a device that is charging. The charging flag is not yet decoded.
- No app icon yet.

## [0.1.0] — 2026-04-21

Initial bash scaffold. Never tagged, released or installed.
