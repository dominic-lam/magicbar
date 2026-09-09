# magicbar — Project Brief

Fast snapshot for picking the project back up. Everything here is verified unless marked otherwise.

*Written 2026-09-08.*

## In one line

A pair of bash consumers that read Apple peripheral battery levels from the macOS IOKit registry and
show them in the menu bar and as threshold notifications.

## Current status

**Built, never installed.** Complete since 2026-04-21, two commits, clean tree, pushed to
`git@github.com:dominic-lam/magicbar.git`. No launch agent loaded, no `~/.magicbar/`, no SwiftBar
plugin installed. A predecessor set of hand-written scripts did the real work until 2026-09-08.

## Runtime flow

```
ioreg -r -k BatteryPercent -a
        → lib/read_battery.sh (parse by ProductID, via python3 plistlib)
            → bin/battery_alert.sh   launchd every 15m, notifies on threshold crossings
            → swiftbar/magicbar…     SwiftBar every 5m, menu bar percentage
```

Both consumers are rendered from templates at install time with this repo's absolute path baked in.

## Key files

| File | Why you would open it |
|---|---|
| `config.sh` | Every user-editable constant. Sourced, never executed. |
| `lib/read_battery.sh` | The only place that knows how to read a battery. |
| `bin/battery_alert.sh` | Threshold logic and state machine. |
| `install.sh` | Template rendering, dependency install, agent loading. |
| `tests/test_read_battery.sh` | The entire test suite. |
| `MIGRATION.md` | Decommissioning the predecessor. Gitignored, this machine only. |

## Commands

```bash
bash tests/test_read_battery.sh   # whole suite, ~1s
./install.sh                      # idempotent
bash bin/battery_alert.sh         # force one notifier run
tail -f ~/.magicbar/launchd.log   # runtime log
ioreg -r -k BatteryPercent -a     # ground truth for ProductIDs
```

## Gotchas

- **Moving the repo breaks a live install.** Absolute paths are baked into the rendered plist and
  plugin. Re-run `./install.sh` after any move, and after any `config.sh` edit.
- **State stores a threshold, not a percentage.** They coincide below 10% only.
- **`terminal-notifier` is load-bearing.** osascript from launchd is dropped silently on modern macOS.
- **launchd's `PATH` excludes Homebrew.** The notifier prepends both brew prefixes itself.
- **Only one device is ever read**, despite a keyboard constant existing in config.
- **`~/.claude/scripts/notify-done.sh` also uses `terminal-notifier`.** Unrelated to this project, but
  it means not every notifier launch in the system log is a battery alert.

## Known defects

Four, all documented in `TODO.md` § Active and `ARCHITECTURE.md` § Known limitations: the blip cascade,
the `LAUNCHD_LABEL` installer break, hardcoded device names, and the stale unverified-ProductID comment.

## Verified hardware

| Device | ProductID |
|---|---|
| Magic Mouse 2/3 | 617 |
| Magic Keyboard | 620 |

Both read off this machine on 2026-09-08.
