# Core boundaries and transition contracts

The September 2026 audit exposed real layering problems, but directory moves
alone do not settle semantic contracts. This branch makes the following
boundaries explicit without deleting public proofs or changing solver trust.

## Generic finite types and collections

`Veil.Util.FiniteTypes` owns heterogeneous products, `Enumeration`,
`FinEncodable`, `FinEncodableInjOnly`, their deriving handlers, and their
existing proofs. It imports no frontend module. `State.Types` re-exports these
same declaration names and retains only the representation-specific tactics.
The concrete checker and generic sorted collections import the generic module.
A regression checks the transitive import closure and exercises deriving.

The sorted collections no longer import the frontend's catch-all `Repr` and
JSON instances. Their previous Repr-based JSON formats are expressed locally:
`OrdList` encodes an array of textual elements; `OrdArray` encodes its textual
list representation. Changing those wire formats or removing all global
frontend presentation fallbacks needs a separately reviewed consumer migration.

## Native versus executable transitions

`Next` is the relation derived from execution of `NextAct`. `Next'` dispatches
to each action's `.ext.tr`; native actions retain their declared relation there.
These definitions must not be assumed interchangeable for arbitrary state
representations.

The new kernel-checked `Transition.toVeilM_transition_iff` states the precise
conversion contract for a source `s` and destination `t`:

```
(converted tr).toTransitionDerived r s t
  ↔ (∃ v, setIn v s = t) ∧ tr r s t
```

Consequently conversion refines the supplied relation, is complete for each
representable update, and is equal to that relation when the canonical
whole-state instance makes every update representable. A regression uses a
lawful Unit substate of Bool to show that a permitted native change can fail
to be executable; another checks whole-state equality in both action modes.
This is a semantic conversion theorem, not a claim that every concrete checker
configuration terminates or that 64-bit state fingerprints are collision-free.

Both generated relations remain. Removing either requires lifting these
per-action facts through module label dispatch and proving the relevant
representation/abstraction obligations for every action. The branch does not
silently assume surjectivity or remove the existing weakening proof machinery.

## Compatibility and deferred work

`ParallelConfig` has a dedicated module. The old array chunking/task API and
its public validity/completeness proofs live in `LegacyParallel`; `Interface`
re-exports them for compatibility. Current exploration uses `ListSplit` and
`IteratedProd.taskSplit`. No public theorem is deleted solely because it has
no direct repository caller.

The combined solver option now emits `grind+smt` and accepts the previously
emitted `grindAndSMT` spelling as a compatibility alias. Codec and programmatic
Options round-trips are tested for all solver values.

The verifier's redundant counters and unused environment wrapper were checked
against `george/manager-fixes`. That branch still owns the scheduler/session
state migration; removing these fields here would overlap its cancellation,
result, and snapshot changes. Its registration checks also contain dependency
cycles before topological scheduling, so the permissive legacy topological-sort
API is retained. Follow-up API removals should be made after that branch lands.

Other open architecture decisions remain: a complete declaration registry;
separating all solver/execution outcomes from presentation; narrowing global
frontend display fallbacks; and auditing supported extension consumers before
removing remaining dormant public APIs. The existing `withBackwardsCompatibility`
wrapper and collection proofs remain intact. Removal of pinned Lean/Std
compatibility bridges requires proof and performance validation, not a presumed
replacement in a newer library.
