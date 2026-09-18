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

- [ ] **Score the first recorded charge, then let the mouse run down from full without a top-up.**
      The Magic Mouse went on the cable at 4% at 14:09 on 2026-09-18 and read 69% at 16:00, still
      charging, with "about 1 hr 2 min to full" showing. The app has recorded it from 50% up
      (`charges` in the saved `drainHistory`); 4% → 49% is in
      `docs/reference/charge-curve-2026-09-18.txt`. Replay what the estimate said at each percent
      against when 100% actually arrived, append 50% → 100% to that file, and confirm the taper:
      steps were 1.55 min per 1% up to 49% and 2.5–3 min by 66–69%. The user agreed on 2026-09-18
      to run the next discharge from full with no top-ups, which is the only way 100% → 41% is ever
      recorded.
- [ ] **Stop the diagnostic launch arguments writing to real app data.** On 2026-09-12
      `--dump-retention` left simulated series `617` and `620` in `drainHistory` and deleted the
      Magic Keyboard's real series. The diagnostics build a real `BatteryStore` on
      `UserDefaults.standard`. `v1.2.0` shipped with this open; `docs/DEVELOPMENT.md` warns about
      it. Isolate the diagnostics from `UserDefaults.standard`, then drop that warning. Until then,
      read the history with `defaults export` and replay it through `DrainHistory` compiled on its
      own, as session 8 did.
- [ ] **Open the downloaded `v1.2.0` past Gatekeeper.** Read back 2026-09-18: `gh release view
      v1.2.0` reports published, not a draft, not a prerelease. Already verified 2026-09-13:
      checksum, version 1.2.0, ad-hoc signature, no `get-task-allow`, `--check-updates` reports no
      update. Unseen: the Open Anyway step on a downloaded copy, and its footer reading
      `magicbar 1.2.0`. Needs the user's hands.

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

- [ ] **The daily reminder fired; whether it was seen is unknown.** First firing on record:
      2026-09-17 23:00:01, "evening reminder for Magic Mouse at 11% — about 33 hours left. Charge
      it tonight", with no `reminder failed` line after it. The user was asked on 2026-09-18
      whether a banner appeared and has not answered.
      *Next action:* ask again. Then pick an hour that is actually before the user stops for the
      night — it is still 23, and the check only runs from the chosen hour until midnight, so a
      Mac asleep for that one hour skips the day.
- [ ] **The evening reminder's "already sent today" is not persisted** (`lastEveningReminder`,
      `BatteryStore.swift`). Relaunching after the hour sends that day's reminder again.
      *Next action:* store it in `UserDefaults`, or accept it as harmless.
- [ ] **Retire the predecessor scripts** per `MIGRATION.md`, once a reboot confirms magicbar
      starts itself. Blocked on that reboot: the Mac last booted 2026-08-24, before magicbar
      existed. `com.dominic.mousebattery.plist` is still in `~/Library/LaunchAgents`.

### The estimate model

- [ ] **Judge the two drain estimates against each other over 3–5 cycles.** Since 2026-09-18 the
      popover shows both under every device at every level — "about 2 days left" (the clock, one
      least-squares rate) and "about 84 hours of use left" (median time per 1% while in use) — and
      both are logged at each recorded change. The user's acceptance criterion is a car's
      fuel-range gauge: *no sudden jumps.* The first real run showed the clock estimate smooth but
      wrong by 14 hours on average, because daily use varied sixfold; seven alternative clock
      models, Android's included, did no better than about a tenth. Findings: `ARCHITECTURE.md`, "What the first real
      run showed". Baseline data and scripts: `docs/reference/estimate-backtest/`.
      *Next action:* when the next run reaches 30%, rerun the band table (`analysis2.py`) and see
      whether the fast 30–41% band repeats on a lighter day than the Monday it fell on.
- [ ] **The drain runs about twice as fast below 10%, and neither estimate knows.** In-use drain
      was 0.8–0.9 %/h between 10% and 30% and 1.9 %/h below 10%; "about 23 hours left" at 7% was
      followed by 4% after 45 minutes of use. One run, five gaps. A stopgap — hide or halve the
      hours below 10% — was offered on 2026-09-18 and the user chose to watch both estimates
      unaltered first.
      *Next action:* after a second run reaches single digits, decide between the stopgap and the
      per-level correction recorded in `FEATURES.md`.
- [ ] **`BatteryReader` logs a line every five seconds while anything charges.** It is how the
      4% → 49% charge curve was recovered on 2026-09-18, and it may be why the system log reached
      back only a day. Charges are now recorded in `drainHistory`, so the line has no job left.
      *Next action:* log on change only. Raised with the user 2026-09-18, not yet answered.
- [ ] **Set `MARKETING_VERSION` to the next tag before releasing.** The installed build carries
      the two new estimates and still reads 1.2.0, the same as the published release.

### Launch

- [ ] **Post to Reddit after `v1.2.0`.** Plan and drafts are in `docs/launch/REDDIT.md` —
      gitignored, this machine only. r/macapps first, r/swift days later with a technical angle,
      r/MacOS only if its rules allow. No subreddit rule has been read at the source: Reddit
      refuses logged-out requests.
      *Next action:* capture the orange and red menu bar screenshots, then read each sidebar
      while logged in.

## Previously active

### Bugs

The diagnostics writing to real app data — see NEXT SESSION.

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
- **The charge estimate's first step after a mid-charge launch is short.** The app starts partway
  through a percent and records it as if it had just begun — 15 seconds on 2026-09-18. The median
  ignores one; it would matter only if most charges were watched from a relaunch.
