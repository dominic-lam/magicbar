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

- Build **Release** with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` or notifications will never
  work. A Debug build is debuggable and macOS refuses it authorization.
- Install to `/Applications`, never run from the build directory. The login item registration
  binds to the launch path.
- The predecessor ad-hoc scripts are still on disk in `~/bin` and `~/SwiftBar` with their
  launch agent unloaded but its plist still present, so they return at next login. See
  `MIGRATION.md`.

---

## NEXT SESSION

- [ ] **Decode `BatteryStatusFlags` by plugging a device in.** Charging display is built and
      works against simulated input, but the real flag has only ever been observed as 0. The
      code treats any non-zero value as charging, which is a guess.
      *Next action:* plug the mouse in, then `log show --predicate 'eventMessage CONTAINS
      "BatteryStatusFlags"'`.
- [ ] **Set the alert style to *Alerts* rather than *Banners*** in System Settings, so a
      low-battery warning stays on screen instead of vanishing after five seconds. Cannot be
      set programmatically.
- [ ] **Retire the predecessor scripts** per `MIGRATION.md`, after a reboot confirms magicbar
      starts itself.

## Active

### Bugs

Nothing known.

### Features

- [ ] **Keep a vanished device visible** with its last known level and a timestamp, rather than
      dropping it from the popover. A sleeping mouse currently looks like a missing one.
      *Next action:* decide how stale is too stale to show.

### Docs & hygiene

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
