# Model-checker state identity and witnesses

The public concrete checker uses 64-bit fingerprints to identify states. Its
closure/completeness theorems assume the state view is injective. Ordinary
hashing does not establish that assumption: a clean run can miss reachable
states because of collisions. Improving a representation's hash does not turn
that assumption into a proof.

Counterexample recovery now checks a separate, narrower contract. Parent-log
walking is bounded by the size of the log and rejects missing entries and
cycles. The initial fingerprint must match an actual initial state. Each step
is replayed from that concrete state, selecting an executable transition with
the expected post-state fingerprint. The actual replayed label is retained;
an alternative label reaching the same state is legitimate. Finally, the
endpoint must exhibit the reported invariant violation, deadlock, or assertion
failure. Missing assertion witnesses and invalid endpoints are errors, rather
than incomplete or misleading counterexamples. Recovery errors abort the run;
they are not clean search results.

This validation cannot restore paths pruned earlier by a collision, nor does it
try every colliding replay candidate. It can reject a reported witness even if
another colliding path would witness the violation. It does not prove the final
result function correct in Lean. The regression suite separately replays a
recovered step and tests deliberate fingerprint collisions, malformed logs,
missing initial states, and missing assertion witnesses.

## Representation scope

Partial-map enumeration makes one absent-or-present value choice per distinct
key. Its existing completeness obligation remains proved. For three keys and
three values it generates 64 candidates, all distinct, instead of 512
candidates with duplicate overwrites.

The existing `FinmapLike` adapters for hash maps, tree maps, and extensional tree
maps interpret absence as the codomain's `Inhabited.default`. Their updates now
erase an entry when assigning that default. The lawful-update proofs are
preserved. This normalizes updates from the empty/default representation;
ordinary partial-map `insert` still stores explicit defaults. Externally
constructed maps, or arbitrary enumerated partial maps reused as total-function
states, are not globally canonicalized by this change. A dedicated canonical
finite total-function representation would be needed to enforce that invariant
at every construction boundary.

This finite-domain update fix is independent of the infinite-domain
finite-support representation on `george/fix-model-checker-hashing`.

## Exact identity assessment

The sequential and parallel search internals already abstract over a state view.
An exact view can use full states and lawful equality, with lawful ordering also
required by the parallel containers. Hash-table collisions then require equality
checks instead of identifying states. However, the public result/progress and
compiled execution paths currently fix the view to `UInt64`, and generated
representations do not uniformly provide the required lawful exact instances.

An exact public mode is deferred. It needs coordinated representation instances,
result serialization, compiled/interactive configuration, memory/performance
measurements, and collision regressions in both strategies. This branch does
not introduce an incomplete configuration switch or claim fingerprint
injectivity.
