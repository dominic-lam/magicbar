# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# magicbar — Claude Code Session Reference

Quick-start guide for Claude Code sessions on this project.

---

## What This Project Is

**magicbar** reads Apple peripheral battery levels out of the macOS IOKit registry and surfaces them
two ways: a **SwiftBar menu bar percentage**, and a **launchd-scheduled notifier** that fires a macOS
notification when the battery crosses a threshold. Pure bash plus a small embedded Python parser.
No build step, no dependencies beyond Homebrew packages the installer fetches.

It replaces a set of hand-written scripts that lived loose in `~/bin` and `~/SwiftBar`. Those are
documented in `MIGRATION.md`.

**Status: built, never installed.** Complete since 2026-04-21, untouched for four months. Nothing from
this repo is currently running on this machine.

**GitHub:** https://github.com/dominic-lam/magicbar

---

## Documentation Structure

- **docs/claude/ARCHITECTURE.md** — Core tech: the IOKit read, the shared library, install-time
  template rendering, the notifier state machine, coding conventions, known limitations
- **docs/claude/ROADMAP.md** — Thin sequencing page: phases, now / next / later. No feature descriptions.
- **docs/claude/FEATURES.md** — Feature catalogue by status (Shipped / Committed / Idea / Blocked /
  Declined). New ideas go here, not TODO.
- **docs/claude/TODO.md** — Open work only: NEXT SESSION, Active, Watch list. No idea backlog.
- **docs/claude/PROGRESS.md** — Session log and navigation index
- **docs/claude/day-plans/** — Per-day plans from `/day-open`, with the reflection from `/day-close`
- **docs/claude/debriefs/** — Longer write-ups of a single piece of work
- **docs/reference/PROJECT_BRIEF.md** — Fast snapshot: runtime flow, key files, gotchas, current status
- **docs/archive/** — Retired progress files, testing guides, audits
- **README.md** — User-facing docs (install, configure, troubleshoot)
- **CHANGELOG.md** — User-facing version history
- **MIGRATION.md** — Decommissioning the predecessor ad-hoc install. **Gitignored** — this machine only.

**Read these first** when starting a session: `TODO.md`, then `docs/reference/PROJECT_BRIEF.md`.

---

## How We Work Together

### Session Start Protocol
1. Read **docs/claude/TODO.md** for current work items
2. Read **docs/reference/PROJECT_BRIEF.md** for a technical snapshot
3. Read **docs/claude/ARCHITECTURE.md** if touching the battery read, the state machine, or the installer
4. Read **docs/claude/PROGRESS.md** if continuing previous work
5. Ask clarifying questions if scope is unclear

### Session End Protocol
1. Update **docs/claude/TODO.md** — tick completed boxes, add discoveries, prune finished items. A newly
   surfaced feature *idea* goes to **FEATURES.md** as an Idea entry, not to TODO.
2. Append to **docs/claude/PROGRESS.md** Session Log, three-line format:
   ```
   ## YYYY-MM-DD (Session N — Title)
   **Completed:** one sentence on what shipped
   **In progress:** what's unfinished, or "Nothing"
   **Next session should:** the single most important pickup — one specific, actionable line
   ```
   Update **CHANGELOG.md** if anything user-facing changed.
   Archive the oldest 10 entries when the Session Log exceeds 15 → `docs/archive/progress/`.
3. Update **docs/claude/ARCHITECTURE.md** if the tech or file structure changed
4. Update **docs/claude/FEATURES.md** if a feature changed status; update **ROADMAP.md** only if
   sequencing changed
5. **Write every doc as of the moment *after* the wrap's own commit.** The wrap commits the docs it just
   wrote, so "commit X" is never a NEXT SESSION item, and "uncommitted" or "not pushed" is never written
   about work the same wrap is about to commit. A git-state claim that must survive in a doc carries a
   hash or a date, never a bare "not pushed" — those go stale silently. Before staging, grep the edited
   docs for `uncommitted|not committed|not pushed` and fix every hit the commit is about to falsify.

### Code Quality Standards
- **No over-engineering:** only what is requested or clearly necessary. This is a few hundred lines of
  bash and should stay that way.
- **Simple > clever:** three similar lines beat a premature abstraction.
- **Delete, don't comment out:** no `# removed` blocks or `_unused` renames.
- **Quote everything.** Unquoted expansions in bash are a bug waiting for a path with a space.
- **Keep the parser pure.** `parse_battery_percent` reads stdin and touches no hardware. That is what
  makes it testable — do not let an `ioreg` call leak into it.

### Git & Deployment
- Only commit when explicitly requested
- Never use destructive git commands unless explicitly requested
- Commit messages: concise, focused on "why" not "what"
- Always add a `Co-Authored-By:` trailer naming **the model actually writing the commit**. Do not pin a
  model name in this rule — it goes stale every time the model changes.

### Mentorship & Learning
**Context:** the user does not have formal software development experience and may not know industry
practice.

**Your role:** act as a senior developer mentor. Teach proactively when there is a real teachable moment
— trade-offs, anti-patterns, the "why" behind a recommendation, not just the "what". Be concise, use
examples from this project, present options with trade-offs rather than one right answer.

---

## Claude Code Session Rules

### Tool Usage
- Use dedicated tools over Bash where one fits: `Read` over `cat`, `Edit` over `sed`, `Glob` over
  `find`, `Grep` over `grep`
- Call independent tools in parallel; wait when calls are dependent

### Single vs Multi-Agent Guidance
- **Single-agent (you):** direct edits, quick fixes, doc updates, searches of one to three queries.
  This repo is small enough that this is almost always right.
- **Task tool with `subagent_type=Explore`:** broad exploration across many files. Rarely needed here.

### Communication Style
- Short and concise
- Reference code as `file_path:line_number`
- No emojis unless requested

---

## Key Technical Context

### Tech Stack
Bash, plus `python3` (`plistlib`) for parsing. `ioreg` for the registry read. `launchd` for scheduling,
`terminal-notifier` for notifications, SwiftBar for the menu bar. Homebrew installs the last two.

### Critical Architecture Points

**One library, two consumers.** `lib/read_battery.sh` is the only place that knows how to read a
battery. `bin/battery_alert.sh` and the SwiftBar plugin both source it and do not know about each
other — removing one leaves the other working.

**The parser is split from the I/O on purpose.** `parse_battery_percent` takes a plist on stdin;
`read_battery_percent` wraps `ioreg | parse`. Only the first is tested, and only because it is pure.

**The library is sourced, not executed,** and deliberately omits `set -euo pipefail` — the caller owns
its error discipline. Both consumers set it themselves and call the library with `|| true`, because a
missing device is expected rather than exceptional.

**Templates are rendered at install time with this repo's absolute path baked in.** `install.sh` `sed`s
`{{INSTALL_DIR}}`, `{{LAUNCHD_LABEL}}` and `{{HOME}}` into the plist and the plugin. **Moving or
renaming this repo silently breaks a live install** — the rendered copies keep pointing at the old
location, and nothing surfaces an error. Re-run `./install.sh` after any move, and after any
`config.sh` edit.

**The notifier stores the threshold it last fired at, not the battery reading.** The two coincide below
10% only, because every integer there is its own threshold. A drop straight to 14% stores 20.

**launchd's environment excludes Homebrew,** so the notifier prepends both brew prefixes to `PATH`
itself. **`terminal-notifier` is load-bearing** — osascript notifications fired from launchd have no
owning app bundle and are dropped silently on modern macOS. Do not "simplify" either away.

### File Overview

```
config.sh                    every user-editable constant; sourced, never executed
lib/read_battery.sh          the only battery read; parse (testable) + wrapper
bin/battery_alert.sh         launchd notifier, threshold state machine
swiftbar/*.sh.template       menu bar plugin, rendered at install
launchd/*.plist.template     agent definition, rendered at install
install.sh / uninstall.sh    idempotent install; uninstall prompts before deleting state
tests/                       the whole suite: parser vs a mock plist
```

---

## Common Tasks Quick Reference

```bash
bash tests/test_read_battery.sh   # whole suite, no framework, no single-test flag
./install.sh                      # idempotent; also the way to apply a config.sh change
./uninstall.sh                    # removes agent + plugin; prompts before state
bash bin/battery_alert.sh         # force one notifier run
tail -f ~/.magicbar/launchd.log   # runtime log; stdout and stderr both land here
launchctl list | grep magicbar    # is the agent loaded?
ioreg -r -k BatteryPercent -a     # ground truth for ProductIDs
```

### Adding support for a new device
1. Find its ProductID with `ioreg -r -k BatteryPercent -a`
2. Add the constant to `config.sh`
3. **Read `FEATURES.md` § Multi-device monitoring first** — per-device state does not exist yet, and
   `$STATE_FILE` is a single bare integer. This is not a one-liner.

### Changing notification frequency
Edit `NOTIFICATION_THRESHOLDS` in `config.sh`, then re-run `./install.sh`.

### Running one test
There is no flag for it. Comment out the other cases in `tests/test_read_battery.sh`.

---

## Current State (2026-09-08)

Built, never installed, four known defects open.

The predecessor ad-hoc scripts were **stopped** on 2026-09-08 — their launch agent was unloaded, but
their files remain on disk and their plist is still in `~/Library/LaunchAgents/`, so they return at
next login unless disabled. Nothing is monitoring any battery right now.

Before installing, read `TODO.md` § NEXT SESSION. Two of the four defects affect anyone who installs
today, and installing on top of the predecessor produces duplicate notifications until `MIGRATION.md`
is worked through.

Test suite last run 2026-09-08: 6 assertions, all passing.
