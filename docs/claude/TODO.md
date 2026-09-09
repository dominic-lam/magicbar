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

- [ ] **Allow notifications in System Settings › Notifications › magicbar.** The app is denied
      and cannot fix that itself. Everything else about notifications is verified; this is the
      last step between the app and working alerts. Set the style to *Alerts* rather than
      *Banners* while there, so a warning persists instead of vanishing.
- [ ] **Confirm a real notification is delivered** once allowed:
      `open /Applications/magicbar.app --args --simulate "617:9"` then drop to 8 and watch for
      a banner. The decision logic is verified; only delivery is not.
- [ ] **Retire the predecessor scripts** per `MIGRATION.md`, after a reboot confirms magicbar
      starts itself.

## Active

### Bugs

Nothing known.

### Features

- [ ] **Suppress alerts while a device is charging.** `BatteryStatusFlags` reads 0 for both
      devices and its meaning is undecoded, so a mouse on a cable would still be nagged.
      *Next action:* plug a device in, re-read the flag, compare.
- [ ] **Keep a vanished device visible** with its last known level and a timestamp, rather than
      dropping it from the popover. A sleeping mouse currently looks like a missing one.
      *Next action:* decide how stale is too stale to show.

### Docs & hygiene

- [ ] **`MIGRATION.md` is gitignored**, so the decommissioning guide exists on one machine only.
      *Next action:* decide whether that is still right now that it covers the predecessor only.
- [ ] **No app icon.** `Assets.xcassets/AppIcon.appiconset` is empty, so the app has the generic
      icon. Range's `scripts/render-icon.swift` draws a battery with Core Graphics and takes
      fill colours as arguments — adapt rather than start from scratch.

---

## Watch list

- **A notification refusal is close to permanent.** It is recorded per bundle ID in `ncprefs`,
  never re-prompted, and has no reset command. Changing the bundle ID would be the only clean
  escape, and would cost the current registration.
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
