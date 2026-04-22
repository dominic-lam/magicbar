#!/bin/bash
# bin/battery_alert.sh — fires a threshold-based macOS notification when
# the monitored device's battery drops into a new, lower band. Invoked by
# launchd on a StartInterval schedule; does nothing if nothing changed.
#
# State: $STATE_FILE stores the last threshold we notified at. The script
# only re-fires when the battery has crossed a *new* lower threshold, or
# after the battery has been recharged above the last-notified level.

set -euo pipefail

# launchd gives us a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin), which
# doesn't include Homebrew. Prepend both possible brew prefixes so
# terminal-notifier resolves on Apple Silicon and Intel alike.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Resolve repo root from this file's own location, so the script works
# regardless of how it's invoked (launchd, `bash bin/battery_alert.sh`,
# or an absolute path).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../config.sh
source "$REPO_ROOT/config.sh"
# shellcheck source=../lib/read_battery.sh
source "$REPO_ROOT/lib/read_battery.sh"

# Ensure the state dir exists — first run, or a user who cleaned ~/.magicbar.
mkdir -p "$(dirname "$STATE_FILE")"

# --- Read battery ---
# Silent exit if the device is asleep/disconnected: nothing to notify about,
# and we don't want to reset or mutate state in that case.
BATTERY=$(read_battery_percent "$MENU_BAR_DEVICE_PRODUCT_ID" || true)
[[ -z "${BATTERY:-}" ]] && exit 0

# --- Load last-notified threshold (default 101 = "nothing notified yet") ---
if [[ -f "$STATE_FILE" ]]; then
    LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 101)
else
    LAST=101
fi
# Guard against a corrupted/empty state file.
[[ "$LAST" =~ ^[0-9]+$ ]] || LAST=101

# --- Recharge detection ---
# If the current battery is higher than the threshold we last notified at,
# the user has recharged / swapped batteries. Reset LAST so the next drain
# re-arms every threshold from the top.
if (( BATTERY > LAST )); then
    LAST=101
    echo 101 > "$STATE_FILE"
fi

# --- Threshold walk ---
# Fire on the first T (highest in the descending list) where:
#   (a) BATTERY ≤ T  — we've crossed it
#   (b) T < LAST     — we haven't already notified at this level
# Break after the first hit → at most one notification per invocation.
for T in "${NOTIFICATION_THRESHOLDS[@]}"; do
    if (( BATTERY <= T )) && (( T < LAST )); then
        # terminal-notifier ships its own app bundle, so macOS actually
        # delivers the notification when launchd fires it. osascript from
        # launchd is silently dropped on recent macOS versions.
        terminal-notifier \
            -title "🖱️ Magic Mouse Low" \
            -message "Battery at ${BATTERY}%" \
            -sound Submarine
        echo "$T" > "$STATE_FILE"
        break
    fi
done

exit 0
