import Veil.Core.Tools.ModelChecker.Concrete.Sequential
import Veil.Core.Tools.ModelChecker.Concrete.MapReduce

namespace Veil.ModelChecker.Concrete

/-! ## Trace Recovery

These functions reconstruct a full trace with concrete states from a SearchContext
that contains fingerprint-based state references. -/

/-- Walk backward through the log to build a fingerprint-based path from a
state to an initial state. Returns `(initialStateFingerprint, steps)` where
each step has the transition label and the fingerprint of the post-state. -/
def retraceSteps [BEq σₕ] [Hashable σₕ]
  (log : Std.HashMap σₕ (Option (σₕ × κ))) (cur : σₕ)
  (acc : List (Step σₕ κ) := []) : Except String (σₕ × List (Step σₕ κ)) :=
  walk (log.size + 1) cur acc
where
  -- A finite parent chain cannot visit more entries than the log contains.
  walk : Nat → σₕ → List (Step σₕ κ) → Except String (σₕ × List (Step σₕ κ))
    | 0, _, _ => .error "Trace recovery failed: cyclic parent log"
    | fuel + 1, current, steps =>
      match log[current]? with
      | some (some (prev, label)) =>
        walk fuel prev ({ transitionLabel := label, nextState := current } :: steps)
      | some none => .ok (current, steps)
      | none => .error "Trace recovery failed: missing parent-log entry"

/-- Find a concrete state with the requested fingerprint; absence is explicit. -/
@[inline, specialize]
def findByFingerprint [fp : StateFingerprint σ σₕ]
  (states : List σ) (targetFp : σₕ) : Option σ :=
  states.find? (fun s => fp.view s == targetFp)

/-- Reconstruct a full trace with concrete states from a SearchContext.
This re-executes transitions to recover full state objects from fingerprints.
The `targetFingerprint` parameter specifies which violating state's trace to recover.
If `assertionFailureExId` is provided, this is an assertion failure trace and we'll
find the failing transition to populate the `failingStep` field. -/
def recoverTrace {ρ σ κ σₕ asm : Type} {m : Type → Type}
  [Monad m] [MonadLiftT BaseIO m] [MonadLiftT IO m]
  [fp : StateFingerprint σ σₕ]
  [Inhabited σ] [Repr σₕ]
  [ActionStatUpdate κ asm]
  {th : ρ}
  (sys : EnumerableTransitionSystem ρ (List ρ) σ (List σ) Int κ (List (κ × ExecutionOutcome Int σ)) th)
  -- (params : SearchParameters ρ σ)
  (ctx : BaseSearchContext σ κ σₕ asm)
  (targetFingerprint : σₕ)
  (assertionFailureExId : Option Int := none)
  : m (Trace ρ σ κ) := do
  -- Retrace steps from the target fingerprint back to an initial state
  let (initFp, stepsFp) ← IO.ofExcept (retraceSteps ctx.log targetFingerprint)
  -- Recover initial state by matching fingerprint
  let initialState ← match findByFingerprint sys.initStates initFp with
    | some st => pure st
    | none => IO.ofExcept <| Except.error "Trace recovery failed: initial fingerprint has no initial state"
  -- Recover trace steps by re-executing transitions and matching fingerprints
  let mut curSt := initialState
  let mut steps : Steps σ κ := #[]
  for step in stepsFp do
    let outcomes := sys.tr th curSt
    -- Extract successful transitions for trace recovery
    let (successfulTransitions, _) := partitionExecutionOutcome outcomes
    let (transitionLabel, nextSt) ←
      match successfulTransitions.find? (fun (_, s) => fp.view s == step.nextState) with
      | some (tr, s) => pure (tr, s)
      | none => IO.ofExcept <| Except.error s!"Could not recover transition from fingerprint {repr (fp.view curSt)} to {repr step.nextState}!"
    curSt := nextSt
    steps := steps.push { transitionLabel := transitionLabel, nextState := nextSt }
  let failingStep : Option (Step σ κ) ← match assertionFailureExId with
    | none => pure none
    | some exId =>
      match (sys.tr th curSt).find? (·.2.exceptionId? == some exId) with
      | some (label, .assertionFailure _ failState) =>
        pure (some { transitionLabel := label, nextState := failState })
      | _ => IO.ofExcept <| Except.error "Trace recovery failed: reported assertion failure cannot be replayed"
  return { theory := th, initialState, steps, failingStep }

/-- Replay a witness and check that its endpoint exhibits the reported violation.
Fingerprint matches alone do not validate a counterexample: colliding states may
follow a different executable path. Labels come from the replayed transitions,
so equivalent alternative labels are accepted. This does not establish completeness
of fingerprint-based exploration. -/
def recoverViolationTrace {ρ σ κ σₕ asm : Type} {m : Type → Type}
  [Monad m] [MonadLiftT BaseIO m] [MonadLiftT IO m]
  [fp : StateFingerprint σ σₕ] [Inhabited σ] [Repr σₕ]
  [ActionStatUpdate κ asm] {th : ρ}
  (sys : EnumerableTransitionSystem ρ (List ρ) σ (List σ) Int κ (List (κ × ExecutionOutcome Int σ)) th)
  (params : SearchParameters ρ σ) (ctx : BaseSearchContext σ κ σₕ asm)
  (targetFingerprint : σₕ) (violation : ViolationKind) : m (Trace ρ σ κ) := do
  let assertionId := match violation with
    | .assertionFailure id => some id
    | _ => none
  let trace ← recoverTrace sys ctx targetFingerprint assertionId
  let valid := match violation with
    | .safetyFailure names =>
      !names.isEmpty && names.all fun name => params.invariants.any fun inv =>
        inv.name == name && !inv.holdsOn th trace.lastState
    | .deadlock =>
      (partitionExecutionOutcome (sys.tr th trace.lastState)).1.isEmpty &&
        !params.terminating.holdsOn th trace.lastState
    | .assertionFailure _ => trace.failingStep.isSome
    | .assumptionFailure _ => false
  unless valid do
    IO.ofExcept <| Except.error
      "Trace recovery failed: replayed endpoint does not exhibit the reported violation (possible fingerprint collision)"
  return trace

/-! ## Model Checker

This module provides the main entry point for model checking, dispatching to
either the sequential or parallel implementation based on configuration. -/

def findReachable {ρ σ κ : Type} {m : Type → Type}
  [Monad m] [MonadLiftT BaseIO m] [MonadLiftT IO m]
  [inhabσ : Inhabited σ] [Repr κ]
  [ActionStatUpdate κ asm]
  {th : ρ}
  (sys : EnumerableTransitionSystem ρ (List ρ) σ (List σ) Int κ (List (κ × ExecutionOutcome Int σ)) th)
  [fp : StateFingerprint σ UInt64]
  (params : SearchParameters ρ σ)
  (parallelCfg : Option ParallelConfig)
  (progressInstanceId : Nat)
  (cancelToken : IO.CancelToken)
  : m (ModelCheckingResult ρ σ κ UInt64) := do
  let assumptionViolations := params.violatedAssumptions th
  unless assumptionViolations.isEmpty do
    setViolationFound progressInstanceId
    return ModelCheckingResult.foundViolation 0 (.assumptionFailure assumptionViolations) none
  -- Create a "filtered" version of the system
  let sys := if params.stateConstraints.isEmpty then sys else {
    initStates := sys.initStates.filter (params.satisfiesConstraints th)
    tr := fun th' s => (sys.tr th' s).filter (fun (_, o) => match o with
      | .success s' => params.satisfiesConstraints th s'
      | .assertionFailure _ s' => params.satisfiesConstraints th s' -- assertion failures should satisfy constraints to be considered
      | .divergence => true) -- well
  }
  let (ctx, distinctCount) ← match parallelCfg with
    | some cfg => do
      let mctx ← breadthFirstSearchParallel (σₕ := UInt64) params sys cfg progressInstanceId cancelToken
      pure (mctx.base, mctx.globalSeen.size)
    | none => do
      let sctx ← breadthFirstSearchSequential (σₕ := UInt64) params sys 60000 progressInstanceId cancelToken
      pure (sctx.1, sctx.1.log.size)
  match ctx.finished with
  | some (.earlyTermination (.foundViolatingState fingerprint violations)) => do
    return ModelCheckingResult.foundViolation fingerprint (.safetyFailure violations) (some (← recoverViolationTrace sys params ctx fingerprint (.safetyFailure violations)))
  | some (.earlyTermination (.deadlockOccurred fingerprint)) => do
    return ModelCheckingResult.foundViolation fingerprint .deadlock (some (← recoverViolationTrace sys params ctx fingerprint .deadlock))
  | some (.earlyTermination (.assertionFailed fingerprint exId)) => do
    return ModelCheckingResult.foundViolation fingerprint (.assertionFailure exId) (some (← recoverViolationTrace sys params ctx fingerprint (.assertionFailure exId)))
  | some (.earlyTermination (.reachedDepthBound _)) =>
    -- No violation found within depth bound; report number of states explored
    return ModelCheckingResult.noViolationFound distinctCount (.earlyTermination (.reachedDepthBound ctx.completedDepth))
  | some (.earlyTermination .cancelled) =>
    -- Search was cancelled by the user
    return ModelCheckingResult.cancelled
  | some (.exploredAllReachableStates) => do
    if !ctx.violatingStates.isEmpty then
      let (fingerprint, violation) := ctx.violatingStates.head!
      return ModelCheckingResult.foundViolation fingerprint violation
        (some (← recoverViolationTrace sys params ctx fingerprint violation))
    else
      return ModelCheckingResult.noViolationFound distinctCount (.exploredAllReachableStates)
  | none => panic! s!"SearchContext.finished is none! This should never happen."

end Veil.ModelChecker.Concrete
