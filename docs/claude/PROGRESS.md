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

## Milestones & Key Sessions

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
| Swift source files | 10 |
| Third-party dependencies | 0 |
| Dependencies dropped in the rewrite | SwiftBar, terminal-notifier, launchd |
| Devices monitored | every peripheral that reports a battery, discovered not configured |

## Session Log

Newest first, directly below the marker. Three-line format, one entry per session.

<!-- Append new entries here -->

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
