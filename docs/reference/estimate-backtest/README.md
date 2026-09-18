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
