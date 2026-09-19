#!/bin/bash
# One-off: load the 4% -> 50% charge readings of 2026-09-18 into magicbar's saved history.
#
# The app only began recording charges at 50% that day; the earlier half was recovered from the
# system log into charge-curve-2026-09-18.txt. Without it, the next charge estimate prices every
# level below 50% at the overall median (about 3 min) when the truth was about 1.55.
#
# Quits the app, backs its preferences up beside the original, rewrites one key, reads it back
# byte for byte, relaunches. Run from the repo root:  bash docs/reference/backfill-charge-2026-09-18.sh
set -euo pipefail
BID=com.dominic-lam.magicbar
ID=bc-89-a7-e3-b9-51
CURVE="$(cd "$(dirname "$0")" && pwd)/charge-curve-2026-09-18.txt"
WORK="$(mktemp -d)"
BACKUP="$HOME/Library/Preferences/$BID.backup-2026-09-18.plist"

pkill -f "MacOS/magicbar( |$)" || true
sleep 2
defaults export "$BID" "$BACKUP"
echo "backup: $BACKUP"
defaults export "$BID" - | plutil -extract drainHistory raw -o - - | base64 -d > "$WORK/before.json"

python3 - "$WORK" "$CURVE" "$ID" <<'EOF'
import json, sys, datetime
work, curve, dev = sys.argv[1:4]
E = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)
d = json.load(open(f"{work}/before.json"))
run = d["charges"][dev][-1]
if run[0]["percent"] < 50:
    sys.exit("already backfilled — nothing to do")
early = []
for line in open(curve):
    if line.startswith("#"): continue
    date, time, pct = line.split(); pct = int(pct.rstrip("%"))
    if pct >= 50: break
    at = (datetime.datetime.fromisoformat(f"{date} {time}").astimezone() - E).total_seconds()
    early.append({"at": at, "percent": pct})
# first moment 50% was read, from the system log; the app's own 50% row was its launch
early.append({"at": (datetime.datetime.fromisoformat("2026-09-18 15:20:58.146").astimezone() - E).total_seconds(), "percent": 50})
assert [s["percent"] for s in early] == list(range(4, 51)), "levels not contiguous"
assert run[0]["percent"] == 50 and run[1]["percent"] == 51, "unexpected start of the recorded run"
merged = early + run[1:]
assert all(a["at"] < b["at"] for a, b in zip(merged, merged[1:])), "times out of order"
d["charges"][dev][-1] = merged
raw = json.dumps(d, separators=(",", ":")).encode()
open(f"{work}/after.json", "wb").write(raw)
open(f"{work}/after.hex", "w").write(raw.hex())
print(f"charge samples: {len(run)} -> {len(merged)}; drain segments untouched: {[len(s) for s in d['segments'][dev]]}")
EOF

defaults write "$BID" drainHistory -data "$(cat "$WORK/after.hex")"
defaults export "$BID" - | plutil -extract drainHistory raw -o - - | base64 -d | cmp - "$WORK/after.json"
echo "written and read back identical"
open /Applications/magicbar.app
echo "relaunched. To undo: quit magicbar, then  defaults import $BID \"$BACKUP\""
