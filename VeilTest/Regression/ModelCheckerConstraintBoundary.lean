import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete ModelCheckerKnownViolation

#eval show IO Unit from do
  let params : SearchParameters Unit Nat := {
    invariants := []
    terminating := { property := fun _ n => n = 3 }
    stateConstraints := [{ property := fun _ n => n ≤ 1 }]
    earlyTerminationConditions := [.assertionFailed, .deadlockOccurred]
  }
  for cfg in [none, some { numSubTasks := 3, thresholdToParallel := 0 }] do
    let (id, token) ← allocProgressInstance
    let result ← findReachable (asm := ActionStatsMap Nat) chain params cfg id token
    match result with
    | .noViolationFound 2 .exploredAllReachableStates => pure ()
    | _ => throw <| IO.userError s!"constraint manufactured deadlock: {repr result}"
    let deadEnd := { chain with tr := fun _ n => if n == 0 then [(0, .success 1)] else [] }
    let (id, token) ← allocProgressInstance
    let result ← findReachable (th := ()) (asm := ActionStatsMap Nat) deadEnd params cfg id token
    match result with
    | .foundViolation _ .deadlock (some trace) =>
      unless trace.steps.size == 1 do throw <| IO.userError "wrong deadlock witness"
    | _ => throw <| IO.userError "constraint hid a real deadlock"
    let failing := { chain with tr := fun _ n =>
      if n == 0 then [(0, .success 1)] else [(0, .success 2), (1, .assertionFailure 19 2)] }
    let (id, token) ← allocProgressInstance
    let result ← findReachable (th := ()) (asm := ActionStatsMap Nat) failing params cfg id token
    match result with
    | .foundViolation _ (.assertionFailure 19) (some trace) =>
      unless trace.steps.size == 1 && trace.failingStep.any (·.nextState == 2) do
        throw <| IO.userError "wrong boundary assertion witness"
    | _ => throw <| IO.userError s!"constraint discarded action assertion: {repr result}"
