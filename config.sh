#!/bin/bash
# magicbar — user-editable constants.
# Sourced by install.sh, bin/battery_alert.sh, and the SwiftBar plugin.
# This file is intentionally NOT executed directly — it's a sourced config.

# --- Device ProductIDs ---
# Magic Mouse 2/3 is 617 (verified). Other peripheral IDs vary across
# generations — the values below are illustrative/unverified. Find your
# own peripheral's ProductID with:
#   ioreg -r -k BatteryPercent -a
MAGIC_MOUSE_PRODUCT_ID=617
MAGIC_KEYBOARD_PRODUCT_ID=620  # unverified; run ioreg to find your own PID

# --- Menu bar display ---
# Only one device is shown in the menu bar for v1. To swap targets, change
# the two values below (e.g. to point at the Magic Keyboard instead).
MENU_BAR_DEVICE_PRODUCT_ID=$MAGIC_MOUSE_PRODUCT_ID
MENU_BAR_DEVICE_ICON="🖱️"

# --- Notification thresholds (descending) ---
# The launchd notifier fires when the battery drops ≤ each threshold, at
# most once per threshold until the battery is recharged above it.
NOTIFICATION_THRESHOLDS=(20 15 10 9 8 7 6 5 4 3 2 1)

# --- Paths ---
STATE_FILE="$HOME/.magicbar/state"
SWIFTBAR_PLUGINS_DIR="${SWIFTBAR_PLUGINS_DIR:-$HOME/SwiftBar}"
LAUNCHD_LABEL="com.dominiclam.magicbar"
