import Veil.Core.Tools.ModelChecker.Concrete.Checker

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete

namespace ModelCheckerKnownViolation

def chain : EnumerableTransitionSystem Unit (List Unit) Nat (List Nat) Int Nat
    (List (Nat × ExecutionOutcome Int Nat)) () where
  initStates := [0]
  tr := fun _ n => [(0, .success (n + 1))]

-- Finding a violation need not itself be configured to stop exploration.
-- Reaching a bound must still return the evidence, in either search strategy.
#eval show IO Unit from do
  for cfg in [none, some { numSubTasks := 2, thresholdToParallel := 0 }] do
    let (id, token) ← allocProgressInstance
    let params : SearchParameters Unit Nat := {
      invariants := [{ name := `initialFailure, property := fun _ n => n ≠ 0 }]
      earlyTerminationConditions := [.reachedDepthBound 1]
    }
    let result ← findReachable (asm := ActionStatsMap Nat) chain params cfg id token
    match result with
    | .foundViolation _ (.safetyFailure [`initialFailure]) (some trace) =>
      unless trace.initialState == 0 && trace.steps.isEmpty do
        throw <| IO.userError "wrong witness for initial invariant failure"
    | _ => throw <| IO.userError s!"bound discarded violation: {repr result}"
    let some refs ← getProgressRefs id | throw <| IO.userError "missing progress"
    unless ← refs.violationFound.get do
      throw <| IO.userError "continuing after a violation must prevent compiled handoff"

end ModelCheckerKnownViolation
