# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# magicbar — Claude Code Session Reference

## What This Project Is

**magicbar** is a macOS 14+ menu bar app that watches the battery in every Apple peripheral
that reports one, and escalates as a device runs down: a plain glyph while all is well, the
device's own icon and a level bar below one threshold, a notification per lost percent below a
second.

Swift and SwiftUI, one Xcode target, no packages, no background job, no third-party anything.
Rewritten from a bash implementation on 2026-09-08; that version is preserved at the
`bash-final` tag.

**GitHub:** https://github.com/dominic-lam/magicbar

---

## Documentation Structure

- **docs/claude/ARCHITECTURE.md** — how the registry read, the state machine and the menu bar
  drawing work, plus what was measured to get there
- **docs/claude/ROADMAP.md** — sequencing only: phases, now / next / later
- **docs/claude/FEATURES.md** — every feature by status. New ideas go here, not TODO.
- **docs/claude/TODO.md** — open work only: NEXT SESSION, Active, Watch list
- **docs/claude/PROGRESS.md** — session log and navigation index
- **docs/reference/PROJECT_BRIEF.md** — fast snapshot: flow, key files, gotchas
- **README.md** — user-facing install and troubleshooting
- **CHANGELOG.md** — user-facing version history
- **MIGRATION.md** — retiring the predecessor ad-hoc scripts. **Gitignored**, this machine only.

**Read first** in a new session: `TODO.md`, then `docs/reference/PROJECT_BRIEF.md`.

---

## How We Work Together

### Session Start Protocol
1. Read **docs/claude/TODO.md**
2. Read **docs/reference/PROJECT_BRIEF.md**
3. Read **docs/claude/ARCHITECTURE.md** if touching the reader, the renderer or the state machine
4. Ask clarifying questions if scope is unclear

### Session End Protocol
1. Update **TODO.md** — tick boxes, add discoveries, prune what closed. A new feature *idea*
   goes to **FEATURES.md** as an Idea, not to TODO.
2. Append to **PROGRESS.md** Session Log, three-line format:
   ```
   ## YYYY-MM-DD (Session N — Title)
   **Completed:** one sentence on what shipped
   **In progress:** what's unfinished, or "Nothing"
   **Next session should:** the single most important pickup
   ```
   Update **CHANGELOG.md** if anything user-facing changed.
3. Update **ARCHITECTURE.md** if the tech changed
4. Update **FEATURES.md** on a status change; **ROADMAP.md** only if sequencing changed
5. **Write every doc as of the moment after the wrap's own commit.** The wrap commits the docs
   it just wrote, so "commit X" is never a NEXT SESSION item and "uncommitted" is never written
   about work the same wrap is about to commit. A git-state claim carries a hash or a date,
   never a bare "not pushed". Before staging, grep the edited docs for
   `uncommitted|not committed|not pushed` and fix every hit the commit is about to falsify.

### Code Quality Standards
- **No over-engineering.** This is a few hundred lines of Swift and should stay that way.
- **Simple beats clever.** Three similar lines beat a premature abstraction.
- **Delete, don't comment out.** No `// removed` blocks or `_unused` renames.
- **Anything that cannot be observed must log itself**, and anything that needs driving must be
  reachable from a launch argument. The app is developed from a terminal with nobody watching
  the menu bar, so this is a hard constraint, not a preference.

### Git & Deployment
- Only commit when explicitly requested
- Never use destructive git commands unless explicitly requested
- Commit messages: concise, focused on "why" not "what"
- Add a `Co-Authored-By:` trailer naming **the model actually writing the commit**. Do not pin
  a model name in this rule — it goes stale every time the model changes.

### Mentorship & Learning
The user does not have formal software development experience. Act as a senior developer
mentor: teach at real teachable moments, explain the "why" behind a recommendation, present
trade-offs rather than one right answer, use examples from this project.

---

## Key Technical Context

### Build and run

```bash
# The flag is required, not optional — see "Notifications" below
xcodebuild -project magicbar.xcodeproj -scheme magicbar -configuration Release \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build

REL="$(xcodebuild -project magicbar.xcodeproj -scheme magicbar -configuration Release \
  -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')/magicbar.app"

pkill -f "MacOS/magicbar( |$)"
rm -rf /Applications/magicbar.app && cp -R "$REL" /Applications/magicbar.app
open /Applications/magicbar.app

log show --last 5m --predicate 'eventMessage CONTAINS "[magicbar]"'
```

Both shell forms above are corrections inherited from Range and both cost real debugging time:
`pkill -f "MacOS/magicbar$"` matches nothing once the app has launch arguments, because `$`
anchors against the whole command line; and globbing `DerivedData/magicbar-*` can resolve to
another checkout's build, so ask `xcodebuild` for `BUILT_PRODUCTS_DIR` instead.

**Never pass `-derivedDataPath` pointing inside this repo.** It lives under an iCloud-synced
`Documents` tree, and iCloud stamps Finder attributes on build output that make `codesign` fail
with "resource fork, Finder information, or similar detritus not allowed".

### Critical architecture points

**Devices are discovered, not configured.** `BatteryReader` enumerates every
`AppleDeviceManagementHIDEventService` with `HasBattery` and takes the display name from the
registry. There is no product ID list to maintain. Product IDs appear only to pick an icon.

**The public power-sources API does not work here.** `IOPSCopyPowerSourcesInfo` plus
`IOPSCopyPowerSourcesList` returns zero sources on this machine — measured. Bluetooth
accessories need `IOPSCopyPowerSourcesByType(kIOPSAccessoryType)`, and neither that function
nor that constant exists in the public SDK. Do not "improve" the registry read into it.

**Notification state is a low-water mark, not a threshold ladder.** The bash version stored the
threshold it last fired at and re-armed everything when a reading rose above it, so a
one-point Bluetooth wobble produced a cascade. Storing the lowest reading seen means a rise
cannot re-arm anything below `rechargeDelta`. Do not replace this with a level comparison.

**The alert rule is a pure function, `BatteryStore.decide`, and must stay one.** It was
entangled with notification authorization and `UserDefaults`, which made it untestable — a
scripted check reported the cadence broken when authorization had simply not resolved in a
short-lived probe. `--dump-cadence`, `--dump-retention` and the menu bar choice printed by
`--dump-devices` all exist for the same reason: a rule that only lives inside a drawing or
polling loop cannot be checked.

**A device's identity is its `DeviceAddress`, never its `SerialNumber` or name.** The same
physical mouse reports a different serial and a different name over Bluetooth and over USB, so
keying on either splits one device into two and loses its alert state on plug-in.

**A disconnected device vanishes from the registry entirely.** Absence is never 0%. The store
leaves a vanished device's marks untouched rather than treating it as a drain to zero.

**The menu bar label is drawn through AppKit, and the two states differ deliberately.** The
idle glyph is `isTemplate = true` so the system inverts it for light and dark bars; the alert
image is `isTemplate = false` so the colour survives. Symbols come back from
`NSImage(systemSymbolName:)` already marked as templates, so a composed image can inherit
`true` and silently lose every colour. Set it explicitly on both paths.

**Use `NSImage(size:flipped:drawingHandler:)`, not `lockFocus`.** Apple deprecates `lockFocus`
as incompatible with resolution-independent drawing: it snapshots at the main screen's scale at
call time. The handler form is re-invoked per backing scale. Range still uses `lockFocus` and
gets away with it only because both its displays are the same scale.

**Notifications require a non-debuggable app.** A Debug build carries
`com.apple.security.get-task-allow` and macOS refuses it notification authorization. Build
Release with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. A refusal is close to permanent: it is
recorded per bundle ID in `ncprefs`, `requestAuthorization` never re-prompts, and there is no
`tccutil` reset for notifications.

**The popover makes the app frontmost, and macOS suppresses notifications from a frontmost
app.** `Notifier` implements `UNUserNotificationCenterDelegate` to return `[.banner, .list,
.sound]`, which is what keeps an alert visible while the user has the popover open.

### File overview

```
MagicbarApp.swift      @main, the MenuBarExtra scene, diagnostic launch arguments
BatteryReader.swift    IORegistry enumeration + the --simulate injection point
Device.swift           model, identity, icon mapping, display name
BatteryStore.swift     poll timer, thresholds, low-water marks, colour
DrainHistory.swift     sampled readings and the "about 3 days left" fit
Notifier.swift         UNUserNotificationCenter, guarded against a missing bundle
MenuBarRenderer.swift  NSImage composition for both label states
LoginItem.swift        SMAppService registration
RangeSlider.swift      the two-handle level slider
RegistryWatcher.swift  IOKit change notifications, so a cable lands at once
PopoverView.swift      device rows, threshold steppers, login toggle, Quit
```

---

## Current State (2026-09-09)

Built, installed at `/Applications/magicbar.app`, running, registered as a login item, and
allowed to post notifications. Reviewed by four reviewers on 2026-09-08; fifteen of their 37
findings are closed, and the rest are triaged in
`docs/claude/debriefs/2026-09-08-design-review.md`.

**Distribution is decided.** Open source only — no App Store, no paid Apple Developer account.
Two GitHub Actions workflows (build-on-push, ad-hoc-signed release on a `v*` tag) are written
and verified locally, but have never run on GitHub: this session is the first push of
`.github/`, and no tag has been pushed yet.

**The sleep reminder was removed.** It could not be delivered as the Mac sleeps — the display
and the audio device are both already off by the time the app is told, measured twice — and
delivering it at wake instead lands on the one moment a Magic Mouse cannot be charged. The
daily reminder at a chosen hour is now the only reminder tied to a moment, and it is
**unverified** — wired, never fired.

**Unverified:** the drain estimate ("about three days left"), shipped 2026-09-09 and checked
only against synthetic data — see `docs/claude/ARCHITECTURE.md`.
