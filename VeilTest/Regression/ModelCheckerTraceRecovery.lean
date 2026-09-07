import Veil.Core.Tools.ModelChecker.Concrete.Checker

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete

namespace ModelCheckerTraceRecovery

-- Deliberate collisions exercise the final result boundary, independently of
-- the ordinary hash function. Search completeness is not asserted here.
local instance : StateFingerprint Nat UInt64 :=
  { StateFingerprint.ofHash Nat with view := fun n => UInt64.ofNat (n % 2) }

def sys : EnumerableTransitionSystem Unit (List Unit) Nat (List Nat) Int Nat
    (List (Nat × ExecutionOutcome Int Nat)) () where
  initStates := [0]
  tr := fun _ n => if n = 0 then [(7, .success 1), (8, .success 3)] else []

def ctx : BaseSearchContext Nat Nat UInt64 (ActionStatsMap Nat) :=
  { BaseSearchContext.initial (κ := Nat) [0] with log := .ofList [(0, none), (1, some (0, 99))] }

def params (bad : Nat) : SearchParameters Unit Nat := {
  invariants := [{ name := `bad, property := fun _ n => n ≠ bad }]
  terminating := { property := fun _ _ => False }
  earlyTerminationConditions := [.foundViolatingState]
}

def expectError (action : IO α) (fragment : String) : IO Unit := do
  let failure ← try
    let _ ← action
    pure none
  catch e => pure (some e.toString)
  match failure with
  | some message => unless (message.splitOn fragment).length > 1 do
      throw <| IO.userError s!"wrong recovery error: {message}"
  | none => throw <| IO.userError s!"expected recovery failure: {fragment}"

#eval show IO Unit from do
  let trace ← recoverViolationTrace sys (params 1) ctx 1 (.safetyFailure [`bad])
  unless trace.initialState == 0 && trace.steps.size == 1 &&
      trace.lastState == 1 && trace.steps[0]!.transitionLabel == 7 do
    throw <| IO.userError "incorrect recovered witness"
  -- Replay is a member of the executable transition relation even though the
  -- stored label differs. A label difference alone is not an invalid trace.
  unless (sys.tr () trace.initialState).any (fun (label, outcome) =>
      match outcome with
      | .success st => label == trace.steps[0]!.transitionLabel && st == trace.lastState
      | _ => false) do
    throw <| IO.userError "witness failed independent transition replay"
  -- The same fingerprint must not turn a safe endpoint into a counterexample.
  expectError (recoverViolationTrace sys (params 3) ctx 1 (.safetyFailure [`bad]) : IO _)
    "does not exhibit"
  expectError (recoverTrace (th := ()) { sys with initStates := [] } ctx 1 : IO _) "no initial state"
  expectError (recoverTrace sys { ctx with log := .ofList [(1, some (0, 7))] } 1 : IO _)
    "missing parent-log"
  expectError (recoverTrace sys { ctx with log := .ofList [(0, some (1, 7)), (1, some (0, 7))] } 1 : IO _)
    "cyclic parent log"
  expectError (recoverTrace sys { ctx with log := .ofList [(0, none), (4, some (0, 7))] } 4 : IO _)
    "Could not recover transition"
  expectError (recoverTrace sys ctx 1 (some 17) : IO _) "assertion failure cannot be replayed"
  expectError (recoverViolationTrace sys (params 1) ctx 0 .deadlock : IO _)
    "does not exhibit"
  let _ ← recoverViolationTrace sys (params 1) ctx 1 .deadlock
  let assertionSys : EnumerableTransitionSystem Unit (List Unit) Nat (List Nat) Int Nat
      (List (Nat × ExecutionOutcome Int Nat)) () := { sys with tr := fun _ n =>
    if n = 0 then [(7, .success 1)] else [(9, .assertionFailure 17 3)] }
  let failure ← recoverViolationTrace assertionSys (params 1) ctx 1 (.assertionFailure 17)
  unless failure.failingStep.any (fun step => step.transitionLabel == 9 && step.nextState == 3) do
    throw <| IO.userError "missing replayed assertion witness"

end ModelCheckerTraceRecovery
