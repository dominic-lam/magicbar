# magicbar — Architecture & Technical Details

Open work is in [`TODO.md`](./TODO.md); feature status in [`FEATURES.md`](./FEATURES.md);
history in [`PROGRESS.md`](./PROGRESS.md).

*Rewritten 2026-09-08 for the Swift app. The bash architecture this replaced is at the
`bash-final` tag.*

---

## Reading a battery

### The route that does not work, and why it is documented

`IOPSCopyPowerSourcesInfo` plus `IOPSCopyPowerSourcesList` is the public, documented power
source API, and it was tried first because a documented interface beats a registry walk.

Measured on this machine 2026-09-08: it returns **zero** power sources.

Bluetooth accessories are a separate power-source type. `pmset -g accps` can list them, but it
reaches them through `IOPSCopyPowerSourcesByType(kIOPSAccessoryType)` — and neither that
function nor that constant appears anywhere in the public SDK. Using it would mean `dlsym` and
a hardcoded type string, which is strictly more fragile than the registry, not less.

This is written down so the next person does not spend the same hour rediscovering it.

### The route that works

`BatteryReader` matches `AppleDeviceManagementHIDEventService`, the class every Apple HID
peripheral with a cell publishes under, then reads each service's properties.

A device qualifies when it has `HasBattery == true` **and** an integer `BatteryPercent`. Both
checks matter: the first excludes peripherals that publish the service without a cell, the
second excludes one that has a cell but is not currently reporting, which is what a sleeping
mouse looks like.

Results are sorted lowest-first, so "the device that matters" is always the head of the list
and the menu bar and popover cannot disagree about ordering.

**Ownership.** `IOServiceMatching` returns +1 and `IOServiceGetMatchingServices` consumes it,
so the matching dictionary must not be released — doing so is a double release. The iterator,
each `io_object_t` from `IOIteratorNext`, and each properties dictionary all need releasing;
the middle one is the one that gets forgotten.

### What the registry gives us for free

| Field | Used for |
|---|---|
| `Product` | display name, so no device name is hardcoded anywhere |
| `BatteryPercent` | the level |
| `HasBattery` | qualification |
| `DeviceAddress` | stable identity for persisted state — the only field that survives a transport change |
| `SerialNumber` | not identity: it differs over Bluetooth and USB |
| `BatteryStatusFlags` | 0 discharging, 3 charging (measured; layout undocumented) |
| `ProductID` | icon selection only |

**`Product` is user-editable and its punctuation is inconsistent.** On this machine the
keyboard uses an ASCII apostrophe and the mouse uses U+2019. Never split it on punctuation and
never use it for identity.

Identity is `SerialNumber`, the Bluetooth address, which is stable across reconnects and does
not collide between two devices of the same model the way a shared product ID would.

---

## The two menu bar styles

The default draws the glyph, a level bar and the percentage in the urgency colour directly on
the bar. "High contrast alerts" instead draws dark content on an opaque capsule and adds a
warning triangle at the urgent level.

The option exists because the default has two measured weaknesses that do not affect everyone:
its warn orange is **2.20:1** against a light menu bar where text wants 4.5:1, and orange and
red simulate to nearly the same olive-yellow under deuteranopia, so hue alone cannot separate
the two levels. The capsule carries its own background and adds a second, non-colour channel.

Named for the effect rather than for who needs it. A setting named after an impairment makes
the reader identify themselves to find it, and it would also be inaccurate: the contrast half
has nothing to do with colour vision.

## The notification rule

Per device, the store keeps the **lowest level seen since the last real recharge**.

An alert fires when a reading is below the nag threshold **and** below that mark. The mark then
moves down. A rise only resets the mark when it clears `rechargeDelta`, currently 5 points.

### The bands

`decide(percent:lastAnnounced:)` is pure, and deliberately separate from delivery. Two rules,
each pointed at either level:

| Rule | Default | Step |
|---|---|---|
| coarse | below the warn level | 5 points |
| fine | below the urgent level | 1 point |

**Where both apply the finer wins outright.** Pointing them at the same level is therefore
redundant rather than contradictory, and no configuration produces two alerts for one drop.
Turning the fine rule off is the standing "stop nagging me" setting; a master switch above both
silences everything.

### Reminders tied to a moment

Two notifications answer *when* rather than *what*, and neither goes through the rule above —
the level has not changed, the opportunity has. Both fire only if something is below the warn
level, and neither consumes nor is suppressed by the ordinary cadence.

- **On sleep.** `NSWorkspace.willSleepNotification`. The message is read on wake, at a desk,
  where a cable is free.
- **Daily, at a chosen hour.** Checked on the ordinary poll against the wall clock rather than
  by its own timer: a timer that must survive sleep, clock changes and time zones is a whole
  mechanism, where a comparison is correct by construction. Fires once per day.

This is the half four reviewers said was missing. The app knew the level and not the moment,
so every warning arrived mid-task, when charging costs the user the device.

### Why not the obvious thing

The bash implementation stored the *threshold* it last fired at and treated any reading above
it as a recharge. A one-point Bluetooth wobble therefore looked like a charge, re-armed the
entire ladder, and produced an alert per tick all the way back down — six notifications for a
battery sitting still at 7%, reproduced before the rewrite.

Storing the lowest *reading* instead makes that impossible: noise cannot re-arm anything, and
"notify on every percent lost" falls out directly rather than needing a ladder of thresholds.

Verified 2026-09-08 by walking a synthetic sequence:

| Reading | Alert | Why |
|---|---|---|
| 25, 12 | no | above the nag threshold |
| 9 | **yes** | first below it |
| 9 again | no | already announced |
| 8 | **yes** | new low |
| 9 | no | one-point blip, not a recharge |
| 8 | no | already announced |
| 30 | no | real recharge, re-arms |
| 9 | **yes** | armed again |

---

## Drawing the menu bar

Two states, drawn differently on purpose.

**Idle** is the `magicmouse` symbol, `isTemplate = true`, so the system inverts it for light and
dark menu bars. No reading, no colour.

**Alert** composes the device's symbol, a rounded level bar and the percentage into one image,
`isTemplate = false`, so the colour survives.

That flag is load-bearing in both directions. A template image is *meant* to be repainted to the
system tint, which is right for a monochrome glyph and destroys a coloured one. Symbols come
back from `NSImage(systemSymbolName:)` already marked as templates, so a composed image can
inherit `true` and silently grey out. It is set explicitly on both paths.

### Why AppKit and not SwiftUI

`MenuBarExtra` repaints a `Text` label to the flat system tint whatever `.foregroundColor`
says, and `ImageRenderer` produces a black glyph mask rather than coloured text. Both were
measured in Range. AppKit's own drawing path has always honoured an explicit `NSColor`.

### Why not `lockFocus`

Apple deprecates it as "incompatible with resolution-independent drawing": it snapshots at the
main screen's scale at the moment of the call. `NSImage(size:flipped:drawingHandler:)`
re-invokes the handler per backing scale instead. The handler may run later and repeatedly, so
it captures values rather than references.

### The level bar

The fill is floored at 1pt, two physical pixels on a 2x display, and its corner radius shrinks
with it: `min(2, fillWidth / 2)`.

Both details exist because of a bug worth remembering. A fixed 2pt radius on a sub-2pt fill
consumes the entire shape, so a low reading drew as an empty track. The first attempt at a fix
floored the fill at the bar's own thickness instead, which made **every level below 36% render
identically** — and since the bar only appears below the alert threshold, that was every level
it was ever visible at. The bar was wrong every single time a user saw it.

Shrinking the radius fixes the cause; the 1pt floor only guarantees a non-zero path.

### Sizes

Content is drawn 18pt tall against a status bar thickness of 22pt, measured and logged at
launch. Drawing at full thickness looks clipped; the bar pads a correctly sized image and
scales an oversized one, which is the usual cause of a soft-looking menu bar item.

The percentage uses `monospacedDigitSystemFont`. With proportional digits the item's width
changes with every reading and the whole right-hand side of the menu bar twitches.

### Symbols

`magicmouse` and `keyboard` were confirmed present on this machine. `trackpad` and
`magicmouse.radiowaves.left.and.right` **do not exist** — do not reach for them. Selection is by
product ID first, since names are user-editable, with a name check as fallback and a chain
ending at `questionmark.circle`. Which tier resolved is logged, because a silently degraded
icon is otherwise invisible from a terminal.

---

## Notifications

A real app bundle owns its own notifications, which is why `terminal-notifier` is gone.

**A Debug build cannot get authorization.** It carries `com.apple.security.get-task-allow`,
marking it debuggable, and macOS will not grant notification permission to a process that could
have code injected into it. Release with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` produces a
bundle with only the sandbox entitlement.

**A refusal is close to permanent.** It is recorded per bundle ID in
`~/Library/Preferences/com.apple.ncprefs.plist`, `requestAuthorization` never re-prompts, and
notifications live outside TCC so there is no reset command. The bundle ID must be right the
first time. The current status is logged at every launch because that is the only way to see it.

**The popover makes the app frontmost**, and macOS suppresses notifications from a frontmost
app. `Notifier` implements `UNUserNotificationCenterDelegate` returning `[.banner, .list,
.sound]`, which keeps an alert visible in exactly the window where the user is looking at
battery levels. `.alert` is deprecated in favour of `.banner` and `.list`.

`UNUserNotificationCenter.current()` raises and terminates the process when there is no bundle
identifier, so every entry point is guarded.

---

## Reacting to a plugged-in cable

**IOKit broadcasts, and the app listens.** Two public notifications carry what this app needs:

- `IOServiceAddMatchingNotification` with `kIOMatchedNotification` — a matching service
  appeared, meaning a peripheral woke or reconnected.
- `IOServiceAddInterestNotification` with `kIOGeneralInterest` — an existing service changed.
  The device entries advertise this themselves; an `IOGeneralInterest` key sits in their
  registry properties.

Plugging a cable in changes the device's properties, so the interest notification is what puts
charging in the menu bar at once rather than at the next poll. Bursts are coalesced, because
one physical event raises several notifications.

`IOPSNotificationCreateRunLoopSource`, the public power-source notification, is **not** usable
here for the same reason the power-source API is not: it reports the sources
`IOPSCopyPowerSourcesList` returns, and that list is empty on this machine.

The 5-second timer stays as a safety net. An undrained matching iterator never fires again, and
a property change that does not raise general interest would otherwise be invisible.

## Launch at login

`SMAppService.mainApp`, registered once on first launch and revocable from the popover or from
System Settings.

Registration binds to the app's **current path**, so the app has to live somewhere permanent.
Registering from a build directory leaves a dangling login item as soon as that directory is
cleaned. Status is logged at launch as the only terminal-visible signal.

---

## Testing

There is no test target. The app is verified by driving it from a terminal, which is the same
constraint that shapes the diagnostics: anything unobservable logs itself, anything that needs
driving has a launch argument.

`--simulate` injects readings, because battery levels cannot be dialled to order and waiting for
a device to reach 19% is not a strategy. `--dump-devices` prints discovery. `--dump-label`
prints the rendered image's size, template flag and a colour sampling, which is how the alert
image was confirmed to be genuinely coloured rather than a grey blob.

**Known limitation of the label sampling:** `tiffRepresentation` rasterizes at 1x, so it proves
colour and template state but not the Retina behaviour, which only happens when the image is
actually displayed.

---

## Known gaps

- **A device's identity and name both change with its transport.** Confirmed on a Magic Mouse
  put on a cable: over Bluetooth it reports `SerialNumber` "BC:89:A7:E3:B9:51" and the name
  "Dominic's Magic Mouse"; over USB the same device reports "J84436504T127CGB4" and "Magic
  Mouse". `DeviceAddress` is the one field that survives both, which is why state is keyed on
  it. Keying on the serial split one device into two and lost its alert state on plug-in.
- **No sleep or wake handling.** The registry watcher covers reconnection, which is the usual
  post-wake event, but nothing observes wake directly.
- **A vanished device disappears from the popover** rather than showing a last-known value with
  a timestamp.
