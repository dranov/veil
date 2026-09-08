# Contributing to Veil

Veil implements a Lean DSL, verification tools, and infoview widgets for
transition systems. Start with the [README](README.md) for setup and the
[DSL reference](docs/DSL-Reference.md) for language behavior. The
[tutorials](Examples/Tutorial) provide specifications that exercise the public
interface.

## Set up the checkout

Install elan and Node.js/npm as described in the README. Run commands from the
repository root unless a different directory is shown. Elan selects the
repository's [lean-toolchain](lean-toolchain) pin (currently Lean 4.32.0);
do not substitute a different Lean version to work around a build failure.
The README recommends Node 24. Keep `node` and `npm` on `PATH` because Lake
also builds the widgets.

```bash
lake exe cache get
lake build
```

The first command downloads dependency build artifacts. The default Lake
build includes `Veil`, its widget bundles, and `VeilTest`; the test library is
also registered as the Lake test driver. Dependencies and build targets are
specified in [lakefile.lean](lakefile.lean). Keep dependency upgrades separate
from unrelated fixes, and include intended manifest/lockfile changes.

For cvc5 build failures, inspect the actual compiler/linker error and the
[CI dependency setup](.github/workflows/ci.yml). Report an environment failure
separately from a failing Veil regression. Avoid deleting or modifying caches
that another checkout is using.

## Find the relevant code

| Area | Location |
| --- | --- |
| DSL declarations, elaboration, and state representations | [Veil/Frontend/DSL](Veil/Frontend/DSL) |
| Extensible `do` elaboration and action semantics | [Veil/Frontend/DSL/Action](Veil/Frontend/DSL/Action) |
| Concrete and symbolic model checking | [Veil/Core/Tools/ModelChecker](Veil/Core/Tools/ModelChecker) |
| Verification scheduling and results | [Veil/Core/Tools/Verifier](Veil/Core/Tools/Verifier) |
| Solver integration | [Veil/Backend/SMT](Veil/Backend/SMT) |
| Lean widget producers and TypeScript consumers | [Veil/Core/UI](Veil/Core/UI), [widget/src](widget/src) |
| Shared utilities and proofs | [Veil/Util](Veil/Util) |
| Regressions, execution tests, and performance cases | [VeilTest](VeilTest) |

Follow the actual import graph when changing boundaries; directory names alone
do not establish a layering contract. Prefer shared helpers at the lowest
layer that owns their semantics. Keep public names, simplifier attributes, and
deriving handlers in mind when deciding whether code is unused.

## Implement and verify changes

Start with a small reproduction of the observed behavior. Add a regression
that would fail without the fix and checks the result a caller depends on.
For action execution, successful elaboration alone is insufficient: inspect
post-states or execute the action, as in
[ActionExecution/RegressionCoverage.lean](VeilTest/ActionExecution/RegressionCoverage.lean).
Use `#guard_msgs` for expected diagnostics. Preserve kernel-checked proofs and
existing elaboration invariants when simplifying code.

Run focused checks while iterating, then the full Lean suite for Lean
implementation changes:

```bash
lake build VeilTest.ActionExecution.RegressionCoverage
lake build VeilTest
```

Choose the focused module relevant to the change. For an ad hoc reproduction,
`lake env lean path/to/Repro.lean` checks that file using existing dependency
artifacts; first build changed imported modules so it cannot silently test
stale code. Tests under `VeilTest` are discovered through Lake's submodule glob.
When changing the public DSL, also check an affected example, for instance
`lake build Examples.Tutorial.Ring`. Examples are a separate library and are
not all covered by the default targets.

For widget changes, install the locked dependencies once and validate from
`widget/`:

```bash
cd widget
npm ci
npx tsc --noEmit
npm run build
```

`build` runs TypeScript and bundles the generated JavaScript. `build-dev`
produces development bundles. Consult [package.json](widget/package.json)
for scripts available on your branch; the base package has no `test` or
`typecheck` script. The current `watch`/`watch-dev` scripts watch Rollup inputs
in `dist`, so they do not themselves compile changed TypeScript. Rebuild or
run the TypeScript compiler in watch mode as well.

Check user-visible widget behavior in the Lean infoview when relevant,
especially editor actions and multiple widgets. A passing TypeScript build
does not validate those interactions. Keep Lean JSON/RPC producers and
TypeScript consumers consistent; preserve distinctions between pending,
unknown, failed, cancelled, bounded, and conclusive results.

For performance-sensitive changes, the repository provides:

```bash
lake script run perftest
```

This runs cases in [VeilTest/Performance](VeilTest/Performance) with per-file
`.timeout` limits. The current implementation uses 120 seconds when that file
is absent, despite the older 20-second comment in `lakefile.lean`. Compare
before/after runs under comparable conditions; do not raise a limit merely
to hide a regression. The current CI workflow uses `lean-action` on Linux and
macOS, without an explicit performance-test step. Passing the ordinary build
does not establish that the performance limits passed.

For documentation-only changes, check links, paths, command spellings, and
`git diff --check`; a full code rebuild is unnecessary. For all changes,
report commands actually run, results, and relevant limitations. Distinguish
cached builds from newly executed checks, and automated checks from manual
editor or combined-branch testing. Do not describe untested paths as verified.

## Commits and review

Use the convention established in the `main` history:

```text
<type>: <lower-case imperative summary>
```

Existing types include `fix`, `feat`, `refactor`, `chore`, `test`, `perf`, and
`docs`. For example:

```text
fix: recognise macro-generated capital indices
refactor: share predicate layout queries
docs: explain contributor workflow
```

Keep one logical change per commit. For a fix, use the body to explain the
previous problem and how the change addresses it; include a concrete trigger
when useful. Separate independent fixes and unrelated cleanup so each commit
can be reviewed on its own. A prefix does not replace a descriptive summary.
This convention does not imply mandatory scopes, a title-length limit,
signing, a DCO, or other Conventional Commits rules.

Before committing, inspect the diff and avoid including another contributor's
work or generated build artifacts. Use the branch and destination requested
for the task, and keep separate workstreams isolated. Summarize the resulting
behavior, relevant validation, compatibility changes, and remaining limitations
in the review description. Update language documentation or examples when the
public behavior changes.
