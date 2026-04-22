#!/bin/bash
# install.sh — idempotent installer for magicbar.
# Installs dependencies, renders templated configs with the local repo path,
# loads the launchd agent, and copies the SwiftBar plugin into place.
# Every step skips-if-present or overwrites, so re-running is safe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR"

# shellcheck source=config.sh
source "$INSTALL_DIR/config.sh"

# --- 1. Preflight: macOS + required tools ---
# Fail fast with clear messages if the environment can't support us.
if [[ "$(uname)" != "Darwin" ]]; then
    echo "error: magicbar only runs on macOS (Darwin). Detected: $(uname)" >&2
    exit 1
fi

if ! command -v brew &>/dev/null; then
    echo "error: Homebrew is required. Install from https://brew.sh and re-run." >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "error: python3 is required (ships with macOS Command Line Tools)." >&2
    echo "       Run: xcode-select --install" >&2
    exit 1
fi

echo "→ Preflight OK (macOS, brew, python3)"

# --- 2. Install terminal-notifier (skip if already installed) ---
# terminal-notifier is what delivers our launchd-fired notifications;
# osascript from launchd is silently dropped on modern macOS.
if brew list terminal-notifier &>/dev/null; then
    echo "→ terminal-notifier already installed"
else
    echo "→ Installing terminal-notifier…"
    brew install terminal-notifier
fi

# --- 3. Install SwiftBar (skip if already installed) ---
if brew list --cask swiftbar &>/dev/null; then
    echo "→ SwiftBar already installed"
else
    echo "→ Installing SwiftBar…"
    brew install --cask swiftbar
fi

# --- 4. State directory ---
# Holds the threshold state file and launchd logs. mkdir -p is idempotent.
mkdir -p "$HOME/.magicbar"
echo "→ State dir ready: $HOME/.magicbar"

# --- 5. Render launchd plist from template ---
# sed substitutes the three placeholders and writes directly to the
# LaunchAgents directory. Overwriting is intentional — pick up any changes
# to the template on re-install.
PLIST_TEMPLATE="$INSTALL_DIR/launchd/${LAUNCHD_LABEL}.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

mkdir -p "$HOME/Library/LaunchAgents"
sed \
    -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" \
    -e "s|{{LAUNCHD_LABEL}}|$LAUNCHD_LABEL|g" \
    -e "s|{{HOME}}|$HOME|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"
echo "→ Rendered launchd plist: $PLIST_DEST"

# --- 6. (Re)load launchd agent ---
# Unload first so a second run picks up changes to the plist; ignore errors
# if it wasn't previously loaded. Then load the freshly rendered copy.
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"
echo "→ launchd agent loaded ($LAUNCHD_LABEL)"

# --- 7. Render + install SwiftBar plugin ---
# The plugin template references {{INSTALL_DIR}} so it can source config.sh
# and lib/read_battery.sh from the repo at runtime. sed + chmod +x, done.
mkdir -p "$SWIFTBAR_PLUGINS_DIR"
PLUGIN_TEMPLATE="$INSTALL_DIR/swiftbar/magicbar.5m.sh.template"
PLUGIN_DEST="$SWIFTBAR_PLUGINS_DIR/magicbar.5m.sh"

sed -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" "$PLUGIN_TEMPLATE" > "$PLUGIN_DEST"
chmod +x "$PLUGIN_DEST"
echo "→ SwiftBar plugin installed: $PLUGIN_DEST"

# --- 8. Next steps ---
cat <<MSG

✓ magicbar installed.

Next steps:
  1. Open SwiftBar (already running? menu bar icon → Refresh All).
  2. Manually verify the notifier: bash $INSTALL_DIR/bin/battery_alert.sh
  3. Tail logs if anything looks off: tail -f ~/.magicbar/launchd.log

To uninstall: $INSTALL_DIR/uninstall.sh
MSG
