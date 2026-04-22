# magicbar

> Because macOS won't tell you your Magic Mouse is dying until it already has.

## What it does

magicbar reads Apple peripheral battery levels from the macOS I/O Kit registry and surfaces them two ways: a **SwiftBar menu bar icon** that shows the current percentage (color-coded as it drains), and a **launchd-scheduled notifier** that fires a macOS notification each time the battery crosses a configured threshold (20%, 15%, 10%, then every integer below). Both consumers share a single battery-read library, so there's exactly one place to fix if Apple changes the IOKit schema.

## Install

```
git clone git@github.com:dominic-lam/magicbar.git
cd magicbar
./install.sh
```

Open SwiftBar and run **Refresh All** to see the menu bar icon immediately. The launchd notifier begins ticking in the background on a 15-minute interval.

## Uninstall

```
./uninstall.sh
```

Removes the launchd agent and the SwiftBar plugin. Prompts before deleting `~/.magicbar/` (state + logs). Leaves `terminal-notifier` and SwiftBar installed in case you use them for other tools; prints the commands to remove them manually.

## How it works

```
                    ioreg -r -k BatteryPercent -a
                                │
                                ▼
                ┌──────────────────────────────────┐
                │  lib/read_battery.sh             │
                │    parse_battery_percent <pid>   │  ← testable
                │    read_battery_percent  <pid>   │  ← consumers call
                └──────────────────────────────────┘
                         ▲                    ▲
                         │                    │
          ┌──────────────┴──────┐     ┌───────┴────────────┐
          │ bin/battery_alert.sh│     │ swiftbar/magicbar  │
          │   launchd, 15m      │     │   SwiftBar, 5m     │
          │   threshold notify  │     │   menu bar text    │
          │   state: ~/.magicbar│     │   stateless        │
          └─────────────────────┘     └────────────────────┘
```

Two consumers, one shared library. They don't know about each other — uninstalling one leaves the other working. Battery data comes from IOKit via the `ioreg` CLI; parsing is done in Python with `plistlib` so the format is robust against the various quirks of ioreg's XML output.

Why these particular tools:
- **`ioreg`** is the only supported way to read peripheral BatteryPercent without writing a full IOKit Swift/Obj-C client.
- **`launchd`** (not `cron`) because macOS has deprecated cron and cron-fired notifications don't reliably reach Notification Center.
- **`terminal-notifier`** (not `osascript`) because osascript notifications fired from launchd have no owning app bundle and are silently dropped on recent macOS.
- **SwiftBar** because it turns a stdout protocol into a menu bar icon with zero boilerplate.

## Configuration

All user-editable constants live in [`config.sh`](config.sh):

| Knob | Purpose |
|---|---|
| `MAGIC_MOUSE_PRODUCT_ID` / `MAGIC_KEYBOARD_PRODUCT_ID` | USB/Bluetooth ProductIDs. 617 for Magic Mouse 2/3 is verified; others are placeholders — confirm with `ioreg -r -k BatteryPercent -a` for your hardware. |
| `MENU_BAR_DEVICE_PRODUCT_ID` | Which ProductID the menu bar reads from (defaults to Magic Mouse). |
| `MENU_BAR_DEVICE_ICON` | Emoji shown in the menu bar before the percentage. |
| `NOTIFICATION_THRESHOLDS` | Descending list of thresholds that trigger notifications. |
| `STATE_FILE` | Where the notifier remembers the last threshold it alerted on. |
| `SWIFTBAR_PLUGINS_DIR` | SwiftBar's plugins folder. Defaults to `~/SwiftBar`; override by exporting this before `./install.sh`. |
| `LAUNCHD_LABEL` | launchd agent label. Change if you want multiple magicbar installs to coexist. |

After editing `config.sh`, re-run `./install.sh` to re-render the plist and SwiftBar plugin.

## Requirements

- macOS (Apple Silicon or Intel)
- Homebrew — installed from [brew.sh](https://brew.sh)
- `python3` — ships with the Xcode Command Line Tools (`xcode-select --install`)
- `terminal-notifier` — installed for you by `install.sh`
- SwiftBar — installed for you by `install.sh`

## Troubleshooting

**Notifications not firing**
- Check the launchd log: `tail -f ~/.magicbar/launchd.log`
- Confirm the agent is loaded: `launchctl list | grep magicbar`
- Verify notification permission: *System Settings → Notifications → terminal-notifier* should show **Allow Notifications** on, with sound enabled.
- Force-run the notifier manually: `bash bin/battery_alert.sh`

**Menu bar icon not appearing**
- Click the SwiftBar icon → **Refresh All**.
- Confirm the plugin was copied: `ls -l "$HOME/SwiftBar/magicbar.5m.sh"` (should be `-rwxr-xr-x`).
- SwiftBar menu → **Plugins…** — look for `magicbar.5m.sh` and check its "Last error" row.
- Make sure SwiftBar's plugins folder matches `SWIFTBAR_PLUGINS_DIR` in `config.sh` (*SwiftBar → Preferences → General → Plugins Folder*).

**Wrong device detected / shows "🖱️ —"**
- Your peripheral's ProductID probably differs from 617. Run `ioreg -r -k BatteryPercent -a` and look for your device's `"ProductID"` value, then update `config.sh` and re-run `./install.sh`.

## License

[MIT](LICENSE) — Dominic Lam, 2026.
