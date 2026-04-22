#!/bin/bash
# tests/test_read_battery.sh — exercises parse_battery_percent against a
# hand-crafted mock plist. Pure bash, no framework dependency.
# Run with:
#   bash tests/test_read_battery.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/read_battery.sh
source "$REPO_ROOT/lib/read_battery.sh"

FAIL=0

# --- Tiny assertion helper. Keeps output compact; sets FAIL=1 on miss. ---
assert_eq() {
    local got="$1" want="$2" name="$3"
    if [[ "$got" == "$want" ]]; then
        echo "  ok   $name"
    else
        echo "  FAIL $name — want='$want' got='$got'"
        FAIL=1
    fi
}

# --- Mock plist covering three devices with distinct ProductIDs. ---
# Shape matches what `ioreg -r -k BatteryPercent -a` emits: an <array> of
# <dict>s, each with at least ProductID and BatteryPercent.
MOCK_PLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>ProductID</key><integer>617</integer>
        <key>BatteryPercent</key><integer>42</integer>
    </dict>
    <dict>
        <key>ProductID</key><integer>620</integer>
        <key>BatteryPercent</key><integer>88</integer>
    </dict>
    <dict>
        <key>ProductID</key><integer>999</integer>
        <key>BatteryPercent</key><integer>5</integer>
    </dict>
</array>
</plist>'

echo "test_read_battery.sh"

# Test 1: matching ProductID returns its BatteryPercent.
GOT=$(echo "$MOCK_PLIST" | parse_battery_percent 617)
assert_eq "$GOT" "42" "ProductID 617 → 42"

# Test 2: a different matching ProductID returns its percentage.
GOT=$(echo "$MOCK_PLIST" | parse_battery_percent 620)
assert_eq "$GOT" "88" "ProductID 620 → 88"

# Test 3: non-matching ProductID exits 1 with empty stdout.
# We temporarily disable `set -e` to capture the non-zero exit code
# without aborting the test script.
set +e
GOT=$(echo "$MOCK_PLIST" | parse_battery_percent 12345)
RC=$?
set -e
assert_eq "$GOT" "" "unknown ProductID → empty stdout"
assert_eq "$RC" "1" "unknown ProductID → exit 1"

# Test 4: malformed plist exits 1 silently (no stderr, no crash).
set +e
GOT=$(echo "not a plist" | parse_battery_percent 617)
RC=$?
set -e
assert_eq "$GOT" "" "malformed plist → empty stdout"
assert_eq "$RC" "1" "malformed plist → exit 1"

if (( FAIL )); then
    echo "FAILED"
    exit 1
else
    echo "PASSED"
fi
