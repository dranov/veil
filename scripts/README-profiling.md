# Profiling

Build dependencies first with `lake build`. Python 3 runs the profilers and
parsers without `bc` or GNU `date`. The shell entry points retain their argument
order and work from the repository root:

```sh
./scripts/profile-file.sh Examples/Tutorial/POPL26/RingDec.lean
./scripts/profile-file.sh --quiet MyFile.lean profiles/my-file.json
./scripts/profile-folder.sh Examples/Tutorial profiles/tutorial --exclude veil.perf.discharger
python3 scripts/parse-profile.py profiles/my-file.json --json > profiles/timing.json
```

Outputs default to `profiles/`. Folder runs retain the source directory layout,
so paths containing spaces/commas and `a_b.lean` versus `a/b.lean` remain distinct.
Dependency/build directories (`.lake`, `.git`, `.veil.tmp`, `node_modules`) are
excluded. A failed compiler or malformed/missing profile returns nonzero; an
interrupt returns 130 and retains completed reports and individual logs. Stale
profiles are removed before a run.

`summary.json` records per-file status, monotonic wall time, sampled CPU time,
profile paths and log paths. `summary.csv` quotes filenames correctly.
`profiles.json` lists successfully decoded profiles. `timing.json` contains full
function identifiers; `timing.txt` is only a human-readable, truncated table.
Trend plots should consume the structured JSON, not scrape the table. On
Debian/Ubuntu, install `python3-venv` before creating the optional environment:

```sh
python3 -m venv .venv-profiling
. .venv-profiling/bin/activate
python3 -m pip install -r scripts/requirements-profiling.txt
python3 scripts/plot-profile-trend.py profiles/old/timing.json profiles/new/timing.json --output profiles/trend.png
```

Inclusive totals overlap across nested functions; summing them is not total CPU
time. Self time belongs to the original sample leaf, even when a filter hides
that leaf. Plotting needs the optional matplotlib/numpy dependencies; parsing
and running profiles use only the standard library.

Run tool regressions with `python3 -m unittest discover -s scripts/tests -v`.
