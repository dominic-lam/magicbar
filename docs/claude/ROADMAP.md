# magicbar — Roadmap

Sequencing only. Features are described in [`FEATURES.md`](./FEATURES.md); open work is in
[`TODO.md`](./TODO.md); what shipped is in `CHANGELOG.md` and [`PROGRESS.md`](./PROGRESS.md).
Never add a feature description here — add an entry to `FEATURES.md` and link it.

*Created 2026-09-08.*

## Where we are

The repo has been feature-complete for its v1 scope since 2026-04-21 and **has never been installed**.
A predecessor set of hand-written scripts did the real work until 2026-09-08, when their launch agent
was unloaded at the user's request. Nothing is currently monitoring any battery.

Four known defects are documented and unfixed, two of which affect anyone who installs today. The
decision in front of the project is whether to install it at all, and the fixes are the price of yes.

## Phases

| Phase | What | Status |
|---|---|---|
| 1 | Extract the ad-hoc scripts into a repo — shared library, tests, install/uninstall | Shipped 2026-04-21 (`f0e168b`) |
| 2 | Documentation scaffold — CLAUDE.md and the `docs/claude/` workflow | Shipped 2026-09-08 |
| 3 | Fix the known defects — blip cascade, installer label, hardcoded names | Now |
| 4 | Multi-device monitoring — the keyboard, the original point | Next |
| 5 | First real install, predecessor decommissioned via `MIGRATION.md` | Next |
| 6 | Quieter thresholds, menu bar for both devices, notification actions | Later |

## Now / next / later

- **Now (phase 3):** the three defects in `TODO.md` § Active → Bugs, in that order. The blip cascade
  first, because it is the one that produces visible noise. Nothing should be installed before this.
- **Next (phases 4–5):** per-device state, then the keyboard, then the display-name constant so alerts
  name the right device. Install once that lands, and retire the predecessor in the same session.
- **Later (phase 6):** everything in `FEATURES.md` § Idea. None of it is committed.
- **Not planned:** a GUI, non-Apple peripherals, a Homebrew formula. Distribution is `git clone`.

## Rules

- A phase is sequencing, not a commitment. Status lives only in `FEATURES.md`.
- Shipped phases stay as one table row; the detail is in `CHANGELOG.md` and `PROGRESS.md`.
- Do not install before phase 3 closes. Shipping known-noisy notifications is how the predecessor
  earned its reputation.
