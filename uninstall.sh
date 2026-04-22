#!/bin/bash
# uninstall.sh — reverses install.sh. Removes the launchd agent and the
# SwiftBar plugin, and (with your confirmation) the state directory.
# Does NOT uninstall terminal-notifier or SwiftBar — you may rely on them
# for other tools — but prints the commands to do so yourself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

REMOVED=()

# --- 1. Unload + remove launchd plist ---
# Ignore unload errors (agent may not be loaded if install never succeeded
# or was partially rolled back).
PLIST_DEST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
if [[ -f "$PLIST_DEST" ]]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
    REMOVED+=("launchd agent: $PLIST_DEST")
fi

# --- 2. Remove SwiftBar plugin ---
PLUGIN_DEST="$SWIFTBAR_PLUGINS_DIR/magicbar.5m.sh"
if [[ -f "$PLUGIN_DEST" ]]; then
    rm -f "$PLUGIN_DEST"
    REMOVED+=("SwiftBar plugin: $PLUGIN_DEST")
fi

# --- 3. Optionally remove state dir ---
# The state dir contains the threshold state file + launchd log. Default
# is to keep it (user may want to inspect logs post-uninstall); confirm
# interactively before blowing it away.
if [[ -d "$HOME/.magicbar" ]]; then
    read -r -p "Remove $HOME/.magicbar (state + logs)? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.magicbar"
        REMOVED+=("state dir: $HOME/.magicbar")
    fi
fi

# --- 4. Report ---
if ((${#REMOVED[@]} == 0)); then
    echo "Nothing to remove. (Was magicbar ever installed?)"
else
    echo "Removed:"
    for item in "${REMOVED[@]}"; do
        echo "  • $item"
    done
fi

cat <<MSG

Note: terminal-notifier and SwiftBar are NOT uninstalled — remove them
yourself if you no longer want them:
  brew uninstall terminal-notifier
  brew uninstall --cask swiftbar
MSG
