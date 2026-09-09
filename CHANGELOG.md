# Changelog

User-facing changes. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Internal session history lives in `docs/claude/PROGRESS.md`.

## [Unreleased]

### Added
- Documentation workflow: `CLAUDE.md` and the `docs/claude/` set (architecture, roadmap, features,
  open work, progress index).

### Known issues
- A one-point upward blip in a battery reading re-arms every notification threshold, producing
  repeated alerts for a battery that has not moved.
- Changing `LAUNCHD_LABEL` in `config.sh` makes `install.sh` fail on a missing template.
- Notification and menu bar text say "Magic Mouse" regardless of the configured device.
- Only one device is monitored; the Magic Keyboard constant in `config.sh` is unused.

## [0.1.0] — 2026-04-21

Initial scaffold. Never tagged or released.

### Added
- Shared battery-read library with a testable, stdin-driven plist parser.
- launchd notifier firing on threshold crossings at 20%, 15%, 10%, then every integer below.
- SwiftBar menu bar plugin with colour-coded percentage, refreshing every 5 minutes.
- Idempotent installer and an uninstaller that prompts before removing state.
- Test suite covering the parser against a mock registry dump.
