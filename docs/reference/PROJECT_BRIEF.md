# magicbar — Project Brief

Fast snapshot for picking the project back up. Everything here was verified on 2026-09-08
unless marked otherwise.

## In one line

A macOS menu bar app that watches every Apple peripheral reporting a battery and escalates from
a silent glyph to a coloured level bar to a notification per lost percent.

## Current status

**v1.2.0, released 2026-09-13, built and running.** Installed at `/Applications/magicbar.app`, registered
as a login item, allowed to notify. Swift and SwiftUI, one target, no packages, no background
job. One network call since 2026-09-12: an optional daily GitHub update check that never
installs anything.

Reviewed 2026-09-08 by four reviewers; fifteen of their 37 findings are closed and the rest are
triaged in `docs/claude/debriefs/2026-09-08-design-review.md`.

**The sleep reminder was removed 2026-09-09** — it could not be delivered while the Mac is
sleeping, measured twice (see `ARCHITECTURE.md`). The daily reminder now carries a drain
estimate ("about three days left") instead. **The daily reminder fired for the first time on
2026-09-17 at 23:00**, carrying "about 33 hours left", and the user confirmed seeing it.
The estimate was reworked 2026-09-13 — one rate across every run between charges, quiet time
counted, a 24-hour floor.

**Three estimates since 2026-09-18, the newer two unreleased.** The clock estimate was judged on
the first complete real run and found smooth but 14 hours off on average, because daily use
varied sixfold; no alternative did better. So a second line now shows hours of use left, and a
device on the cable shows time to full, learned per level from recorded charges. The first
charge (4% → 100%, 3 h 31 min) read up to 77 minutes short until the taper had been seen; its
whole curve is now in the app's record, and the second charge is the test.

**Distribution works.** Open source only, no paid developer account. GitHub Actions build the
app on every push and publish an ad-hoc-signed zip on a `v*` tag. `v1.2.0` was published
2026-09-13 and verified by download: checksum, version, signature, no `get-task-allow`.

**The diagnostics work on a copy of the saved data** (fixed 2026-09-25). Any `--` argument reads
the real history and writes only to `com.dominic-lam.magicbar.diagnostics`.

## Runtime flow

```
IORegistry (AppleDeviceManagementHIDEventService, HasBattery)
      → BatteryReader → [Device]  (lowest first)
          → BatteryStore  5s poll + IOKit change events · levels · low-water marks
              → MenuBarRenderer  idle glyph, or the alert in one of two styles
              → Notifier         coarse and fine rules, plus a daily reminder
              → DrainHistory     drain segments and charge runs behind all three estimates
UpdateChecker  GitHub latest release, at launch + daily + "Check now" → footer link
```

## Key files

| File | Why you would open it |
|---|---|
| `magicbar/BatteryReader.swift` | the only place that reads hardware |
| `magicbar/BatteryStore.swift` | the notification rule and the poll timer |
| `magicbar/MenuBarRenderer.swift` | both label states and both alert styles |
| `magicbar/RangeSlider.swift` | the two-handle level slider |
| `magicbar/Notifier.swift` | authorization and delivery, with the bundle guard |
| `magicbar/DrainHistory.swift` | drain segments, charge runs, and the clock, use and time-to-full estimates |
| `magicbar/UpdateChecker.swift` | the update check — the app's only network access |
| `docs/claude/ARCHITECTURE.md` | why each of the above is shaped that way |
| `docs/DEVELOPMENT.md` | build, terminal troubleshooting, every launch argument |

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
/Applications/magicbar.app/Contents/MacOS/magicbar --dump-estimate     # + the stored drain series and its fit
/Applications/magicbar.app/Contents/MacOS/magicbar --check-estimate    # synthetic cases, no saved data
/Applications/magicbar.app/Contents/MacOS/magicbar --check-updates     # one real GitHub request
open /Applications/magicbar.app --args --simulate-update 1.3.0         # footer notice, no request
open /Applications/magicbar.app --args --simulate "617:9,620:62"       # "+" suffix = charging
log show --last 5m --predicate 'eventMessage CONTAINS "[magicbar]"'
```

The `--dump-*` rules exist because a rule that only lives inside a drawing or polling loop, or
inside days of accumulated history, cannot be checked. Two of the bugs found in review were of
exactly the drawing-loop shape; the drain estimate is the history-shaped case.

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
