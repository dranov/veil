import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete

namespace ModelCheckerActionStats

def diamond : EnumerableTransitionSystem Unit (List Unit) Nat (List Nat) Int Nat
    (List (Nat × ExecutionOutcome Int Nat)) () where
  initStates := [0]
  tr := fun _ n => match n with
    | 0 => [(0, .success 1), (0, .success 2)]
    | 1 => [(1, .success 3)]
    | 2 => [(2, .success 3)]
    | _ => []

#eval show IO Unit from do
  let params : SearchParameters Unit Nat := { invariants := [], earlyTerminationConditions := [] }
  for workers in [1, 2, 3, 4] do
    let (id, token) ← allocProgressInstance
    let result ← breadthFirstSearchParallel (asm := ActionStatsMap Nat) (σₕ := UInt64)
      params diamond { numSubTasks := workers, thresholdToParallel := 0 } id token
    let stats := ActionStatUpdate.dump (κ := Nat) result.base.actionStatsMap
    unless result.globalSeen.size == 4 &&
        stats.foldl (fun n s => n + s.distinctStates) 0 == 3 &&
        stats.foldl (fun n s => n + s.statesGenerated) 0 == 4 do
      throw <| IO.userError s!"parallel discoveries counted twice: {repr stats}"
    for stat in stats do
      unless stat.distinctStates ≤ stat.statesGenerated do
        throw <| IO.userError "distinct count exceeds generated count"

end ModelCheckerActionStats
