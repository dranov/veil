import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete ModelCheckerKnownViolation

#eval show IO Unit from do
  for subSteps in [0, 2, 4] do
    let (id, token) ← allocProgressInstance
    let failed ← try
      let _ ← breadthFirstSearchParallel (σₕ := UInt64) (asm := ActionStatsMap Nat)
        { invariants := [], earlyTerminationConditions := [.reachedDepthBound 0] }
        chain { numSubSteps := subSteps } id token
      pure false
    catch error =>
      pure (error.toString == "Parallel model checking does not support numSubSteps other than 1")
    unless failed do throw <| IO.userError s!"unsupported numSubSteps={subSteps} was ignored"
