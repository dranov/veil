# Maintainer tooling and validation

The default build checks Veil and its test library. CI additionally runs the
Python profiling-tool regressions, the widget source-watch integration test,
and two explicitly selected examples:

```sh
lake build Examples.Tutorial.POPL26.RingFin Examples.Puzzles.DieHard
```

RingFin exercises finite concrete checking with explicit theory data. DieHard is
a finite reachable water-jug puzzle whose intentional counterexample is logged
as information. The complete `Examples` target is intentionally not a fast CI
gate: examples include large searches, compiled runs, and deliberately faulty
specifications. Select those individually with an explicit resource contract.

`lake script run perftest` enforces each `.timeout` file and returns nonzero on a
failure or timeout. Missing timeout files use the existing 120-second fallback;
malformed or zero budgets are errors. The runner now awaits/reaps each child and
records the actual exit result. CI runs it explicitly on Linux as an **advisory**
step and retains `perftest.log` for 14 days. Functional tests remain mandatory.
No performance budget has been increased or disabled.

## Current performance baseline

A shared development environment on 2026-09-09 produced:

| Test | Existing budget | Observation |
| --- | --- | --- |
| NOPaxosKernelDefEq | 25 s | Pass, 15 s |
| PickPerf | 10 s | Timeout at 10 s; unprofiled standalone run completes in 18.0 s |
| SuzukiKasamiKernelDefEq | 15 s | Pass, 6 s |

The PickPerf profile reported 17.4 s inclusive frontend time and 23.3 s summed
sampled self time across threads. Compiler work accounted for about 5.1 s,
model-check elaboration 5.9 s inclusive, and extraction 3.4 s inclusive. These
numbers overlap and must not be added. Its four concrete runs explored only
4, 27, 16 and 2 states: the recorded cost is compilation/elaboration, not a large
reachable-state search. Profiling adds overhead and the host is shared; these
observations are diagnostic evidence, not newly calibrated release thresholds.
Reducing that overhead and calibrating budgets on controlled hardware remain
follow-up work. Do not turn the advisory job into a required gate by simply
raising the existing limit.

See [profiling instructions](../../scripts/README-profiling.md) for exact-name
JSON reports, portable runners, output schemas and optional plotting dependencies.

## Integration notes

The separate contributor-guidance branch describes the old main behavior. After
integration, update its short notes about watchers and CI performance coverage;
its documented absent-budget fallback remains 120 seconds. The separate widget
results branch has its own behavior tests and extracts protocol/diff code: retain
those tests alongside `npm run test:watch`, and combine both branches' TypeScript
cleanup. The watcher uses the same four existing widget entry points; helpers are
bundled by imports rather than emitted as extra standalone widgets.

The generated compiled-checker project and the core/widget dependency boundary
still need integration with their separately owned architecture/compiler streams.
This branch does not claim a new independently validated core-only build mode or
a verified container image. The obsolete archive-dependent Docker recipe was
retired; native instructions use the pinned repository Lean toolchain.
