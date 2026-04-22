#!/bin/bash
# lib/read_battery.sh — shared battery-read library.
#
# Exposes two functions so the parsing logic is testable without calling
# into the live IOKit registry:
#
#   parse_battery_percent <product_id>
#       Reads an XML plist from stdin, prints BatteryPercent for the first
#       device whose ProductID matches. Exit 0 on success (prints integer),
#       exit 1 on no match / malformed input. No stderr output.
#
#   read_battery_percent <product_id>
#       Wraps `ioreg -r -k BatteryPercent -a | parse_battery_percent`.
#       What real consumers call. Same exit semantics.
#
# This file is sourced, not executed — no `set -e` here; the caller decides.

# --- parse_battery_percent <product_id> ---
# Delegates to python3 + plistlib. The python script reads ALL of stdin, so
# large plists are fine; it fails silently (exit 1) on any exception so the
# callers can render "device not found" rather than erroring out.
parse_battery_percent() {
    local product_id="$1"
    /usr/bin/python3 -c '
import sys, plistlib
target = int(sys.argv[1])
try:
    data = plistlib.loads(sys.stdin.buffer.read())
    # ioreg -r -a normally returns a list of device dicts, but a single
    # match can come through as a bare dict — normalize to a list.
    if isinstance(data, dict):
        data = [data]
    for dev in (data or []):
        if dev.get("ProductID") == target:
            pct = dev.get("BatteryPercent")
            if pct is not None:
                print(int(pct))
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
' "$product_id" 2>/dev/null
}

# --- read_battery_percent <product_id> ---
# Real-world entry point. ioreg's stderr is silenced because Bluetooth
# churn (disconnects, pairing events) can leak warnings that would spam
# the launchd log for no useful reason.
read_battery_percent() {
    local product_id="$1"
    ioreg -r -k BatteryPercent -a 2>/dev/null | parse_battery_percent "$product_id"
}
