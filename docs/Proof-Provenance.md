# Verification proof provenance

Verification results describe the selected proof witness and its transitive
Lean declaration dependencies. A proof which merely refers to an admitted
helper is not admission-free. The `@[veil]` attribute rejects such helpers,
just as it rejects a direct explicit or synthetic `sorry`.

The result's optional `proofProvenance` object distinguishes:

- `hasAdmissions`: a direct or transitive `sorryAx` dependency whose origin is
  not marked as a Veil trusted SMT call. This includes explicit admissions and
  admissions from other tools whose origin Veil cannot establish.
- `trustsSmt`: a `sorryAx` introduced inside a marked trust-enabled `veil_smt`
  proof. Referenced declarations retain their own provenance even inside a
  marked call; a proof can have both flags.
- `axioms`: all other transitive declared axiom names. The widget lists axioms
  beyond the usual `propext`, `Classical.choice`, and `Quot.sound`. A proof with
  no admissions can still depend on declared axioms.
- `incomplete`: an unresolved variable or unavailable declaration prevented a
  complete inspection. The UI reports this uncertainty.

The old `proofHasSorry` field remains for protocol compatibility. It now means
that either admission flag is true, including dependencies. It must not be used
as evidence that the SMT solver produced the admission. Old payloads without
provenance are displayed as unavailable, rather than guessed to be SMT trust.

## Trust modes

`veil.smt.trust` defaults to `true` in normal use. The solver's unsatisfiable
answer discharges a goal by admission. Veil marks that call's proof region so
its warning and widget banner can accurately describe solver trust.

With `set_option veil.smt.trust false`, SMT proof reconstruction is requested.
The test library sets this weak default, but dedicated regressions explicitly
exercise both modes. Reconstruction is not a blanket promise that every
imported dependency is admission-free: provenance is still checked, and
admitted library lemmas or explicit axioms remain visible.

Unmarked admissions, including results of direct calls to other solver tactics,
are reported as admissions of unestablished origin. The marker and cached
summary are informational Lean expression metadata, not kernel certificates
or a security boundary against a metaprogram deliberately forging metadata.
The change introduces no new axiom and does not alter the kernel's trust model.

## Caching and asynchronous results

The analysis visits each declaration at most once per witness and uses Lean's
cached transitive axiom summaries for imported declarations. It opens bodies
only when an admission's origin needs inspection. A summary is attached to the
witness while its elaboration environment is available. It travels with the
witness across asynchronous discharger snapshots and theorem insertion, so
repeated rendering does not traverse the dependency graph again or depend on
the receiving environment having the same local declarations.

Tests cover direct, indirect, and imported admissions; real SMT calls in both
modes; declared axioms; trust-marker boundaries; missing dependencies; cache
reuse in an empty environment; theorem registration; and widget classification.
