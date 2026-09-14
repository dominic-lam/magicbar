# Developing magicbar

The user-facing guide is the [README](../README.md). This page is for building, debugging and
understanding the app.

## Build it

Requires macOS 14 or later and Xcode.

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

No Homebrew packages, no SwiftBar, no `terminal-notifier`, no launchd job, no third-party
dependencies of any kind.

## How it works

```
IORegistry (AppleDeviceManagementHIDEventService)
        │  every service with HasBattery + BatteryPercent
        ▼
  BatteryReader ──▶ [Device]
        │
   BatteryStore     5s timer + IOKit events, thresholds, low-water marks
     │       │
     ▼       ▼
 MenuBarRenderer   Notifier
  (NSImage)        (UNUserNotificationCenter)
```

Devices are **discovered**, not configured. Anything that publishes a battery level is picked
up automatically and named from the registry, so there is no list of product IDs to maintain
and adding a Magic Trackpad would require no code.

Settings persist in `UserDefaults`. There is no config file.

The only network access is `UpdateChecker`: at launch and every 24 hours it asks
`api.github.com` for the latest non-prerelease tag and compares it with
`CFBundleShortVersionString`. It never downloads anything; the footer link opens the fixed
Releases page. GitHub answers 404 while every release is a prerelease, which counts as "nothing
newer". Local builds take their version from `MARKETING_VERSION` in the project, so keep it in
step with the next tag — a stale one makes a local build announce an update to itself.

The full design, and what was measured to arrive at it, is in
[docs/claude/ARCHITECTURE.md](claude/ARCHITECTURE.md).

## Troubleshooting from a terminal

Anything worth knowing logs itself under `[magicbar]`:

```
log show --last 10m --predicate 'eventMessage CONTAINS "[magicbar]"'
```

**No notifications** — the app logs its authorization status at every launch, which is the only
way to see that state.

**Menu bar item missing** — `pgrep -f "MacOS/magicbar( |$)"`. If it is running, the item exists
but the menu bar is full; macOS hides overflow silently.

**Wrong or missing device** — `--dump-devices` (below) prints what the app can see.

**Not starting at login** — the app logs its login item status at launch.

## Diagnostics

Pass these to the binary directly, e.g.
`/Applications/magicbar.app/Contents/MacOS/magicbar --dump-devices`.

**They share the real app's saved data.** Each builds a real `BatteryStore`, so a run can write
into the settings and drain history the installed app uses. `--dump-retention` is the proven
case: on 2026-09-12 it left simulated devices in the drain history and deleted a real one's.
Until that is fixed, avoid it — and anything with `--simulate` — on a machine whose history
you care about.

| Argument | Effect |
|---|---|
| `--dump-devices` | print every discovered device, and the menu bar choice, then exit |
| `--dump-label` | print the rendered menu bar image's size, template flag and colour sampling |
| `--dump-cadence "12,9,8,9,7"` | walk a sequence of readings through the alert rule and print each decision |
| `--dump-retention` | show which devices stay listed after they disconnect |
| `--dump-estimate` | print each device's drain segments and its "days left" estimate |
| `--check-estimate` | run the estimate rule on synthetic drains, charges and quiet days — touches no saved data |
| `--test-notification` | once permission resolves, send the same test notification as the popover button |
| `--check-updates` | print the version comparisons, ask GitHub for the latest release, and exit — makes one real request |
| `--simulate-update 1.3.0` | show the "Version … available" footer without touching the network |
| `--simulate "617:9,620:62"` | use injected readings instead of real hardware |

`--simulate` takes product IDs or names. It is how every menu bar state and notification rule
gets tested without waiting for a real battery to drain.
