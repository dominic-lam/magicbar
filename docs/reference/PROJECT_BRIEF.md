# magicbar — Project Brief

Fast snapshot for picking the project back up. Everything here was verified on 2026-09-08
unless marked otherwise.

## In one line

A macOS menu bar app that watches every Apple peripheral reporting a battery and escalates from
a silent glyph to a coloured level bar to a notification per lost percent.

## Current status

**v1.0.0, built and running.** Installed at `/Applications/magicbar.app`, registered as a login
item. Swift and SwiftUI, one target, no packages, no background job.

**One thing does not work:** notification authorization is denied and must be granted by hand in
System Settings › Notifications › magicbar. The first launch was a debuggable Debug build,
macOS recorded a refusal against the bundle ID, and it will not re-prompt.

## Runtime flow

```
IORegistry (AppleDeviceManagementHIDEventService, HasBattery)
      → BatteryReader → [Device]  (lowest first)
          → BatteryStore  60s timer · thresholds · low-water marks
              → MenuBarRenderer  idle glyph, or device + bar + percent
              → Notifier         one alert per percent lost below the nag line
```

## Key files

| File | Why you would open it |
|---|---|
| `magicbar/BatteryReader.swift` | the only place that reads hardware |
| `magicbar/BatteryStore.swift` | the notification rule and the poll timer |
| `magicbar/MenuBarRenderer.swift` | both label states; the part with no prior art |
| `magicbar/Notifier.swift` | authorization and delivery, with the bundle guard |
| `docs/claude/ARCHITECTURE.md` | why each of the above is shaped that way |

## Build and run

```bash
xcodebuild -project magicbar.xcodeproj -scheme magicbar -configuration Release \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
```

The flag is required. Without it the build is debuggable and can never get notification
permission. Install to `/Applications`, never run from the build directory, and never point
`-derivedDataPath` inside this repo — it is in an iCloud tree and `codesign` will fail.

## Diagnostics

```bash
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-devices
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-label
open /Applications/magicbar.app --args --simulate "617:9,620:62"
log show --last 5m --predicate 'eventMessage CONTAINS "[magicbar]"'
```

## Gotchas

- **The public power-sources API returns zero sources here.** Accessories need a private call.
  The registry read is not a shortcut, it is the only public route. Do not "improve" it.
- **Absence is not zero.** A sleeping peripheral vanishes from the registry entirely.
- **`Product` is user-editable** and its apostrophe differs between devices. Never use it for
  identity or split it on punctuation.
- **`isTemplate` is load-bearing in both directions** and symbols arrive already marked true.
- **A Debug build can never notify.** See above.
- **A notification refusal is close to permanent** — per bundle ID, no re-prompt, no reset.
- **Do Not Disturb suppresses alerts** regardless of permission.

## Verified hardware

| Device | ProductID | Symbol |
|---|---|---|
| Magic Mouse | 617 | `magicmouse` |
| Magic Keyboard | 620 | `keyboard` |

Both discovered automatically; the IDs are only used to pick an icon.

## History

The bash implementation this replaced is at the `bash-final` tag: SwiftBar plugin, launchd
notifier, `terminal-notifier`, `ioreg`. It monitored one device and flooded the user with
alerts when a reading wobbled.
