# Estimate backtest — 2026-09-18

The first complete Magic Mouse run (41% → 4%, 2026-09-13 to 09-18, 42 readings) and the scripts
that scored candidate models against it. Kept so a later model is judged on the same baseline.

`run-2026-09-13-to-18.json` is the app's own saved `drainHistory`, exported read-only with
`defaults export com.dominic-lam.magicbar -`. Times are seconds since 2001-01-01 UTC.

Every script walks forward hour by hour, gives a model only the readings it would have had at
that moment, and scores its prediction of when each later level was reached.

```bash
cd docs/reference/estimate-backtest
python3 backtest.py  run-2026-09-13-to-18.json   # least squares, windows, time-of-day profiles
python3 naive.py     run-2026-09-13-to-18.json   # trailing-window and fixed rates
python3 android.py   run-2026-09-13-to-18.json   # Android-style step averaging, and the hours-of-use test
python3 analysis2.py run-2026-09-13-to-18.json   # per-day use, in-use gaps, how wide an honest range is
```

`naive.py`, `android.py` and `analysis2.py` load their shared helpers from `backtest.py`, so the
four files must stay in one directory under these names. Findings: `docs/claude/ARCHITECTURE.md`,
"What the first real run showed".

## Second run — 2026-10-07

`history-2026-10-07.json` is the whole saved `drainHistory` on 2026-10-07, same export: the mouse's
first run and its second (100% → 4%, 2026-09-18 to 10-07, no top-up), both full charges, and the
keyboard's 56% → 11%. These scripts stand alone and each takes that file:

```bash
python3 run2-replay.py       history-2026-10-07.json  # per-day use, bands, the shipped rules replayed hourly
python3 run2-alternatives.py history-2026-10-07.json  # the shipped clock rule against three simple alternatives
python3 run2-score.py        history-2026-10-07.json  # the second charge, "half below 10%", and the keyboard
```

Findings: `docs/claude/ARCHITECTURE.md`, "What the second run showed" and "The charge estimate".
