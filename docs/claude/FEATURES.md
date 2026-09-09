# magicbar — Feature Catalogue

Every feature by status, whatever its state. New ideas go **here**, not in `TODO.md`.
Sequencing is in [`ROADMAP.md`](./ROADMAP.md); open work with a known next action is in
[`TODO.md`](./TODO.md); technical detail is in [`ARCHITECTURE.md`](./ARCHITECTURE.md).

**Statuses:** Shipped · Committed · Idea · Blocked · Declined

*Created 2026-09-08.*

---

## Summary — everything not yet shipped

| Feature | Status | Next step |
|---|---|---|
| Multi-device monitoring (mouse + keyboard) | Committed | Decide the state file format |
| Configurable device display name | Committed | Add a constant to `config.sh` |
| Thinned sub-10% thresholds | Idea | Decide whether every integer is wanted |
| Both devices in the menu bar | Idea | Needs multi-device monitoring first |
| Notification actions | Idea | Confirm `terminal-notifier` support |

---

## Shipped

### Single-device battery read — v0.1.0

Reads `BatteryPercent` from the IOKit registry for one configured ProductID, via `ioreg` piped into a
Python `plistlib` parser. Split into a testable stdin-driven parser and a thin hardware wrapper.
Detail in `ARCHITECTURE.md` § Core Tech.

### Menu bar percentage — v0.1.0

SwiftBar plugin on a 5-minute refresh. Colour-coded: red at 10% or below, orange at 20% or below,
default above. Renders a neutral placeholder when the device is absent rather than an error.

### Threshold notifier — v0.1.0

launchd job on a 15-minute interval. Fires one notification per crossed threshold via
`terminal-notifier`. Thresholds are 20, 15, 10, then every integer from 9 down to 1.

### Install and uninstall — v0.1.0

Idempotent installer with preflight checks, dependency install, template rendering and agent loading.
Uninstaller reverses it and prompts before deleting state.

---

## Committed

### Multi-device monitoring

**The original point of the project, still unbuilt.** Watch the Magic Keyboard alongside the Magic
Mouse. `MAGIC_KEYBOARD_PRODUCT_ID` already exists in `config.sh` and is referenced nowhere.

**Blocked on state design.** `$STATE_FILE` is one bare integer with no device identity, so two devices
cannot share it. Options, undecided:

- One file per device (`~/.magicbar/state.617`) — trivial, no format to parse, no migration.
- One key-value file — one read, but needs parsing and a migration path from the bare integer.

Depends on the configurable display name below, otherwise a keyboard alert says "Magic Mouse".

### Configurable device display name

The notification title and SwiftBar dropdown hardcode "Magic Mouse". A display-name constant beside
`MENU_BAR_DEVICE_ICON` in `config.sh` fixes it. Small, but a prerequisite for anything multi-device.

---

## Idea

Nobody has committed to these.

### Thin out the sub-10% thresholds

Below 10% every integer fires, so the last stretch of battery life produces nine notifications. Fewer
checkpoints, say 8 / 5 / 2, would be quieter. Counter-argument: at that level the user genuinely does
want nagging. Trivial to change — it is one array in `config.sh`.

### Both devices in the menu bar

One SwiftBar line showing mouse and keyboard together, or the lower of the two. Needs multi-device
monitoring first, and a decision about menu bar width.

### Notification actions

A "Remind me later" or "Snooze" button on the alert. `terminal-notifier` supports actions; whether
they survive being fired from launchd is unconfirmed.

### Live-hardware smoke test

A test that reads the real registry and asserts something plausible comes back, catching an IOKit
schema change that the static mock cannot. Would have to skip cleanly when no device is present.

---

## Blocked

Nothing.

---

## Declined

Nothing yet. Record rejected ideas here with the reason, so they are not re-proposed.
