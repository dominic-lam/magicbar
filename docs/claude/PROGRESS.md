# magicbar Development Progress Index

Open work is in [`TODO.md`](./TODO.md); sequencing in [`ROADMAP.md`](./ROADMAP.md);
user-facing release notes in `CHANGELOG.md`.

## Navigation

| Looking for | Go to |
|---|---|
| What happened in a session | § Session Log, below |
| Older sessions | `docs/archive/progress/` |
| Why the code is shaped this way | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| The bash implementation | `git checkout bash-final` |

## Version Timeline

| Version | Date | What |
|---|---|---|
| v0.1.0 | 2026-04-21 | bash: SwiftBar plugin, launchd notifier, ioreg read. Never installed. |
| v1.0.0 | 2026-09-08 | Swift menu bar app. Bash deleted, dependencies dropped. |
| v1.2.0 | 2026-09-13 | First public release via CI: update check, drain estimate, plain-language README. |

## Milestones & Key Sessions

- **2026-09-13 — v1.2.0 released.** The first finished build on GitHub Releases, published by
  the tag workflow and verified by download. Shipped ahead of two gates the project had set: the
  daily reminder had never fired, and the diagnostics could still write to real data.
- **2026-04-21 — the repo exists.** Ad-hoc scripts extracted into a project with a shared
  library, tests and an installer. Then untouched for four and a half months.
- **2026-09-09 — reviewed and reshaped.** Four reviewers found 37 things, nine of them real
  defects or model problems. The settings were rebuilt to the user's design and the app gained
  the half it was missing: reminders tied to a moment rather than to a level.
- **2026-09-08 — found, documented, then rewritten.** The predecessor scripts were traced and
  stopped, this repo was documented, and the whole implementation was replaced with a native
  app in the same day.

## Archive Policy

Archive the oldest 10 entries when the Session Log exceeds 15 → `docs/archive/progress/`.

## Statistics

| | |
|---|---|
| Swift source files | 12 |
| Third-party dependencies | 0 |
| Network access | one optional GitHub release check, daily or on click — never installs |
| Dependencies dropped in the rewrite | SwiftBar, terminal-notifier, launchd |
| Devices monitored | every peripheral that reports a battery, discovered not configured |

## Session Log

Newest first, directly below the marker. Three-line format, one entry per session.

<!-- Append new entries here -->

## 2026-09-18 (Session 8 — the estimate judged on a full real run, and two new estimates)
**Completed:** Found the daily reminder's first firing in the log (2026-09-17 23:00, carrying "about 33 hours left"); replayed the saved readings through the app's own estimate code, compiled on its own so no diagnostic touched real data, and showed the clock estimate smooth but slipping its "empty at" by two days over the week; backtested it against seven alternatives on the first complete mouse run (41% → 4%) — windows, trailing rates, time-of-day profiles and Android's step averaging — and none beat it by more than a tenth, because daily use varied sixfold; measured in-use drain by level band and found the bottom 10% about twice as fast as the middle; then added a second drain estimate in hours of use, shown beside the first at every level, and a time-to-full estimate learned per level from recorded charges, both with `--check-estimate` cases, built, installed and seen producing real numbers.
**In progress:** The diagnostics still write to real app data; the two drain estimates and the charge estimate have each seen one run, so none is judged yet.
**Next session should:** Leave the mouse to run down from the 100% it reached at 17:40 with no top-up, and when it is next plugged in, replay the charge estimates against the real finish.

*Later the same day:* the user confirmed seeing the 23:00 reminder, which closes it end to end. The charge finished at 17:40 — 4% → 100% in 3 h 31 min — and the estimate scored 77 minutes short at 55%, 9 short at 90% and exact from 95%, because the taper (1.6 min per 1% at 50–60%, 3.3 from 70%) had never been seen. The 4% → 50% readings recovered from the log were then loaded into the app's record by `docs/reference/backfill-charge-2026-09-18.sh`, run at the user's word after a preferences backup, so the per-level table covers the whole curve. The global response-style instructions were also rewritten around replies being read from the bottom up.

## 2026-09-16 (Session 7 — the estimate explained, published, and set up to be judged)
**Completed:** Worked the drain estimate end to end and published it as a walkthrough with the real readings embedded — an artifact plus a copy in the repo — then extended it with what a charge does to the rate and with the same readings fitted from different starting points, which showed a 12-hour window claiming 20%/day and a 24-hour one 5%/day against the full history's 9%/day; documented that no rate is ever cached and what actually triggers a recompute; established from the registry that no battery-health reading exists for these peripherals and recorded wear-from-drain-trend as an idea; and removed the 200-sample history cap so several charge cycles survive for judging the model.
**In progress:** The daily reminder is still unproven, the diagnostics still write to real app data, and no charge cycle has yet been recorded under the new uncapped storage.
**Next session should:** Set the daily reminder hour to the next hour and confirm a real `evening reminder` line appears in the log.

## 2026-09-13 (Session 6 — an estimate that survives a charge, and 1.2.0 released)
**Completed:** Added a GitHub link to the popover footer, guarded the documented install command after a hung `-showBuildSettings` left the build path empty and deleted the installed app, reworked the drain estimate so the rate is fitted across every run between charges with quiet time counted and a 24-hour floor (checked by a new `--check-estimate`, and the real saved history confirmed migrated), stopped tracking Affinity source files, released `v1.2.0` — download verified by checksum, signature and version, and the update check confirmed against a real release — and established that no battery-health reading is exposed, recording wear-from-drain-trend as an idea.
**In progress:** The daily reminder is still unproven, the diagnostics still write to real app data, and the downloaded `v1.2.0` has not been opened past Gatekeeper.
**Next session should:** Set the daily reminder hour to the next hour and confirm a real `evening reminder` line appears in the log.

## 2026-09-12 (Session 5 — an update check, a README for non-developers, and a diagnostic that ate real data)
**Completed:** Added an optional update check — a daily GitHub release query plus a "Check now" button, the app's only network access, which never downloads or installs anything — replaced the misleading "Updates live" footer with the version number and a "Battery levels refresh automatically" line, added a developer-mode refresh timestamp, raised every popover font by 2 pt, rewrote the README for non-technical users with the technical material moved to `docs/DEVELOPMENT.md`, and drafted a gitignored Reddit launch plan; along the way found that the daily reminder has never fired and that `--dump-retention` writes into real app data, which deleted the keyboard's drain history.
**In progress:** The daily reminder is still unproven, the diagnostics bug is unfixed, and the README's popover screenshot shows the old layout.
**Next session should:** Set the daily reminder hour to the next hour and confirm a real `evening reminder` line appears in the log.

## 2026-09-09 (Session 4 — distribution decided, the sleep reminder proven undeliverable, the drain estimate shipped)
**Completed:** Decided distribution — open source only, no paid Apple Developer account, so no App Store or notarisation — and built two GitHub Actions workflows for it: a build check on every push, and an ad-hoc-signed Release zip on a `v*` tag, both verified locally in a clean clone. Found and fixed the wake reminder nagging on every quick lid-close instead of only a real absence. Then built, measured and removed a sleep-time chime: both a notification and a sound proved undeliverable at the moment of sleep — the display and the audio device are both already off by the time the app is told — and the second attempt stalled every sleep by fifteen seconds, caught in the system's own power log. Replaced the whole sleep/wake reminder with a persisted, timestamped drain history and a least-squares "about three days left" estimate, shown in the popover and folded into the daily reminder, verified against ten synthetic series and a new `--dump-estimate` diagnostic.
**In progress:** `v1.2.0-rc.1` is published and the pipeline is verified end to end, but the app inside it is not: the daily reminder has never fired and the drain estimate has only ever seen synthetic data. Gatekeeper rejects the downloaded copy, as expected for an unnotarised build.
**Next session should:** Promote `v1.2.0-rc.1` to `v1.2.0` once the daily reminder has actually fired and the drain estimate has produced a real number.

## 2026-09-09 (Session 3 — reviewed by four, four defects fixed, and the settings rebuilt)
**Completed:** Ran four reviewers over the app, two briefed as designers and two role-playing users, and recorded all 37 findings in `debriefs/2026-09-08-design-review.md`. Fixed the four real defects they found, including a charging device hiding a dying one and a repeat of the fill-floor bug in the notification tile. Rebuilt the settings around a two-handle level slider to the user's own design, replaced the notification model with a master switch plus two independently targeted cadence rules, added sleep and daily charge reminders, and made the high-contrast alert style an option rather than the default.
**In progress:** The two new reminders are unverified — neither the sleep hook nor the daily check has had the chance to fire. The user is testing both over the next few days.
**Next session should:** Discuss how to wrap this up and release it. The open question is distribution: the install is a wall of Terminal commands, there is no signed build, and both user reviewers named that as the first wall they hit.

## 2026-09-08 (Session 2 — bash replaced by a native menu bar app in one sitting)
**Completed:** Tagged and deleted the bash implementation, then built magicbar as a SwiftUI `MenuBarExtra` app: registry-based device discovery, a two-state drawn menu bar label, a low-water-mark notification rule that kills the old alert cascade, popover threshold controls and `SMAppService` login registration. Installed to `/Applications` and verified discovery, both label states and the full notification decision sequence from the terminal.
**In progress:** Notification *delivery* is blocked — macOS recorded a refusal when the first launch was a debuggable Debug build, and that persists per bundle ID. The fix is one switch in System Settings.
**Next session should:** Allow notifications in System Settings › Notifications › magicbar, then confirm a real alert is delivered by simulating a drop from 9% to 8%.

## 2026-09-08 (Session 1 — the predecessor stopped, this repo found and documented)
**Completed:** Traced the running battery notifier to hand-written scripts outside version control, reproduced a notification-cascade bug in them, unloaded their launch agent, then found this repo, ran its tests green and scaffolded the documentation workflow.
**In progress:** Nothing. Four defects recorded, none touched.
**Next session should:** Fix the blip cascade in the notifier.
