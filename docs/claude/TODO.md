# magicbar — Current Work Items

**Where a new item goes:**

| If it… | Put it in |
|---|---|
| is one of the next 3 things to do | **NEXT SESSION** |
| has a real, known next action | **Active** |
| is a risk or a number to re-check, with no action yet | **Watch list** |
| is a feature nobody has committed to | **not here** — `FEATURES.md`, status *Idea* |
| is a fact, finding, or procedure | **not here** — `ARCHITECTURE.md` |

Close items by ticking the box, not by rewriting them. Once something ships and has no open
thread, delete it rather than leaving a status block behind.

*Rewritten 2026-09-08 after the Swift rewrite. Three of the four defects listed here before
were dissolved by that rewrite rather than fixed — see PROGRESS.md.*

---

## Operating constraints

**Installed and running** at `/Applications/magicbar.app`, registered as a login item.
**Distribution works.** 2026-09-09: open source only, no App Store, no $99/year developer
account — the project's headroom does not cover it. Two GitHub Actions workflows
(`.github/workflows/build.yml`, `release.yml`) build on every push and publish an ad-hoc-signed
zip to GitHub Releases on a `v*` tag. Both ran green on GitHub on 2026-09-10, and
`v1.2.0-rc.1` is published and verified by download. A hyphen in the tag marks it a
prerelease, so the pipeline can be exercised without claiming a build is finished.

The app is **not notarised** and will not be. A downloaded copy is rejected by Gatekeeper —
confirmed, not assumed — so the user must approve it once under System Settings › Privacy &
Security. The release notes carry that instruction; do not quietly drop it.

- Build **Release** with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` or notifications will never
  work. A Debug build is debuggable and macOS refuses it authorization.
- Install to `/Applications`, never run from the build directory. The login item registration
  binds to the launch path.
- The predecessor ad-hoc scripts are still on disk in `~/bin` and `~/SwiftBar` with their
  launch agent unloaded but its plist still present, so they return at next login. See
  `MIGRATION.md`.
- Keep `MARKETING_VERSION` in the project in step with the next tag (1.2.0 since 2026-09-12).
  Local builds read their version from it, and a stale value makes the update check announce
  the app to itself.

---

## NEXT SESSION

- [ ] **Retake the README screenshots, now that `--simulate` is safe.** Since `4a9bc78`
      (2026-09-25) a simulated launch works on a copy of the saved data. The popover shot predates
      the 2026-09-12 layout and the orange and red menu bar labels were never captured — see
      "Docs & hygiene". While at it, look at a popover with two mice: simulated
      (`--simulate "Home Magic Mouse:30,Work Magic Mouse:50,620:62"`), or live now that the user
      has a second one, "Old Magic Mouse" (address `d0-81-7a-e8-0d-85`, renamed 2026-10-07).
- [ ] **Ask the user whether to release the unreleased work as 1.3.0.** `CHANGELOG.md`
      § Unreleased holds the use and charge estimates (the charge one scored to the minute twice),
      full names for two of a kind, the untrimmed history and the last-10% fix. Releasing means
      setting `MARKETING_VERSION` (still 1.2.0) and tagging. It also unparks the Gatekeeper test
      below: a 1.3.0 download saves charges, so opening it on this Mac would not drop the curve.

## Active

> The 28 open findings from the 2026-09-08 design review are triaged in
> [`debriefs/2026-09-08-design-review.md`](./debriefs/2026-09-08-design-review.md).
> The items below are the ones with a decided next action; the rest live in that table.

### From the review, highest value first

- [ ] **The charging flag is `!= 0`.** If Apple ever sets another bit, the app reads a fault as
      charging, suppresses low alerts and turns green — one stray bit switches it off. Now
      that 3 is confirmed as the charging value, this is a small change.
      *Next action:* treat 3 as charging, log anything else.
- [ ] **The test button is gated behind developer mode**, which is where the one check a normal
      user needs is hardest to find.
      *Next action:* promote it, and decide whether the slider stays behind ⌥.
- [ ] **Snooze on the notification.** Raised by all four, but partly answered: unticking the 1%
      rule is now a standing "stop nagging me". A per-occasion snooze is still missing.
      *Next action:* decide whether the standing setting is enough.

- [ ] **The daily reminder works; its hour is still 23.** It fired on 2026-09-17 at 23:00:01 with
      "about 33 hours left. Charge it tonight", and the user confirmed on 2026-09-18 that they saw
      it. The check only runs from the chosen hour until midnight, so a Mac asleep for that one
      hour skips the day.
      *Next action:* pick an hour that is actually before the user stops for the night.
- [ ] **The evening reminder's "already sent today" is not persisted** (`lastEveningReminder`,
      `BatteryStore.swift`). Relaunching after the hour sends that day's reminder again.
      *Next action:* store it in `UserDefaults`, or accept it as harmless.
- [ ] **Retire the predecessor scripts** per `MIGRATION.md`. The reboot is done: the Mac booted
      2026-10-01 15:54:38 and magicbar started itself 42 seconds later. The old agent came back
      with it and recorded a 15% alert on 2026-10-05; on 2026-10-06 it was booted out of launchd
      and its plist moved to `~/bin/com.dominic.mousebattery.plist`, beside the script.
      *Next action:* delete the leftovers per `MIGRATION.md` steps 3–5, plus that moved plist.

### The estimate model

- [ ] **Judge the two drain estimates against each other over 3–5 cycles.** Since 2026-09-18 the
      popover shows both under every device at every level — "about 2 days left" (the clock, one
      least-squares rate) and "about 84 hours of use left" (median time per 1% while in use) — and
      both are logged at each recorded change. The user's acceptance criterion is a car's
      fuel-range gauge: *no sudden jumps.* The first real run showed the clock estimate smooth but
      wrong by 14 hours on average, because daily use varied sixfold; seven alternative clock
      models, Android's included, did no better than about a tenth. Findings: `ARCHITECTURE.md`, "What the first real
      run showed". Baseline data and scripts: `docs/reference/estimate-backtest/`.
      *Next action:* two runs are judged (`ARCHITECTURE.md`, "What the second run showed"); the
      third began at 100% at 21:55 on 2026-10-07 and at 4.9%/day reaches 10% around 2026-10-25.
      Then rerun `run2-score.py`, score the last-10% fix (installed 2026-10-07: "about 19 days
      left" and "about 93 hours of use left" at 100%) against the real finish, and check whether
      100% → 97% again went in about an hour.
- [ ] **`BatteryReader` logs a line every five seconds while anything charges.** It is how the
      4% → 49% charge curve was recovered on 2026-09-18, and it may be why the system log reached
      back only a day. Charges are now recorded in `drainHistory`, so the line has no job left.
      *Next action:* log on change only. Raised with the user 2026-09-18, not yet answered.

### Launch

- [ ] **Open the downloaded `v1.2.0` past Gatekeeper.** Parked by the user 2026-09-25. Verified
      2026-09-13: checksum, version, ad-hoc signature, no `get-task-allow`; `gh release view`
      read back 2026-09-26: published, not a draft or prerelease, zip and checksum attached. Unseen: the Open Anyway step and the footer
      reading `magicbar 1.2.0`. **Not on this Mac without a settings backup:** `v1.2.0` saves only
      drain runs to the same `drainHistory` key, so its first save would drop the recorded charge
      curve (read from its tagged source 2026-09-25). Needs the user's hands.
      *Next action:* do it before the Reddit post — on the other Mac if magicbar is not
      installed there, which also makes it a true first-run test.
- [ ] **Post to Reddit after `v1.2.0`.** Plan and drafts are in `docs/launch/REDDIT.md` —
      gitignored, this machine only. r/macapps first, r/swift days later with a technical angle,
      r/MacOS only if its rules allow. No subreddit rule has been read at the source: Reddit
      refuses logged-out requests.
      *Next action:* capture the orange and red menu bar screenshots, then read each sidebar
      while logged in.

## Previously active

### Features

- [ ] **Keep a vanished device visible.** Done for low devices: one that vanishes below the warn
      level stays listed for 30 minutes marked "last seen" (confirmed with `--dump-retention`,
      2026-09-12). A healthy device still simply disappears.
      *Next action:* decide whether a healthy device should stay listed too.

### Docs & hygiene

- [ ] **The README still cannot show a low battery, and its popover shot is out of date.**
      The README was rewritten for non-technical readers on 2026-09-12, with build steps and
      diagnostics moved to `docs/DEVELOPMENT.md`. `docs/screenshots/popover.png` predates that
      day's popover changes: fonts 2 pt larger, "Updates live" gone, a "Check for updates" row
      and a version footer added. The orange and red menu bar labels were never captured.
      *Next action:* retake the popover shot, then capture the warn and urgent labels with
      `open /Applications/magicbar.app --args --simulate "617:9,620:62"` and add them beside
      the prose that describes them.
      *Note:* the nine shots in `docs/review-shots/` are evidence for the 2026-09-08 debrief and
      show settings that no longer exist. Leave them; do not reuse them in user-facing docs.
- [ ] **`MIGRATION.md` is gitignored**, so the decommissioning guide exists on one machine only.
      *Next action:* decide whether that is still right now that it covers the predecessor only.

---

## Watch list

- **Notification permission was granted late and the reason is not fully understood.** It read
  as denied through several launches, then resolved to authorized once a non-debuggable
  Release build had been installed for a while. Do not assume a Debug build can ever notify.
- **macOS warns about these batteries too**, at 6% and 3%, from Control Center. Two systems now
  nag about the same device. Apple's can be silenced separately in System Settings.
- **Apple could rename or restructure the registry class.** Everything funnels through one
  service class; a change breaks discovery entirely. The failure is visible (no devices) rather
  than silent, which is the good version of this problem.
- **Sandbox denial would be silent.** Reading registry properties works sandboxed today, but a
  denial returns success with the properties stripped rather than an error. The app runs
  unsandboxed, so this only matters if that changes.
- **The free signing certificate expires yearly** and needs an Xcode renewal. `SMAppService`
  requires a signed app, so login-at-start dies with it.
- **The label colour sampling only proves 1x.** Retina correctness rests on using the
  scale-aware drawing API, not on a measurement.
- **Anyone on `v1.2.0-rc.1` will never hear about an update.** That build predates the update
  check, so the notice reaches only installs from the next release on.
- **The level creeps up a point or two just after a charge** (39 → 40 → 41, 2026-09-13). Those
  readings stay in the new segment and flatten the fitted rate slightly — optimistic. Worth
  correcting only if the 2026-09-16 comparison shows the estimate running long.
- **A missing log line older than about a day proves nothing.** On 2026-09-18 a six-day
  `log show` returned nothing before 23:00 the previous evening. The earlier "the reminder never
  fired" finding was read while those days were still held, so it probably stands, but the same
  search today could not have confirmed it.
- **Full names on a clash have met one real pair, in the log only** (2026-10-07): a second Magic
  Mouse beside the first on its cable read "Dominic Magic Mouse" and "Magic Mouse". The popover
  with that pair is unseen, and a live device beside a remembered one of the same kind has never
  happened, which `--simulate` cannot produce.
- **The charge estimate's first step after a mid-charge launch is short.** The app starts partway
  through a percent and records it as if it had just begun — 15 seconds on 2026-09-18. The median
  ignores one; it would matter only if most charges were watched from a relaunch.
