# magicbar Development Progress Index

Navigation index for session history. Open work is in [`TODO.md`](./TODO.md); sequencing in
[`ROADMAP.md`](./ROADMAP.md); user-facing release notes in `CHANGELOG.md`.

## Navigation

| Looking for | Go to |
|---|---|
| What happened in a session | § Session Log, below |
| Older sessions | `docs/archive/progress/` |
| A release's user-facing changes | `CHANGELOG.md` |
| Why the code is shaped this way | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| A day's plan and its reflection | `docs/claude/day-plans/` |
| A longer write-up of one piece of work | `docs/claude/debriefs/` |

## Version Timeline

| Version | Date | What |
|---|---|---|
| v0.1.0 | 2026-04-21 | Initial scaffold: shared library, launchd notifier, SwiftBar plugin, tests, installer |
| — | 2026-09-08 | Documentation scaffold. No code change. |

Never released or tagged. Never installed.

## Milestones & Key Sessions

- **2026-04-21 — the repo exists.** Ad-hoc scripts extracted into a real project with a shared
  library, a test suite and an installer. Two commits, then untouched for four and a half months.
- **2026-09-08 — the predecessor stopped, this repo documented.** The hand-written scripts that had
  been running were unloaded, four defects in this repo were found and recorded, and the docs
  workflow was scaffolded.

## Archive Policy

Archive the oldest 10 entries when the Session Log exceeds 15 → `docs/archive/progress/PROGRESS-sessions-NN-NN.md`.

## Statistics

| | |
|---|---|
| Commits | 2 |
| Test assertions | 6, all passing as of 2026-09-08 |
| Lines of shell + docs at scaffold | 622 |
| Times installed | 0 |

## Session Log

Newest first. Three-line format, one entry per session.

## 2026-09-08 (Session 1 — the predecessor stopped, this repo found and documented)
**Completed:** Traced the running battery notifier to a pair of hand-written scripts outside version control, reproduced a notification-cascade bug in them, unloaded their launch agent at the user's request, then found this repo, reviewed it, ran its tests green, and scaffolded `CLAUDE.md` plus the `docs/claude/` workflow.
**In progress:** Nothing. Four defects are recorded in `TODO.md` but none were touched.
**Next session should:** Fix the blip cascade in `bin/battery_alert.sh` — the recharge check compares a live percentage against a stored threshold, so a one-point rise re-arms the whole ladder.
