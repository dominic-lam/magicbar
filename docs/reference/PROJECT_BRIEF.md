# magicbar — Project Brief

Fast snapshot for picking the project back up. Everything here was verified on 2026-09-08
unless marked otherwise.

## In one line

A macOS menu bar app that watches every Apple peripheral reporting a battery and escalates from
a silent glyph to a coloured level bar to a notification per lost percent.

## Current status

**v1.1.0, built and running.** Installed at `/Applications/magicbar.app`, registered as a login
item, allowed to notify. Swift and SwiftUI, one target, no packages, no background job.

Reviewed 2026-09-08 by four reviewers; fifteen of their 37 findings are closed and the rest are
triaged in `docs/claude/debriefs/2026-09-08-design-review.md`.

**Unverified:** the sleep and daily reminders, added 2026-09-09, have never fired.

**No release exists** — no signed build, no notarisation, no cask. Installing means building
from source, which both user reviewers named as the first wall they hit.

## Runtime flow

```
IORegistry (AppleDeviceManagementHIDEventService, HasBattery)
      → BatteryReader → [Device]  (lowest first)
          → BatteryStore  5s poll + IOKit change events · levels · low-water marks
              → MenuBarRenderer  idle glyph, or the alert in one of two styles
              → Notifier         coarse and fine rules, plus sleep and daily reminders
```

## Key files

| File | Why you would open it |
|---|---|
| `magicbar/BatteryReader.swift` | the only place that reads hardware |
| `magicbar/BatteryStore.swift` | the notification rule and the poll timer |
| `magicbar/MenuBarRenderer.swift` | both label states and both alert styles |
| `magicbar/RangeSlider.swift` | the two-handle level slider |
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
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-devices      # + which device the menu bar picks
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-label        # + writes both tiles to /tmp
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-cadence "19,14,9,8"
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-retention
open /Applications/magicbar.app --args --simulate "617:9,620:62"       # "+" suffix = charging
log show --last 5m --predicate 'eventMessage CONTAINS "[magicbar]"'
```

The three `--dump-*` rules exist because a rule that only lives inside a drawing or polling loop
cannot be checked. Two of the bugs found in review were of exactly that shape.

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
