# magicbar — Roadmap

Sequencing only. Features are described in [`FEATURES.md`](./FEATURES.md); open work is in
[`TODO.md`](./TODO.md); what shipped is in `CHANGELOG.md` and [`PROGRESS.md`](./PROGRESS.md).
Never add a feature description here.

*Rewritten 2026-09-08 after the Swift rewrite closed phases 3 through 5 in one session.*

## Where we are

v1.0.0 is built, installed and running, with every dependency the bash version needed now gone.
Discovery, both menu bar states and the notification decision logic are verified. The one thing
not working is notification *delivery*, blocked on a macOS permission the app cannot grant
itself.

## Phases

| Phase | What | Status |
|---|---|---|
| 1 | Extract the ad-hoc scripts into a repo | Shipped 2026-04-21 (`f0e168b`) |
| 2 | Documentation workflow | Shipped 2026-09-08 (`fd170ad`) |
| 3 | Replace bash with a native menu bar app | Shipped 2026-09-08 |
| 4 | Multi-device monitoring | Shipped 2026-09-08 — dissolved by discovery, not built |
| 5 | Fix the alert cascade | Shipped 2026-09-08 — low-water marks replaced the ladder |
| 6 | Notifications actually delivering | Shipped 2026-09-08 |
| 7 | Charging awareness, stale-device display | Shipped 2026-09-09 |
| 8 | Design review, and the settings rebuilt around it | Shipped 2026-09-09 |
| 9 | Release: signed build, and how anyone installs it | Now |
| 10 | Retire the predecessor scripts | Next — after a reboot proves self-start |

## Now / next / later

- **Now (phase 9):** decide how this is released. Both user reviewers named the Terminal-only
  install as the first wall they hit, and there is no signed build. Nothing else in the backlog
  is larger than that decision.
- **Next (phase 10):** confirm the two new reminders fire, then decommission the predecessor
  per `MIGRATION.md`.
- **Later:** everything in `FEATURES.md` § Idea. None of it is committed.
- **Not planned:** distribution, notarisation, non-Apple peripherals, a preferences window.
  The popover is the whole interface.

## Rules

- A phase is sequencing, not a commitment. Status lives only in `FEATURES.md`.
- Shipped phases stay as one table row.
- Three phases closed by making them unnecessary rather than by building them. Prefer that.
