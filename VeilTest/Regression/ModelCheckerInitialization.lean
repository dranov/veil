import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete ModelCheckerKnownViolation

#eval show IO Unit from do
  for cfg in [none, some { numSubTasks := 2 }] do
    for successful in [[], [0]] do
      let sys := { chain with initStates := successful, initFailures := [(23, 99)] }
      let (id, token) ← allocProgressInstance
      let result ← findReachable (th := ()) (asm := ActionStatsMap Nat) sys {
        invariants := []
        stateConstraints := [{ property := fun _ n => n < 2 }]
        earlyTerminationConditions := [.reachedDepthBound 0]
      } cfg id token
      match result with
      | .initializationFailure 23 () 99 =>
        let json := Lean.toJson result
        unless (json.getObjVal? "trace").toOption == some .null &&
            (json.getObjVal? "initialization").isOk do
          throw <| IO.userError "initializer witness was represented as a transition trace"
      | _ => throw <| IO.userError s!"initializer assertion lost: {repr result}"
