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

---

## NEXT SESSION

- [ ] **Promote `v1.2.0-rc.1` to `v1.2.0`** once the daily reminder has fired at least once and
      the drain estimate has produced a real number. The pipeline itself is proven: the rc was
      published 2026-09-10, downloaded, and verified — checksum matches, signature survives the
      round trip, version reads from the tag, no `get-task-allow`, and the binary runs. What is
      not proven is the app inside it, which is the only reason this is still a candidate.
- [ ] **Confirm the daily reminder fires, and carries the estimate.** Set the hour to the next
      one with a device below the warn level. It has never run. The estimate will read as
      absent until the history is a few days old, which is expected, not a fault.
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
- [ ] **Watch the drain estimate against reality.** Shipped 2026-09-09 and verified only
      against synthetic series. In a week, compare what `--dump-estimate` says to what actually
      happened. *Next action:* re-read it around 2026-09-16.
- [ ] **Snooze on the notification.** Raised by all four, but partly answered: unticking the 1%
      rule is now a standing "stop nagging me". A per-occasion snooze is still missing.
      *Next action:* decide whether the standing setting is enough.

- [ ] **The daily reminder is now the only reminder tied to a moment.** The sleep reminder was
      removed on 2026-09-09 — nothing can be delivered as the Mac sleeps, and wake is when a
      Magic Mouse cannot be charged. That puts more weight on the daily hour being right.
      *Next action:* pick an hour that is actually before the user stops for the night.

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
