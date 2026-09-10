# magicbar

> Because macOS won't tell you your Magic Mouse is dying until it already has.

A macOS menu bar app that watches the battery in every Apple peripheral you own and gets
progressively louder as one runs down.

## What it does

**Everything healthy** — one small mouse glyph in the menu bar. It carries no reading and no
colour. Its only job is to tell you the app is alive. Click it to see every device's level.

**A device drops below 20%** — the menu bar item becomes *that device's* icon, a level bar and
its percentage, in orange. Below 10% it turns red. If both devices are low, the lower one is
shown and the other stays one click away.

**A device drops below 10%** — every further percent lost produces a notification. That is
deliberate nagging: at that point you want to be bothered.

Both thresholds are adjustable from the popover.

## Install

### Download it

Grab `magicbar.zip` from [Releases](https://github.com/dominic-lam/magicbar/releases), unzip,
drag **magicbar.app** to **Applications**, and open it.

macOS will refuse the first time. Go to **System Settings › Privacy & Security**, scroll to
the bottom, and click **Open Anyway**.

That step is unavoidable and it is not a bug. Getting rid of it means notarising the app,
notarising needs a paid Apple Developer account, and this is a free side project with no
income to pay for one. The app is signed — just not by anyone Apple has been paid to
recognise.

### Or build it

```
git clone git@github.com:dominic-lam/magicbar.git
cd magicbar
xcodebuild -project magicbar.xcodeproj -scheme magicbar -configuration Release \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
cp -R "$(xcodebuild -project magicbar.xcodeproj -scheme magicbar -configuration Release \
  -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')/magicbar.app" /Applications/
open /Applications/magicbar.app
```

A locally built copy is never quarantined, so it skips the Privacy & Security step entirely.

`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` is not optional. Without it the build carries
`com.apple.security.get-task-allow`, which marks the app debuggable, and macOS will not grant
a debuggable app permission to post notifications.

Install to `/Applications` rather than running from the build directory. The app registers
itself as a login item on first launch, and that registration binds to wherever it was
launched from — a build directory gets cleaned and leaves a dangling entry.

### One manual step: notifications

Open **System Settings › Notifications › magicbar** and switch **Allow Notifications** on.
Set the alert style to **Alerts** rather than **Banners** if you want the warning to stay on
screen instead of vanishing after a few seconds. Neither can be set programmatically.

## Requirements

macOS 14 or later. Xcode only if you build it yourself. No Homebrew packages, no SwiftBar,
no `terminal-notifier`, no launchd job, no third-party dependencies of any kind.

## How it works

```
IORegistry (AppleDeviceManagementHIDEventService)
        │  every service with HasBattery + BatteryPercent
        ▼
  BatteryReader ──▶ [Device]
        │
   BatteryStore     60s timer, thresholds, low-water marks
     │       │
     ▼       ▼
 MenuBarRenderer   Notifier
  (NSImage)        (UNUserNotificationCenter)
```

Devices are **discovered**, not configured. Anything that publishes a battery level is picked
up automatically and named from the registry, so there is no list of product IDs to maintain
and adding a Magic Trackpad would require no code.

## Configuration

Both thresholds live in the popover and persist in `UserDefaults`. There is no config file.

## Troubleshooting

**No notifications** — check System Settings as above, then
`log show --last 10m --predicate 'eventMessage CONTAINS "[magicbar]"'`. The app logs its
authorization status at every launch, which is the only way to see that state.

**Menu bar item missing** — `pgrep -f "MacOS/magicbar"`. If it is running, the item exists but
your menu bar may be full; macOS hides overflow silently.

**Wrong or missing device** — `/Applications/magicbar.app/Contents/MacOS/magicbar --dump-devices`
prints what the app can see, as name, percent, product ID and serial.

**Not starting at login** — the app logs its login item status at launch. Untick and retick
"Open at login" in the popover, or check System Settings › General › Login Items.

## Diagnostics

The app is developed from a terminal, so anything worth knowing logs itself under `[magicbar]`.

| Argument | Effect |
|---|---|
| `--dump-devices` | print every discovered device and exit |
| `--dump-label` | print the rendered menu bar image's size, template flag and colour sampling |
| `--simulate "617:9,620:62"` | use injected readings instead of real hardware |

`--simulate` takes product IDs or names. It is how every menu bar state and notification rule
gets tested without waiting for a real battery to drain.

## License

[MIT](LICENSE) — Dominic Lam, 2026.
