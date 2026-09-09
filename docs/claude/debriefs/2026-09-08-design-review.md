# Design review — 2026-09-08

Four reviewers ran against the app as it stood at commit `41a6ec2`. Two were briefed as
designers with separate lanes; two were briefed as users and told to react rather than
critique. They did not see each other's output.

Screenshots they worked from are in `docs/review-shots/`.

---

## Triage

Status as of `505dd6c`. Fifteen of the 37 are now closed.

| # | Finding | Source | Status |
|---|---|---|---|
| 1 | A charging device wins the menu bar outright, hiding one that is dying | both designers | **fixed** `7cd0d2f` |
| 2 | Notification tile collapses every level ≤5.9% into one picture | menu bar designer | **fixed** `7cd0d2f` |
| 3 | A sleeping device silently cancels its own alarm | both designers | **fixed** `7cd0d2f` |
| 4 | Authorization re-checked every 5s (XPC round trip) | power user | **fixed** `7cd0d2f` |
| 5 | Device list republished unchanged every tick | power user | **fixed** `7cd0d2f` |
| 6 | Nothing interrupts until 9%; warning arrives hours late, not days | panel designer | **fixed** `7cd0d2f` |
| 7 | Up to ten alerts, no grouping | panel designer | **fixed** `7cd0d2f` — grouped per device |
| 8 | Unpairing a healthy device leaves it listed as "asleep" | user, in session | **fixed** `bd44754` |
| 9 | Simulated readings indistinguishable from real | found in session | **fixed** `7cd0d2f` |
| 10 | Orange on a light menu bar is 2.20:1 contrast | menu bar designer | **fixed** `192ef8d` — optional, `505dd6c` |
| 11 | Orange and red identical to red-green colourblind users | menu bar designer | **fixed** `192ef8d` — optional, `505dd6c` |
| 12 | No snooze, no acknowledgement, no way to silence in-app | all four | **partly** `192ef8d` — the 1% rule is now optional; no per-occasion snooze |
| 13 | Level bar is 36% of item width and spans 1–4.6pt of fill | menu bar designer | open |
| 14 | Menu bar state flips with no hysteresis at the threshold | menu bar designer | open |
| 15 | Charging takeover has no end state; a full device holds the bar | menu bar designer | open |
| 16 | Idle glyph carries zero information | menu bar designer | open |
| 17 | Composed alert image has no accessibility description | menu bar designer | **fixed** `192ef8d` |
| 18 | Second low device invisible until you click | menu bar designer | open |
| 19 | Two same-model devices are indistinguishable everywhere | panel designer | open |
| 20 | Developer mode gates the test button a normal user needs | panel designer | open |
| 21 | Dev preview never shows real alert wording (`isTest` replaces it) | panel designer | open |
| 22 | Sound picker has no preview and no "None" | user, panel designer | **fixed** `192ef8d` — preview on select, and a None option |
| 23 | Steppers: mismatched steps, moving bounds, silent clamping | panel designer | **fixed** `192ef8d` — replaced by the range slider |
| 24 | No visible "next alert at N%" state | panel designer | open |
| 25 | No version, no About, Quit styled as a caption | panel designer | open |
| 26 | No time-remaining estimate | both users | open — but the daily reminder now depends on it |
| 27 | No charge-complete alert | everyday user | open |
| 28 | No end-of-day warning, when the user can actually act | everyday user | **fixed** `192ef8d` — sleep and daily reminders |
| 29 | AirPods and non-HID accessories unsupported | power user | open |
| 30 | No shell hook / `--json` for scripting | power user | open |
| 31 | Per-device thresholds and mute | power user | open |
| 32 | Login item registers without asking | power user | open |
| 33 | Charging flag is `!= 0`; one stray bit disables the app | power user | open |
| 34 | Trackpad falls through to a generic battery icon | power user | open |
| 35 | App icon is a generic green battery at 16px | menu bar designer | open |
| 36 | No signed release; install is a wall of Terminal commands | both users | open |
| 37 | README architecture diagram still says "60s timer" | menu bar designer | open |

The three that changed the product rather than the polish: **1** (the app contradicting itself
on screen), **6** (warning too late), and **12** (no consent, which is what makes the nagging
intolerable rather than merely loud). All three are addressed, though **12** only as a standing
setting rather than a per-occasion snooze.

**28 was the finding that mattered most and was not on anyone's bug list.** Both users
independently said the app answers "what is the level?" and not "what should I do, and when?" —
a percentage arriving mid-task is a more detailed ambush. The sleep and daily reminders are the
answer to that, and they are the only work here that changed what the app is *for*.

---

## Reviewer 1 — designer, menu bar and glanceability

Ran the installed build's own `--dump-label` for real numbers rather than eyeballing:

```
label idle  size=(14.0, 20.0)  isTemplate=true
label alert size=(77.13, 18.0) isTemplate=false
```

### P1

**A charging device hides a dying one.** `menuBarDevice` returned the first charging device
before it ever checked the threshold. Keyboard on a cable at 90%, mouse discharging at 4%: the
bar showed a calm green keyboard and the mouse was invisible — while `evaluateNotification`
still fired a red "battery critical" banner for it. The app contradicted itself on screen, in
two places, at once. Fix: rank lowest discharging under threshold first, charging second.

**The alert colours were only validated against a black menu bar.**

| | vs black bar | vs white bar |
|---|---|---|
| orange `#FF9500` | 9.55:1 | **2.20:1** |
| red `#FF3A30` | 5.92:1 | **3.55:1** |

At 14pt medium that is normal-size text needing 4.5:1. Orange gets half. And `isTemplate =
false` means macOS does none of the inversion it does for the idle glyph — you took the
colour, you own the legibility. In Sonoma+ the bar is translucent over the wallpaper, so
"light mode" is not reliably white either. Fix: draw a filled capsule in the urgency colour
with the content knocked out in near-black. 9.55:1 on orange, 5.92:1 on red, independent of
the ground — and it gives the alert a different silhouette, not just a different hue.

**Orange and red are the same colour to ~8% of men.** Deuteranope simulation: orange →
`0.844, 0.875, 0.175`, red → `0.712, 0.769, 0.201`. Both olive-yellow, 13% apart. The entire
escalation is invisible. The only other channel is the bar fill, which is 4.6pt versus 1pt —
also invisible. Fix: low = outlined capsule, critical = solid filled; or swap the device glyph
for `exclamationmark.triangle.fill` at critical.

**"Asleep", "gone", "app blind" and "notifications denied" all render as the identical
everything-is-fine glyph.** Mouse hits 6%, item goes red, you ignore it, mouse sleeps → the
item returns to the calm plain glyph. The alarm silences itself precisely at the end of the
drain curve. Fix: cache `(percent, timestamp)`, keep drawing a vanished low device dimmed; badge
the idle glyph when notifications are denied.

### P2

**The level bar is 28pt wide and visually empty in every state a user sees.** It only appears
below the alert threshold, so its live range is 0–19%. On a 24pt track that is 1pt to 4.6pt of
fill — the whole spread is about a millimetre. Cost: 28pt of a measured 77.13pt item, **36% of
the width**, to duplicate the number less precisely. Fix: drop it when discharging (item goes
77 → 49pt), keep it only while charging where the fill traverses the whole track. Bar-present
then means "on a cable", which is another non-colour channel.

**No hysteresis.** `lowest.percent < alertThreshold` is a bare comparison, so 20 → 19 → 20
flips the item between 14pt and 77.13pt, shoving every icon left of it by 63pt each time. The
monospaced-digit work that stops twitch *within* a state is undone by the transition *between*
states. Fix: enter below the threshold, leave at threshold + 3.

**Charging takeover has no end.** A device at 95% on a cable seizes 83pt to say something you
already know. And `flags != 0` means a full-but-plugged device may never stop. Fix: take over
for ~2 minutes after a transition, or only below 50%; treat `percent >= 100 && isCharging` as a
distinct charged state.

**The idle glyph carries zero bits.** Between 20% and 100% — where devices live ~95% of the
time — the app says nothing without a click. Fix: fill the mouse silhouette proportionally to
the lowest device, still a template image. Zero extra width, no colour, and the glyph becomes a
gauge. Second-best: an "always show percentage" preference, which is table stakes in this
category.

**No accessibility description on the composed image.** VoiceOver announces nothing; the whole
item is a picture of a number.

**The tile repeats the bug already fixed in the menu bar.** `fillW = max(strip.width * percent
/ 100, stripH)` → every level ≤6% draws identically, and the tile only exists below 10%.

**The banner shows a full green battery next to "battery critical"** — the app icon is the
first thing the eye lands on and it says everything is fine.

**When both devices are low the second is invisible until you click.**

### P3

Idle canvas is 20pt tall, alert canvas 18pt, and a 20pt symbol is drawn into the 18pt canvas at
`y = -1`. Today that only trims transparent padding. The app icon at 16px is a generic green
battery — the mouse reading does not survive the downscale, and green is a claim the app cannot
guarantee. The `%` sign costs ~9pt and disambiguates nothing. Green means "healthy" in the
panel and "charging" in the menu bar.

### Called out as well done

Monospaced digits to stop width twitch. `isTemplate` set explicitly on both paths with the
reason recorded. Shrinking the fill's corner radius rather than flooring the fill — and the
write-up of the wrong fix. Low-water marks rather than a threshold ladder. The tile using the
urgency colour as ground rather than fill. `Urgency` as one enum feeding colour, wording and
tint. The white bolt drawn over the gauge rather than knocked out. IOKit interest notifications.

---

## Reviewer 2 — designer, panel and notifications

### P1

**There is no early warning at all; the first notification arrives at 9%.**
`evaluateNotification` returned early unless `percent < nagThreshold`. Crossing the alert
threshold changed only the menu bar — the one surface a user is least likely to be looking at.
The README's promise is only half kept: by the time the user is told in a channel that
interrupts, they have hours, not days. Fix: one notification on crossing the alert threshold,
different wording, no repeat, re-armed by the existing `rechargeDelta`.

**Up to ten notifications below the nag line, with sound, and no way to stop them.** Every new
low posts its own alert with a unique identifier, no `threadIdentifier`, no actions. Ten
sounds, ten rows, and the only escape is turning magicbar off in System Settings — which also
kills the useful first warning permanently, since authorization never re-prompts. Deliberate
nagging still needs an off switch. Fix, in order of value: (1) `content.threadIdentifier =
device.id` so they collapse into one stack; (2) a "Snooze until charged" notification action
that writes the current reading into `lowWaterMarks`; (3) a configurable step in points.

**The two steppers sit in an unlabelled group and read as a matched pair. They are not.** One
drives the menu bar, the other drives notifications and sits above the heading it belongs
under. But splitting them is only half right, because `alertThreshold` is *also* the
green/orange boundary for the panel bars and the tile tint. Fix: keep them together under a
heading that describes what they are — two urgency levels the whole app reacts to — and state
the consequence rather than the mechanism:

```
Levels
  Warn below     20% ⬍    menu bar shows the level in orange
  Urgent below   10% ⬍    menu bar turns red, and you get a
                          notification for every further percent lost
```

**"Notify on every % drop below 10%" is not parseable.** Two percent signs mean two different
things in one sentence: a step size and a threshold.

**Developer mode should not be in the shipping panel, and the useful half should not be behind
a checkbox.** Three problems stacked: the one thing a normal user needs (confirming
notifications work, given the mandatory manual System Settings step) is gated behind a box
labelled "Developer mode"; "Battery level — 5%" with a slider sitting under a live reading
reads as an override of the real level; and the developer half duplicates `--simulate`, which
the project's own testing doctrine says is the way to drive the app. Fix: promote a plain "Send
a test notification" button, always visible; delete the picker and slider or hide them behind
a hold-⌥ reveal.

### P2

**No `interruptionLevel`**, so a 4% alert during a Focus session is silently withheld — the
exact scenario the app exists for.

**The attached tile spends its whole slot on one bit.** At delivered banner size it is roughly
48pt square. The level strip is `12/256` of that — about 2 points — drawn in white at 30%
opacity against white, and in the banner screenshot it is simply not there. The device glyph is
redundant with the title, which already names the device. So what survives is the tint colour
and nothing else, while the number the user wants is in small body text. Fix: put the
percentage in the tile, large, white on the tint. Verify by scaling to 48px and looking, which
is how it should have been judged in the first place.

**The body text has no verb.** "4% remaining" restates the title. At the moment of the alert
the user needs to know whether to act now or tonight.

**Two devices of the same model are indistinguishable everywhere.** `shortName` maps any name
containing "Magic Mouse" to the literal "Magic Mouse". Fix: only strip the possessive when the
result is unique across the device list.

**The steppers hide an interdependency.** Bounds are `(nagThreshold + 1)...100` and
`1...(alertThreshold - 1)`, with steps of 5 and 1 for no visible reason. A user at 20/10
pressing down on the top stepper hits a floor with no explanation.

**Close-together values produce configurations nobody would choose, with no warning.** 20/19
gives a one-point orange band then 19 alerts. 100/1 makes the menu bar permanently show a
level — a feature people would want, and entirely undiscoverable. Fix: a live readback — "At
these settings a full drain sends 9 notifications."

**The panel is a settings window that happens to show batteries.** Readings occupy the top
fifth; everything below is touched once. Fix: collapse the settings behind a disclosure.

**A sleeping device silently disappears** and the empty state only appears when *every* device
is gone, so "the keyboard is fine" and "the app lost it" look identical.

**The armed state is invisible.** The low-water mark plus `rechargeDelta` means a user who tops
up to 12% and unplugs gets no alert until it drops below the old mark. Correct behaviour that
looks exactly like a broken app. Fix: "next alert at 6%" in the row.

**"Updates live" is a claim, not data**, and has already been wrong twice because it describes
intent. Fix: "Updated 4s ago".

**"Open Notification Settings" only exists while permission is denied**, and the README's other
manual step — switching the alert style from Banners to Alerts — has no pointer from the app
at all.

**The sound picker cannot be auditioned and has no "None".** The list is `["Default"] + system
sounds`, and `nagThreshold` bottoms out at 1, so **there is no way to turn notifications off
inside the app**.

### P3

The empty state is a full stop. No version, no About. Quit is a foot-gun styled as a caption.
Urgency in the panel is colour alone. A charging device still shows red — alarm and reassurance
in the same row.

### Called out as well done

The denied-permission banner clears itself once fixed in System Settings. The presentation
delegate keeping alerts alive while the popover has made the app frontmost — a trap that ships
broken constantly, at the exact moment a user presses test. `fireDeveloperNotification` not
moving the low-water mark, so testing cannot silence a real warning. `launchAtLogin` reading
back the system's actual state. The sound list enumerated from disk. The tile using urgency as
ground. One type size across the panel with hierarchy from weight and colour.

---

## Reviewer 3 — user, design studio, not technical

Briefed as someone on an iMac with a Magic Mouse and Keyboard, fifteen menu bar icons they
resent, and a specific grievance: the mouse dies mid-task and macOS only warns when it is
already too late.

**On first impression.** The top half of the panel made sense instantly — two devices, two
bars, two numbers, which macOS does not give them. Then they stalled on the settings.

They **misread the key setting**. "Notify on every % drop below 10%" was read as "notify me
when it goes below 10%" — one notification. It took a third pass at the word "every" to
realise it meant ten separate alerts, and they were not sure until they saw it happen. Asked
after installing what that setting did, they would have got it wrong.

**On the sound.** "I don't know what Hero sounds like. There's no play button. I'd be picking
blind from a list of words, and the first time I actually hear it will be at 9% while I'm
concentrating."

**On the panel colours.** Their mouse at 25% showed the same green as the keyboard at 61%. "25%
is not a green feeling. If everything is green until it isn't, the bar is just decoration and I
only ever read the number."

**On the banner.** "The notification has a cheerful green full battery on the left of the words
battery critical. Green icon, red icon, and the word critical, all in one small box."

**Does it solve their problem? Halfway.** The 20% badge is the genuinely useful part — a day or
two of warning instead of macOS's last second. But:

> It's still just a number, and a number doesn't tell me what to do. 20% on my mouse might be
> two days or two hours — I've never measured it, and this app doesn't measure it for me
> either. What I actually want to be told is "charge this tonight," not "20%."

And the reframing that matters most:

> Here's the thing it doesn't solve at all: I get caught mid-task. Always mid-task. This app
> warns me mid-task too. It's just a more detailed version of the same ambush. […] The warning
> I need is at the end of the day, when I'm packing up and plugging things in costs me nothing.
> Nothing in this app knows what time it is or what I'm doing.

**On the manual notification step**, they said they would have skipped it, the app would have
looked like it was working, and the first they would know is the mouse dying in silence. *(The
app does show a warning card with a link to the settings pane; they did not see it because the
screenshot they were given had permission already granted. Setup error on my part, not a
defect.)*

**On the ten notifications: no.**

> The first one is useful. The second one is a fair reminder. Three through ten are the app
> yelling at me about a thing I already know and physically cannot fix without stopping work.

They noted the last 10% goes fast, so it is ten alerts in about half an hour, each with a
sound, leaving a column of near-identical rows to clear. No snooze, no acknowledgement. Their
only lever is dragging the threshold to 3% — "my only escape from the nagging is to disable the
thing I installed it for." They would keep it about one battery cycle.

**What they would change and could not.** Turn the sound off (unsure "None" exists — it does
not). Nag less (impossible; the stepper moves where nagging starts, not how often). Always show
the percentage (they guessed setting the threshold to 100 might work — it does, and is
undiscoverable). Hide the icon when everything is fine (impossible, and they want it more than
expected: "a permanent icon whose message is nothing is wrong is rent I'm paying in menu bar
space").

They also flagged the width at 4% — "a red mouse, a red bar, and red text: three things all
telling me the same fact" — and that charging at 55% is the loudest thing on screen for the
least interesting state a battery can be in. And charging at 8% still being red: "It's plugged
in. The problem is being fixed. Why is it still shouting?"

### What I'd want next

1. Stop at two notifications, with a snooze button — or let me choose how often
2. An "unplug it, it's full" alert when charging finishes
3. Time remaining, not just a percentage — "about a day left"
4. Warn me at the end of the day, when I can actually act on it
5. Hide the menu bar icon completely when every device is fine
6. Tell me loudly if notification permission is off
7. A sound preview in the panel, and a "None" option
8. Quiet down the charging display
9. Battery history, so I learn what normal looks like
10. AirPods and everything else Bluetooth
11. A drag-to-Applications installer
12. A version number and an update check
13. Colour the bars by how worried I should be
14. Rename my devices

**Verdict:** keep it, on probation. Two changes would make it permanent — no icon when
everything is fine, and stop after two warnings.

---

## Reviewer 4 — user, developer with many peripherals

Briefed as someone who reads source before installing and has deleted four battery apps.

**Would install, after reading.** Grepped the tree for `URLSession`, `http`, analytics,
telemetry, Sparkle — zero hits. No packages, no launchd job, no update checker. MIT.

> `ARCHITECTURE.md` is the thing that actually earned my trust. It documents the route that
> *doesn't* work […] People who write down their dead ends have usually measured the live ones
> too.

**What made them hesitate:** no release, no notarized build, no checksum. "I have to open Xcode
and paste a build command that includes `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` — 'disable this
security-related build setting or the app doesn't work' is exactly the sentence I stop and
re-read." They read the entitlements comment as the quiet part out loud: this is a personal
tool that happens to be public.

**What annoyed them:** the login item registers itself on first launch without asking. "The
flag is even named `didOfferLoginItem`, but nothing is offered — it just does it. Two of the
four battery apps I deleted did something in that family."

**On their device zoo.** They ran the query themselves. Only mouse and keyboard publish under
`AppleDeviceManagementHIDEventService`; a trackpad and spare keyboard would too. AirPods would
not, or not usefully — the reader demands a single scalar `BatteryPercent` and AirPods publish
case/left/right through a different path. "The device I most want warned about — the AirPods
that die mid-call — is the one it probably can't see."

Two problems at that scale:

> **Charging outranks dying.** With six peripherals, something in my house is always on a
> cable. Drop the trackpad on USB-C at 80% while the mouse is at 4%, and the menu bar shows a
> cheerful green charging item while the 4% mouse disappears from the bar entirely. On two
> devices that's a rare coincidence. On six it's Tuesday. That's a bug, not a preference.

> **The popover doesn't scale and won't hold still.** Fixed 340pt, no scroll view, sorted
> lowest-first. […] I'd never learn where the trackpad row is. I want a stable order with the
> low one marked, not a leaderboard.

Also: icons stop at product IDs 617 and 620, so a Magic Trackpad falls through to a generic
battery — "`shortName` already knows about Magic Trackpad, so somebody thought about it; the
icon path just didn't get the memo."

**On the nagging.** They expected to hate it and partly did not:

> The low-water-mark logic is the good version of this. […] That's more care than any of the
> four apps I deleted. What's missing is consent.

No snooze, no quiet-until-charged, no per-device mute. And macOS already warns at 6% and 3%, so
"at 6% I get shouted at twice."

**On scripting.** `--dump-devices` output is usable, but it spins up a whole app instance to
print four fields, there is no `--json`, no exit code meaning "something is low", and no way to
query the running instance. What they want is a shell hook on threshold crossing — "one
`Process` call and a preference string" — which turns a notifier into infrastructure.

**What worried them in the source**, ranked:

> The 5-second poll is fine. […] What I'd actually patch is next to it: `refresh()` calls
> `notifier.refreshAuthorization()` every single tick, which is a `getNotificationSettings` XPC
> round trip to `usernoted` — roughly seventeen thousand IPC calls a day to keep a checkbox
> honest. […] Right beside it, `devices` gets reassigned every tick with no equality guard […]
> That's the difference between 0.0% and 0.3% idle CPU, and I have deleted an app for exactly
> that.

On the charging flag, which they verified independently on their own machine:

> `flags != 0` means charging is a guess with two data points, and the failure mode is nasty:
> if Apple ever sets another bit for something like a battery fault, the app reads it as
> charging, suppresses low alerts, and takes over the menu bar with a green item. One stray bit
> switches the app off.

Unsandboxed did not bother them, because they read the code and there is no network in it.

### What I'd want next

1. Fix charging outranking a dying device — it hides the thing the app exists to show
2. AirPods and other non-HID accessories, or say clearly they are out of scope
3. A shell hook on threshold cross, plus `--json` on the dump
4. Snooze / "quiet until charged" on the notification
5. Per-device thresholds and mute, with a stable popover order
6. Stop hammering `usernoted` every five seconds, and guard the publish on actual change
7. Ask before registering as a login item
8. A trackpad icon, and a 16px app icon that still looks like a mouse
9. Treat the charging flag as a known-value check, not `!= 0`
10. A signed release or a cask

---

## What the reviews changed about how this gets built

Two of the four defects were found by reviewers reading code rather than looking at pictures,
and one — the tile fill collapse — was a bug already fixed once in another file three
directories away. Both of those argue the same thing: rules that only exist inside the drawing
or the polling loop cannot be checked.

Three rules have since been pulled out into pure functions with their own launch arguments
(`--dump-cadence`, `--dump-retention`, and the menu bar choice printed by `--dump-devices`).
The first attempt to verify the alert cadence reported it broken when it was not — the probe
process exited before notification authorization resolved, so nothing was recorded. A rule
entangled with permission and persistence could not be checked at all.

---

## What the reviewers rated highly

Consolidated, because the praise is spread across four documents and says something the
findings do not.

**Three of the four singled out the low-water-mark alert logic** — the rule that replaced the
bash version's threshold ladder. The menu bar designer called it "the strongest thing in the
app, and the part users would have hated first". The developer, who was primed to dislike being
nagged, said it was "more care than any of the four apps I deleted" and that what was missing
was not the logic but consent.

**Two independently valued the dead ends being written down.** The developer was explicit that
`ARCHITECTURE.md` is what earned his trust, specifically because it records the route that does
*not* work: "people who write down their dead ends have usually measured the live ones too".
The menu bar designer said the write-up of the *wrong* fix to the fill-floor bug was "the more
valuable artefact" — more valuable than the fix.

**Traps that commonly ship broken, caught here:**

- The presentation delegate keeping an alert visible while the popover has made the app
  frontmost — "a trap that ships broken constantly, and it is the exact moment a user presses
  a test button".
- `isTemplate` set explicitly on both drawing paths, since a composed image silently inherits
  `true` from an SF Symbol and loses every colour.
- Monospaced digits to stop the menu bar twitching — "most people ship the twitch and never
  diagnose it".
- The white bolt drawn over the gauge rather than knocked out of it.
- `launchAtLogin` reading the system's real state back after setting it, so a failed
  registration shows as an unticked box rather than a checkbox that lies.
- `fireDeveloperNotification` not moving the low-water mark, so a test cannot silence a real
  warning that was due later.
- The denied-permission banner clearing itself once the user fixes System Settings, where most
  apps require a relaunch.

**Design decisions rated as correct:** `Urgency` as a single enum feeding colour, wording and
tint, so no two surfaces can disagree; the notification tile using the urgency colour as the
ground rather than the fill; one type size across the panel with hierarchy from weight and
colour, "why the panel reads as one widget rather than three stacked ones"; the sound list
enumerated from disk rather than hardcoded; IOKit interest notifications so a cable lands
immediately.

**On trust,** the developer grepped for `URLSession`, `http`, analytics, telemetry and Sparkle
and found none, noted no packages and no update checker, and rated the 5-second poll a
non-issue. Unsandboxed did not concern him because he had read the code.

**From the non-technical user,** the only unqualified praise: the device list "made sense
instantly — two devices, two bars, two numbers. That's exactly what I wanted and macOS doesn't
give me it", and the 20% badge as "a day or two earlier" than macOS.

### The pattern worth noticing

Almost all of the praise is for **engineering judgement**, not for the product. Nobody rated
the concept, the escalation model, or the interface beyond the device list. The two users
arrived with a problem and both said the app addresses it only halfway — it tells you the
number sooner, but still at a moment you cannot act on, and then repeats itself. The
craftsmanship is not in question. What the app is *for* still is.
