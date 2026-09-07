# DSL semantics maintenance

The September 2026 remediation rejects declaration-level action/procedure
contracts: their statements were never elaborated or enforced. Ordinary
`require` and `assert` statements in an action body retain their existing
semantics. A module also rejects a second termination predicate rather than
silently selecting the first; users must write the intended combination.

Procedure metadata now uses `ProcedureBody.imperative` or
`ProcedureBody.relational`. Extensions inspecting the previous `code` field
must match the new `body` field; a relational body contains a Lean term, not a
`doSeq`. The unused `spec` field has been removed because contracts are rejected.

Assertion isolates are unsupported and have an explicit diagnostic. The
unfinished `StateAssertion.inSets`, `Module._assertionSets`, and
`Module.defaultAssertionSet` metadata has been removed. It had no checking
consumer, simplification attributes, or repository extension callers; it did
not implement independent verification of assertion sets. Existing assertion
and verification syntax remains the supported API.

The theory-parameter filter and predicate expression layout now have shared
implementations used by both locality transformations. Their proof generation
and simplifier invariants remain intact. Layout validation checks the ordered
theory/state arguments of ghost predicates. This is an incremental cleanup:
registration still needs a future fully qualified declaration registry carrying
all elaborated binders and generated artifacts. Optional locality discovery
still treats unsupported definitions as unavailable; broad changes to that
contract and the full registry should be reviewed with the proof pipeline.

Module composition scaffolding remains. Its public metadata and immutable
traversal need an explicit supported-API decision and dedicated end-to-end
semantics before removal; absence of repository callers alone is insufficient
justification for deleting those public declarations.
