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
**No release exists** — no signed build, no notarisation, no cask. Installing means building from
source, which is the first wall both user reviewers hit.

- Build **Release** with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` or notifications will never
  work. A Debug build is debuggable and macOS refuses it authorization.
- Install to `/Applications`, never run from the build directory. The login item registration
  binds to the launch path.
- The predecessor ad-hoc scripts are still on disk in `~/bin` and `~/SwiftBar` with their
  launch agent unloaded but its plist still present, so they return at next login. See
  `MIGRATION.md`.

---

## NEXT SESSION

- [ ] **Decide how to release this.** Both user reviewers hit the same first wall: the install
      is a wall of Terminal commands and there is no signed build. The open questions are
      whether it is distributed at all, and if so whether that means a notarised build, a
      Homebrew cask, or just a drag-to-Applications zip. Everything else in this file is
      smaller than that decision.
- [ ] **Confirm the two new reminders actually fire.** Sleep the Mac with a device below the
      warn level, and set the daily hour to the next one. Both are wired and neither has ever
      run. *(User is testing over the next few days — 2026-09-09.)*
- [ ] **Retire the predecessor scripts** per `MIGRATION.md`, once a reboot confirms magicbar
      starts itself.

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
- [ ] **A drain estimate — "about three days left".** Both user reviewers asked for it and it is
      what makes the daily reminder able to say something useful rather than repeat a number.
      Needs history, but a thirty-day ring buffer in a plist is enough.
      *Next action:* decide the sampling rate and where it lives.
- [ ] **Snooze on the notification.** Raised by all four, but partly answered: unticking the 1%
      rule is now a standing "stop nagging me". A per-occasion snooze is still missing.
      *Next action:* decide whether the standing setting is enough.

## Previously active

### Bugs

Nothing known.

### Features

- [ ] **Keep a vanished device visible** with its last known level and a timestamp, rather than
      dropping it from the popover. A sleeping mouse currently looks like a missing one.
      *Next action:* decide how stale is too stale to show.

### Docs & hygiene

- [ ] **Nothing in the repo shows what the app looks like.** The README describes three menu
      bar states in prose and a reader deciding whether to build from source cannot see any of
      them. `docs/review-shots/` holds nine, but they were taken for the 2026-09-08 review and
      the popover has been rebuilt since, so they show settings that no longer exist.
      *Next action:* retake the idle glyph, a low-battery label and the popover, and embed them
      under "What it does".
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
