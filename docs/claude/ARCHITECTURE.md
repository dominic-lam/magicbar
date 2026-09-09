# magicbar — Architecture & Technical Details

Core tech, data flow, conventions, known limitations. Open work lives in [`TODO.md`](./TODO.md);
feature descriptions in [`FEATURES.md`](./FEATURES.md); what shipped in [`PROGRESS.md`](./PROGRESS.md).

*Written 2026-09-08 against the initial scaffold (`f0e168b`) — nothing here has changed since the repo was created.*

---

## Core Tech — How It Works

### Reading a battery level (verified 2026-09-08)

macOS exposes peripheral battery levels through the IOKit registry. The only supported way to reach
them without writing an IOKit client in Swift or Objective-C is the `ioreg` CLI:

```
ioreg -r -k BatteryPercent -a
```

That emits an XML plist of every device publishing a `BatteryPercent` key. Each device dict carries a
`ProductID`, which is how a specific peripheral is picked out.

Parsing is done in Python via `plistlib` rather than in bash, because `ioreg`'s XML has enough shape
variation that text munging is unreliable. Notably a single match can arrive as a bare dict rather than
a one-element array, which the parser normalizes.

### Known ProductIDs

| Device | ProductID | Status |
|---|---|---|
| Magic Mouse 2/3 | 617 | Verified on this machine |
| Magic Keyboard | 620 | Verified on this machine 2026-09-08 |

`config.sh` still labels 620 as unverified. That comment is stale and should be corrected.

Anyone on different hardware should run the `ioreg` command above and read their own values.

### The shared library

`lib/read_battery.sh` exposes two functions, deliberately split:

- `parse_battery_percent <product_id>` — reads a plist from **stdin**, prints the integer percentage
  for the first device matching that ProductID. Exit 0 on success, exit 1 on no match or malformed
  input. Never writes to stderr. This is the testable half; it touches no hardware.
- `read_battery_percent <product_id>` — wraps `ioreg | parse_battery_percent`. This is what real
  consumers call.

The file is **sourced, not executed**, and deliberately omits `set -euo pipefail` so the caller owns
its own error discipline.

`ioreg`'s stderr is discarded because Bluetooth churn (disconnects, pairing events) leaks warnings
that would otherwise fill the launchd log with noise.

### Data flow

```
                    ioreg -r -k BatteryPercent -a
                                │
                                ▼
                ┌──────────────────────────────────┐
                │  lib/read_battery.sh             │
                │    parse_battery_percent <pid>   │  ← testable, stdin-driven
                │    read_battery_percent  <pid>   │  ← consumers call this
                └──────────────────────────────────┘
                         ▲                    ▲
                         │                    │
          ┌──────────────┴──────┐     ┌───────┴────────────┐
          │ bin/battery_alert.sh│     │ swiftbar/magicbar  │
          │   launchd, 15m      │     │   SwiftBar, 5m     │
          │   threshold notify  │     │   menu bar text    │
          │   stateful          │     │   stateless        │
          └─────────────────────┘     └────────────────────┘
```

Two consumers, one library. They do not know about each other — removing one leaves the other working.

---

## The notifier state machine

`bin/battery_alert.sh` runs on a 15-minute launchd interval and fires at most one notification per run.

**State is the threshold last fired at, not the battery reading.** `$STATE_FILE` holds a single bare
integer with no device identity. The two values coincide below 10% only because every integer there is
its own threshold; above 10% they diverge (a drop straight to 14% stores 20, not 14).

Each run walks `NOTIFICATION_THRESHOLDS` in descending order and fires on the first `T` where the
battery is at or below `T` **and** `T` is below the stored value, then breaks.

A reading **above** the stored value is treated as a recharge: state resets to 101 and every threshold
re-arms. See § Known limitations — this is the source of a real bug.

An unreadable device causes a silent exit with no state mutation. That is the normal case for a
sleeping or disconnected peripheral, not an error.

---

## Install-time template rendering

`launchd/*.plist.template` and `swiftbar/*.sh.template` are not runnable as-is. `install.sh` renders
them with `sed`, substituting three placeholders:

| Placeholder | Becomes |
|---|---|
| `{{INSTALL_DIR}}` | Absolute path of this repo |
| `{{LAUNCHD_LABEL}}` | `LAUNCHD_LABEL` from `config.sh` |
| `{{HOME}}` | `$HOME` |

Rendered output goes to `~/Library/LaunchAgents/` and the SwiftBar plugins folder.

**The rendered copies bake in this repo's absolute path.** Moving or renaming the repo after install
silently breaks both consumers — they keep pointing at the old location. Re-run `./install.sh` after
any move. Editing `config.sh` also requires a re-install before the rendered artifacts pick it up.

---

## Coding conventions

- `config.sh` is sourced, never executed. Every user-editable constant lives there and is read by
  `install.sh`, the notifier, and the SwiftBar plugin.
- Both consumers set `set -euo pipefail` themselves and call the library with `|| true`, because a
  missing device is expected rather than exceptional.
- The notifier prepends both Homebrew prefixes to `PATH`. launchd supplies a minimal environment that
  excludes Homebrew, so `terminal-notifier` will not resolve without it.
- Sources carry `# shellcheck source=` directives, but shellcheck is not installed and not in CI.

### Tool choices, and why they are not negotiable

- **`ioreg`** — the only supported route to peripheral `BatteryPercent` short of a full IOKit client.
- **`launchd`, not `cron`** — macOS has deprecated cron, and cron-fired notifications do not reliably
  reach Notification Center.
- **`terminal-notifier`, not `osascript`** — osascript notifications fired from launchd have no owning
  app bundle and are dropped silently on recent macOS. Do not "simplify" this away.
- **SwiftBar** — turns a stdout protocol into a menu bar item with no boilerplate.

---

## Testing

`tests/test_read_battery.sh` is flat bash with a local `assert_eq` helper. No framework, no runner, no
single-test flag — comment out cases to isolate one. It exercises `parse_battery_percent` only, against
a hand-written mock plist covering three ProductIDs.

Coverage: matching ID, second matching ID, unknown ID (empty stdout + exit 1), malformed input
(empty stdout + exit 1).

`read_battery_percent`, the notifier's threshold logic, `install.sh` and `uninstall.sh` are untested.

Last run 2026-09-08: 6 assertions, all passing.

---

## Known limitations

Each of these is real, reproduced, and open. See [`TODO.md`](./TODO.md) for the work items.

### Only one device is ever monitored

`MENU_BAR_DEVICE_PRODUCT_ID` drives **both** consumers despite its name, and points at the mouse.
`MAGIC_KEYBOARD_PRODUCT_ID` is defined in `config.sh` and referenced nowhere.

Adding a second device is not a one-liner: `$STATE_FILE` holds one bare integer with no device
identity, so per-device state has to exist first.

### Device names are hardcoded in user-facing strings

The notification title says "Magic Mouse Low" and the SwiftBar dropdown says "Magic Mouse", regardless
of which ProductID is configured. Repointing the config at another device makes both lie.

### Changing `LAUNCHD_LABEL` breaks the installer

`install.sh` derives the *template source path* from `LAUNCHD_LABEL`:

```bash
PLIST_TEMPLATE="$INSTALL_DIR/launchd/${LAUNCHD_LABEL}.plist.template"
```

The template on disk is named after the default label, so changing the label makes the installer look
for a file that does not exist and exit. The label should substitute into the plist body only, never
select the source file. `README.md` currently invites users to change it.

### A one-point upward blip re-arms every threshold

The recharge check compares a live percentage against a stored *threshold*. A reading that rises by one
looks like a recharge, resets state to 101, and the ladder walks down again — one notification per
15-minute tick, most of them reporting a battery that never moved. Bluetooth levels do wobble by a point.

Reproduced 2026-09-08 against the predecessor script, whose logic is character-for-character identical:
a battery sitting at 7% with a single blip to 8% produced six notifications over ninety minutes.
