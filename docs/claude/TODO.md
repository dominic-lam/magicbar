# magicbar — Current Work Items

**Where a new item goes:**

| If it… | Put it in |
|---|---|
| is one of the next 3 things to do | **NEXT SESSION** |
| has a real, known next action | **Active** |
| is a risk or a number to re-check, with no action yet | **Watch list** |
| is a feature nobody has committed to | **not here** — an entry in `FEATURES.md` (status *Idea*) |
| is a committed feature | **Active**, as a stub: checkbox · one line · next action · link to its `FEATURES.md` entry |
| is a fact, finding, or procedure | **not here** — `ARCHITECTURE.md` or `docs/reference/` |

Shipped work lives in `CHANGELOG.md` and `PROGRESS.md`; feature descriptions of every status live in
`FEATURES.md`. Once something ships and has no open thread, delete it rather than leaving a status
block behind. Close items by ticking the box, not by rewriting them.

*Created 2026-09-08, against the initial scaffold with nothing yet installed.*

---

## Operating constraints

**Project status: BUILT, NEVER INSTALLED.** The repo has been complete since 2026-04-21 and
`./install.sh` has never been run on this machine. The predecessor ad-hoc scripts were doing the real
work until 2026-09-08, when their launch agent was unloaded.

- Nothing in this repo is currently running. No launch agent, no `~/.magicbar/`, no SwiftBar plugin.
- The predecessor install is **stopped but not removed** — its files are still on disk and its plist is
  still in `~/Library/LaunchAgents/`, so it returns at next login unless disabled. See `MIGRATION.md`.
- Installing magicbar before decommissioning the predecessor produces two menu bar icons and duplicate
  notifications. That is expected and documented, not a bug.

---

## NEXT SESSION

The three that matter, in order:

- [ ] **Decide: install magicbar, or keep it on the shelf.** Everything else is downstream of this.
      Running `./install.sh` also means working through `MIGRATION.md` to retire the predecessor.
- [ ] **Fix the blip cascade** before installing anything. It is the one bug that actively annoys the
      user, and it ships as-is today. See `ARCHITECTURE.md` § Known limitations.
- [ ] **Fix the `LAUNCHD_LABEL` installer break.** One-line fix, and the README currently tells people
      to do the thing that breaks it.

---

## Active

### Bugs

- [ ] **Blip cascade re-arms every threshold.** A one-point upward reading resets state to 101 and the
      ladder walks down again, one notification per tick. Reproduced 2026-09-08 on the predecessor
      script (identical logic): six notifications from a battery sitting still at 7%.
      *Next action:* require a rise of several points, or store the reading alongside the threshold, so
      Bluetooth noise cannot look like a recharge.
- [ ] **`LAUNCHD_LABEL` selects the template source path**, so changing it makes `install.sh` exit on a
      missing file. `README.md` invites the change.
      *Next action:* hardcode the template filename; substitute the label into the plist body only.
- [ ] **Device names hardcoded in user-facing strings.** Notification title and SwiftBar dropdown both
      say "Magic Mouse" whatever ProductID is configured.
      *Next action:* add a display-name constant to `config.sh` alongside the icon, or derive it.

### Features

- [ ] **Monitor the keyboard as well as the mouse** — the original point of the project, still unbuilt.
      Blocked on per-device state: `$STATE_FILE` holds one bare integer with no device identity.
      Design and tier in [`FEATURES.md`](./FEATURES.md) § Multi-device monitoring.
      *Next action:* decide the state file format before writing any consumer code.

### Docs & hygiene

- [ ] **`config.sh` calls ProductID 620 unverified.** It was verified on this machine 2026-09-08.
      *Next action:* correct the comment.
- [ ] **`MIGRATION.md` is gitignored**, so the decommissioning guide exists on one machine only.
      *Next action:* decide whether it is genuinely machine-specific or should be tracked.

---

## Watch list

Risks and numbers to re-check. No action yet.

- **Apple could change the IOKit schema.** Everything funnels through one `ioreg` key, so a change
  breaks both consumers at once. The single-library design means one place to fix; the tests would not
  catch it, because they run against a static mock rather than live hardware.
- **ProductIDs vary across peripheral generations.** 617 and 620 are verified on this machine only.
  Anyone else needs to run `ioreg` themselves.
- **`install.sh`, `uninstall.sh` and the notifier's threshold logic have no test coverage.** Only the
  plist parser is tested.
- **The rendered artifacts bake in an absolute path.** Moving the repo silently breaks a live install
  with no error surfaced anywhere the user would look.
