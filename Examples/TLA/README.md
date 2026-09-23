# TLA+ examples

The specifications keep their TLA+ source comments alongside the executable Veil
translation. The collection examples use the DSL's finite-set vocabulary:

| Operation | Examples |
| --- | --- |
| `set_type`, inferred model carriers, literals, membership, union and difference | SimpleAllocator, Room, KVSnap, KVSnapRe, Paxos, MultiPaxos, EPaxos, NOPaxos, Raft, BcastByz |
| Nonempty and fixed-cardinality subset choices | SimpleAllocator, KVSnap, KVSnapRe, BcastByz |
| `finite_type` and `TSet.univ` | BcastByz, MultiPaxos |
| `card`, predicate counts and distinct-sender counts | Room, BcastByz, Paxos, MultiPaxos, EPaxos, NOPaxos, Raft |
| Comprehensions, record images and collection-bounded quantifiers | KVSnap, KVSnapRe, Paxos, MultiPaxos, EPaxos, NOPaxos |
| Indexed unions | SimpleAllocator, MultiPaxos, EPaxos |
| Inclusive intervals | NOPaxos |
| Partial functions with generated coherence invariants | KeyValueStore, Raft |
| Whole-function nondeterministic initialization | EWD840 |

These translations preserve the distinction between sets, sequences and multisets.
In particular, MultiPaxos keeps `SlotsUNIV` ordered for its deterministic first-free
slot choice; NOPaxos keeps `ReplicaOrder` ordered for leader selection; snapshot
histories and protocol logs remain lists; and Raft's message bag remains a
multiset. Explicit resource and participant subdomains remain explicit parameters.

`set_type` model parameters default to tree sets. Explicit overrides, such as the
sorted-list carriers shown in KVSnapRe, remain available. See the
[DSL reference](../../docs/DSL-Reference.md#finite-sets) for the syntax and laws.

Existing model-checking commands retain their bounds and expected outcomes.
Paxos, MultiPaxos and NOPaxos additionally run small bounded regression configurations.
AWSDnsRace, BuggyCircularBuffer and Traffic intentionally expose counterexamples.
Large model configurations that were commented out remain optional: compiling a
specification generates its definitions, but does not exhaustively verify those
configurations.
