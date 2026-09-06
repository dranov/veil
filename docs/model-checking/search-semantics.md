# Concrete search coverage

Initial states have depth zero. An explicit `reachedDepthBound d` checks the state
predicates at every reached distance from zero through `d`, inclusive. It does not
execute actions leaving states at depth `d`, so it cannot diagnose their outgoing
assertions or deadlocks. If the frontier becomes empty before the boundary, the
search is exhausted; otherwise its result retains the requested depth bound.
Sequential and parallel exploration use the same boundary predicate pass.

The DSL preserves its existing `maxDepth := 0` convention: zero means unlimited.
Positive `maxDepth` values use the distance convention above. Low-level callers
can request an initial-state-only check with `reachedDepthBound 0`.

A recorded violation remains a violation if a depth limit or cancellation later
stops the search. Stopping conditions control when exploration stops; omitting a
violation from those conditions does not suppress its eventual report. Evidence
also prevents a continuing interpreted search from handing off to a compiled run.

## Constraints and initialization

State constraints restrict exploration. Successful initial states and successor
states outside a constraint are skipped. They do not disable the original actions:
a state whose only successful successors are pruned is a constraint boundary, not
a deadlock. A state with no original successful action remains subject to the
termination predicate. An assertion raised by an action executed at an explored
state is reported even if its failure state is outside the constraint.

Exhaustion under state constraints describes the constrained exploration; it is
not evidence about the skipped states. A depth-bound result likewise does not
claim complete coverage of the original system.

Initializer assertion failures are retained independently of successful initial
states. Any failing initializer branch is reported before BFS, even when another
branch initializes successfully or the failure state lies outside the constraint.
The result carries an `initialization` witness with `theory` and `state`; it does
not pretend that the failed initializer established a valid initial state or took
an ordinary transition. Low-level enumerable-system clients can supply failures
through `initFailures`, which defaults to the empty list for compatibility.

## Cancellation, workers, and statistics

Cancellation is polled independently of progress sampling, between explored
states and boundary predicates. Parallel workers poll within their assigned
chunks and notify their peers after a terminal result. An individual pure action
or predicate evaluation must return before its next cancellation poll; the checker
does not forcibly interrupt that computation.

A small frontier runs directly in one worker. Larger frontiers use nonempty chunks
bounded by the normalized worker count. `numSubTasks := 0` retains the minimum of
one worker. The compatibility field `numSubSteps` currently only supports `1`;
other values fail explicitly instead of being silently ignored.

Parallel action statistics remove duplicate discovery credit during reduction.
When several workers discover the same fingerprint, only the first retained
worker receives distinct-state credit; generated-state counts are preserved.
Custom `ActionStatUpdate` implementations must implement `removeDuplicate` to
support this correction. Counts and search identity still use the configured state
fingerprint; this change does not provide collision-free identity.

The search retains its reachability and closure proofs. The cancellation path has
an explicit invariant-preservation proof. Boundary coverage, initializer outcomes,
constraint behavior, and final-result preservation additionally have executable
regressions; those regressions are not a proof of every concurrent interleaving.
