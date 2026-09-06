import VeilTest.Regression.ModelCheckerKnownViolation

open Veil Veil.ModelChecker Veil.ModelChecker.Concrete ModelCheckerKnownViolation

#eval show IO Unit from do
  let params : SearchParameters Unit Nat := { invariants := [], earlyTerminationConditions := [] }
  let (id, token) ← allocProgressInstance
  token.set
  let ctx := BaseSearchContext.initial (σₕ := UInt64) (κ := Nat) (asm := ActionStatsMap Nat) [0]
  let now ← IO.monoMsNow
  match ← checkCancellationWithPeriodicUpdate id now 60000 token ctx 1 with
  | .searchCancelled => pure ()
  | _ => throw <| IO.userError "cancellation was throttled by progress interval"
  -- Cancellation before starting must not execute even the first state.
  for cfg in [none, some { numSubTasks := 2, thresholdToParallel := 0 }] do
    let result ← findReachable (asm := ActionStatsMap Nat) chain params cfg id token
    match result with
    | .cancelled => pure ()
    | _ => throw <| IO.userError "pre-cancelled search continued"
  -- A worker checks between states, even within a single large frontier chunk.
  -- The callback cancels deterministically at its third poll, without timing races.
  let polls ← IO.mkRef 0
  let wide : EnumerableTransitionSystem Unit (List Unit) Nat (List Nat) Int Nat
      (List (Nat × ExecutionOutcome Int Nat)) () := { chain with initStates := List.range 100 }
  let gs := (MapReduceSearchContextMain.initial (κ := Nat) (σₕ := UInt64)
    (asm := ActionStatsMap Nat) wide.initStates 1).globalSeen
  let queue := wide.initStates.map fun n => (⟨hash n, n⟩ : MapReduceQueueItem UInt64 Nat)
  let worker ← LawfulMapReduceSearchContextLocal.bfsBigStep params wide gs 0 queue
    (by intro item h; simp [queue] at h; obtain ⟨n, hn, rfl⟩ := h; exact .init _ hn)
    (do polls.modify (· + 1); return (← polls.get) ≥ 3)
  unless (← polls.get) == 3 && worker.val.1.statesFound == 2 do
    throw <| IO.userError "worker cancellation did not stop within its chunk"
  match worker.val.1.finished with
  | some (.earlyTermination .cancelled) => pure ()
  | _ => throw <| IO.userError "worker did not publish cancellation"
