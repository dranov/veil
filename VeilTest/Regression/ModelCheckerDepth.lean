import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete ModelCheckerKnownViolation

-- Exercise the limit, its immediate neighbors, and several parallel partition sizes.
#eval show IO Unit from do
  for cfg in [none, some { numSubTasks := 1 }, some { numSubTasks := 3, thresholdToParallel := 0 }] do
    for bound in [0, 1, 2, 3] do
      for bad in List.range (bound + 2) do
        let (id, token) ← allocProgressInstance
        let params : SearchParameters Unit Nat := {
          invariants := [{ name := `safe, property := fun _ n => n ≠ bad }]
          earlyTerminationConditions := [.reachedDepthBound bound, .foundViolatingState]
        }
        let result : ModelCheckingResult Unit Nat Nat UInt64 ← findReachable (th := ()) (asm := ActionStatsMap Nat) chain params cfg id token
        match result with
        | .foundViolation _ (.safetyFailure _) (some trace) =>
          unless bad ≤ bound && trace.steps.size == bad do
            throw <| IO.userError s!"violation outside bound {bound}: {repr result}"
        | .noViolationFound count (.earlyTermination (.reachedDepthBound actual)) =>
          unless bad > bound && actual == bound && count == bound + 1 do
            throw <| IO.userError s!"wrong coverage at bound {bound}: {repr result}"
        | _ => throw <| IO.userError s!"unexpected bounded result: {repr result}"
    -- Every initial/boundary state is checked, not only the first one.
    let (id, token) ← allocProgressInstance
    let wide := { chain with initStates := [0, 1, 2] }
    let result : ModelCheckingResult Unit Nat Nat UInt64 ← findReachable (th := ()) (asm := ActionStatsMap Nat) wide {
      invariants := [{ name := `lastInitial, property := fun _ n => n ≠ 2 }]
      earlyTerminationConditions := [.reachedDepthBound 0]
    } cfg id token
    unless (match result with | .foundViolation .. => true | _ => false) do
      throw <| IO.userError "did not check all depth-zero states"
    -- No outgoing action assertion or deadlock check may run at the boundary.
    let (id, token) ← allocProgressInstance
    let failing := { chain with tr := fun _ _ => [(0, .assertionFailure 17 1)] }
    let result : ModelCheckingResult Unit Nat Nat UInt64 ← findReachable (th := ()) (asm := ActionStatsMap Nat) failing {
      invariants := [], terminating := { property := fun _ _ => False }
      earlyTerminationConditions := [.reachedDepthBound 0, .assertionFailed, .deadlockOccurred]
    } cfg id token
    match result with
    | .noViolationFound n (.earlyTermination (.reachedDepthBound d)) =>
      unless n == 1 && d == 0 do
        throw <| IO.userError "wrong boundary state count or depth"
    | _ => throw <| IO.userError s!"executed outgoing action at depth zero: {repr result}"
