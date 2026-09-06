/-
Copyright (c) 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: George Pîrlea
-/
import Lean.Data.Json
import Std.Data.HashMap
import Veil.Core.Tools.ModelChecker.Concrete.Core

namespace Veil.ModelChecker.Concrete
open Lean

/-- A single log line with timestamp and source. -/
structure CompilationLogLine where
  timestamp : Nat    -- milliseconds since compilation start
  content : String
  isError : Bool := false  -- true if from stderr
  deriving ToJson, FromJson, Inhabited, Repr

/-- Status of background compilation. -/
inductive CompilationStatus where
  | none                                                            -- No background compilation
  | inProgress (elapsedMs : Nat) (logLines : Array CompilationLogLine)  -- Compilation is running
  | succeeded                                                       -- Compilation finished successfully
  | failed (error : String)                                         -- Compilation failed with error message
  deriving Inhabited, Repr

instance : ToJson CompilationStatus where
  toJson
    | .none => Json.mkObj [("status", "none")]
    | .inProgress ms lines => Json.mkObj [("status", "inProgress"), ("elapsedMs", ms), ("logLines", toJson lines)]
    | .succeeded => Json.mkObj [("status", "succeeded")]
    | .failed err => Json.mkObj [("status", "failed"), ("error", err)]

instance : FromJson CompilationStatus where
  fromJson? j := do
    let status ← j.getObjValAs? String "status"
    match status with
    | "none" => return .none
    | "inProgress" =>
      let ms ← j.getObjValAs? Nat "elapsedMs"
      let lines := (j.getObjValAs? (Array CompilationLogLine) "logLines").toOption.getD #[]
      return .inProgress ms lines
    | "succeeded" => return .succeeded
    | "failed" => return .failed (← j.getObjValAs? String "error")
    | _ => throw s!"Unknown compilation status: {status}"

/-- A single point in the progress history time series for charting. -/
structure ProgressHistoryPoint where
  /-- Timestamp in milliseconds since start -/
  timestamp : Nat
  /-- BFS depth -/
  diameter : Nat
  /-- Total post-states generated -/
  statesFound : Nat
  /-- Unique states after dedup -/
  distinctStates : Nat
  /-- Frontier size -/
  queue : Nat
  deriving ToJson, FromJson, Inhabited, Repr

/-- Retention budgets apply independently to samples, compiler output and finished runs. -/
def maxProgressHistory : Nat := 512
def maxCompilationLogLines : Nat := 256
def maxCompilationLineChars : Nat := 2048
def maxRetainedResults : Nat := 64

/-- Keep a bounded recent window. Copying releases the array's discarded backing storage. -/
def pushRecent (items : Array α) (item : α) (limit : Nat) : Array α :=
  let items := items.push item
  items.extract (items.size - limit) items.size

/-- Progress information for model checking, using TLC-style terminology. -/
structure Progress where
  status : String := "Initializing..."
  /-- Length of the longest behavior found so far (BFS depth) -/
  diameter : Nat := 0
  /-- Total number of post-states generated (before deduplication) -/
  statesFound : Nat := 0
  /-- Number of unique states (after deduplication via fingerprinting) -/
  distinctStates : Nat := 0
  /-- States found but not yet explored (frontier size) -/
  queue : Nat := 0
  isRunning : Bool := true
  isCancelled : Bool := false
  startTimeMs : Nat := 0
  elapsedMs : Nat := 0
  /-- Status of background compilation (for handoff mode). -/
  compilationStatus : CompilationStatus := .none
  /-- Per-action statistics -/
  actionStats : List ActionStatDisplay := []
  /-- All possible action labels (for detecting never-enabled actions) -/
  allActionLabels : List String := []
  /-- Time-series history for charting progress over time -/
  history : Array ProgressHistoryPoint := #[]
  deriving ToJson, FromJson, Inhabited, Repr

/-- Mutable state of one run. Terminal publication and handoff share this lock. -/
structure ProgressState where
  progress : Progress
  resultJson : Option Lean.Json := none
  cancelToken : IO.CancelToken
  handoffRequested : Bool := false
  violationFound : Bool := false
  /-- A Stop request remains effective when handoff replaces the worker token. -/
  cancellationRequested : Bool := false

/-- A lifetime handle retained by active workers and panels. -/
structure ProgressRefs where
  state : Std.Mutex ProgressState

/-- Global registry mapping instance IDs to their progress refs.
    This allows passing quotable IDs through syntax while maintaining per-instance state. -/
initialize progressRegistry : IO.Ref (Std.HashMap Nat ProgressRefs) ← IO.mkRef {}
initialize nextInstanceId : IO.Ref Nat ← IO.mkRef 0

/-! ## Compiled Mode Progress Reporting

In compiled mode, the model checker runs as a separate process. Progress is communicated
via stderr (JSON lines), while the final result goes to stdout. -/

/-- Global flag indicating compiled mode (progress goes to stderr). -/
initialize compiledModeEnabled : IO.Ref Bool ← IO.mkRef false

/-- Start time for compiled mode progress tracking. -/
initialize compiledModeStartTime : IO.Ref Nat ← IO.mkRef 0

/-- Enable compiled mode progress reporting. Call this at the start of the compiled executable. -/
def enableCompiledModeProgress : IO Unit := do
  compiledModeEnabled.set true
  compiledModeStartTime.set (← IO.monoMsNow)

/-- Allocate a new progress instance and return its ID along with the cancel token.
    Takes all action labels for detecting never-enabled actions. -/
def allocProgressInstance (allActionLabels : List String := []) : IO (Nat × IO.CancelToken) := do
  let id ← nextInstanceId.modifyGet fun n => (n, n + 1)
  let cancelTk ← IO.CancelToken.new
  let refs : ProgressRefs := { state := ← Std.Mutex.new {
    progress := { startTimeMs := ← IO.monoMsNow, status := "Running...", allActionLabels }
    cancelToken := cancelTk
  } }
  progressRegistry.modify fun m => m.insert id refs
  return (id, cancelTk)

/-- Get the progress refs for an instance ID. -/
def getProgressRefs (instanceId : Nat) : IO (Option ProgressRefs) := do
  return (← progressRegistry.get)[instanceId]?

/-- Run action with refs if they exist, otherwise do nothing. -/
private def withRefs (instanceId : Nat) (f : ProgressRefs → IO Unit) : IO Unit := do
  if let some refs ← getProgressRefs instanceId then f refs

/-- Read progress and its result from one publication, including after registry eviction. -/
def getProgressSnapshot (refs : ProgressRefs) : IO (Progress × Option Lean.Json) :=
  refs.state.atomically fun ref => do
    let s ← ref.get
    return (s.progress, s.resultJson)

/-- Keep recent results addressable by ID. Existing panels/workers own their handles
    directly, so pruning an index entry does not invalidate a displayed result. -/
def pruneFinishedProgress : IO Unit := do
  let mut completed := #[]
  for (id, refs) in (← progressRegistry.get).toList do
    if !(← getProgressSnapshot refs).1.isRunning then completed := completed.push id
  completed := completed.qsort (· < ·)
  let expired := completed.extract 0 (completed.size - maxRetainedResults)
  progressRegistry.modify fun registry => expired.foldl (fun m id => m.erase id) registry

def getCancelToken (instanceId : Nat) : IO (Option IO.CancelToken) := do
  let some refs ← getProgressRefs instanceId | return none
  refs.state.atomically fun ref => return some (← ref.get).cancelToken

/-- Update progress while the run is active. Late worker reports cannot reopen a result. -/
def updateProgress (instanceId : Nat)
    (diameter statesFound distinctStates queue : Nat)
    (actionStats : List ActionStatDisplay := []) : IO Unit := do
  let now ← IO.monoMsNow
  withRefs instanceId fun refs => refs.state.atomically fun ref => do
    ref.modify fun s =>
      if !s.progress.isRunning then s else
      let p := s.progress
      let elapsed := now - p.startTimeMs
      let historyPoint : ProgressHistoryPoint := {
        timestamp := elapsed, diameter, statesFound, distinctStates, queue }
      { s with progress := { p with
        diameter, statesFound, distinctStates, queue, actionStats
        elapsedMs := elapsed, history := pushRecent p.history historyPoint maxProgressHistory } }
  if ← compiledModeEnabled.get then
    let startTime ← compiledModeStartTime.get
    let p : Progress := {
      status := "Running...", diameter, statesFound, distinctStates, queue, actionStats,
      startTimeMs := startTime, elapsedMs := now - startTime }
    IO.eprintln (toJson p).compress

/-- Accept a compiled progress report without overwriting lifecycle or compiler status. -/
def updateCompiledProgress (instanceId : Nat) (p : Progress) : IO Unit :=
  withRefs instanceId fun refs => refs.state.atomically fun ref => ref.modify fun s =>
    if !s.progress.isRunning then s else
    let old := s.progress
    let point : ProgressHistoryPoint := {
      timestamp := p.elapsedMs, diameter := p.diameter, statesFound := p.statesFound,
      distinctStates := p.distinctStates, queue := p.queue }
    { s with progress := { old with
      diameter := p.diameter, statesFound := p.statesFound
      distinctStates := p.distinctStates, queue := p.queue, actionStats := p.actionStats,
      elapsedMs := p.elapsedMs, history := pushRecent old.history point maxProgressHistory } }

def updateStatus (instanceId : Nat) (status : String) : IO Unit := withRefs instanceId fun refs => do
  let now ← IO.monoMsNow
  refs.state.atomically fun ref => ref.modify fun s =>
    if !s.progress.isRunning then s else
    { s with progress := { s.progress with status, elapsedMs := now - s.progress.startTimeMs } }

/-- Atomically publish the first terminal result. A discovered violation can still win
    while interpreted execution is stopping for handoff. Returns whether it was accepted. -/
def publishResult (instanceId : Nat) (resultJson : Lean.Json) : IO Bool := do
  let some refs ← getProgressRefs instanceId | return false
  let now ← IO.monoMsNow
  let accepted ← refs.state.atomically fun ref => do
    let s ← ref.get
    let violation := resultJson.getObjValD "result" == .str "found_violation"
    if !s.progress.isRunning ||
        (s.handoffRequested && !violation && resultJson.getObjValD "error" == .null) then return false
    ref.set { s with
      resultJson := some resultJson, handoffRequested := false
      progress := { s.progress with
        status := "Complete", isRunning := false
        elapsedMs := now - s.progress.startTimeMs } }
    return true
  if accepted then pruneFinishedProgress
  return accepted

def finishProgress (instanceId : Nat) (resultJson : Lean.Json) : IO Unit := do
  let _ ← publishResult instanceId resultJson

/-- Missing IDs are terminal, so an expired result cannot leave a panel polling forever. -/
def getProgress (instanceId : Nat) : IO Progress := do
  match ← getProgressRefs instanceId with
  | some refs => return (← getProgressSnapshot refs).1
  | none => return { status := "Result expired", isRunning := false }

def getResultJson (instanceId : Nat) : IO (Option Lean.Json) := do
  match ← getProgressRefs instanceId with
  | some refs => return (← getProgressSnapshot refs).2
  | none => return none

def isCancelled (instanceId : Nat) : IO Bool := do
  let some refs ← getProgressRefs instanceId | return false
  refs.state.atomically fun ref => do
    let s ← ref.get
    return s.cancellationRequested || (← s.cancelToken.isSet)

def requestCancellation (instanceId : Nat) : IO Unit := withRefs instanceId fun refs =>
  refs.state.atomically fun ref => do
    let s ← ref.get
    s.cancelToken.set
    ref.set { s with cancellationRequested := true }

/-- Cancellation is terminal and cannot replace an already published result. -/
def cancelProgress (instanceId : Nat) : IO Unit := do
  let now ← IO.monoMsNow
  withRefs instanceId fun refs => refs.state.atomically fun ref => ref.modify fun s =>
    if !s.progress.isRunning then s else
    { s with
      resultJson := some (Json.mkObj [("result", "cancelled")]), handoffRequested := false
      progress := { s.progress with
        status := "Cancelled", isRunning := false
        isCancelled := true, elapsedMs := now - s.progress.startTimeMs } }
  pruneFinishedProgress

partial def waitForResult (instanceId : Nat) (pollIntervalMs : Nat := 100) : IO (Option Lean.Json) := do
  let some refs ← getProgressRefs instanceId | return none
  loop refs
where
  loop (refs : ProgressRefs) : IO (Option Lean.Json) := do
    let (progress, result) ← getProgressSnapshot refs
    if progress.isRunning then
      IO.sleep pollIntervalMs.toUInt32
      loop refs
    else return result

/-! ## Handoff Coordination -/

def updateCompilationStatus (instanceId : Nat) (status : CompilationStatus) : IO Unit :=
  withRefs instanceId fun refs => refs.state.atomically fun ref => ref.modify fun s =>
    { s with progress := { s.progress with compilationStatus := status } }

def updateCompilationLog (instanceId : Nat) (elapsedMs : Nat) (line : String) (isError : Bool) : IO Unit :=
  withRefs instanceId fun refs => refs.state.atomically fun ref => ref.modify fun s =>
    if !s.progress.isRunning then s else
    let existingLines := match s.progress.compilationStatus with | .inProgress _ l => l | _ => #[]
    let newLine : CompilationLogLine := { timestamp := elapsedMs, content := (line.take maxCompilationLineChars).toString, isError }
    { s with progress := { s.progress with compilationStatus := .inProgress elapsedMs (pushRecent existingLines newLine maxCompilationLogLines) } }

def updateCompilationElapsed (instanceId : Nat) (elapsedMs : Nat) : IO Unit :=
  withRefs instanceId fun refs => refs.state.atomically fun ref => ref.modify fun s =>
    if !s.progress.isRunning then s else
    let lines := match s.progress.compilationStatus with | .inProgress _ l => l | _ => #[]
    { s with progress := { s.progress with compilationStatus := .inProgress elapsedMs lines } }

/-- Claim handoff only while the interpreted request is still eligible. -/
def requestHandoff (instanceId : Nat) : IO Bool := do
  let some refs ← getProgressRefs instanceId | return false
  refs.state.atomically fun ref => do
    let s ← ref.get
    if !s.progress.isRunning || s.handoffRequested || s.violationFound || s.cancellationRequested || (← s.cancelToken.isSet) then
      return false
    ref.set { s with handoffRequested := true }
    return true

def checkHandoffRequested (instanceId : Nat) : IO Bool := do
  let some refs ← getProgressRefs instanceId | return false
  refs.state.atomically fun ref => return (← ref.get).handoffRequested

def shouldStop (cancelToken : IO.CancelToken) (instanceId : Nat) : IO Bool :=
  return (← cancelToken.isSet) || (← checkHandoffRequested instanceId)

def setViolationFound (instanceId : Nat) : IO Unit := withRefs instanceId fun refs =>
  refs.state.atomically fun ref => ref.modify fun s => { s with violationFound := true }

def isViolationFound (instanceId : Nat) : IO Bool := do
  let some refs ← getProgressRefs instanceId | return false
  refs.state.atomically fun ref => return (← ref.get).violationFound

/-- Replace the worker token only if no terminal result or Stop request won the race. -/
def resetProgressForHandoff (instanceId : Nat) : IO (Option IO.CancelToken) := do
  let some refs ← getProgressRefs instanceId | return none
  let now ← IO.monoMsNow
  refs.state.atomically fun ref => do
    let s ← ref.get
    if !s.progress.isRunning || !s.handoffRequested || s.cancellationRequested || s.violationFound then
      return none
    let cancelToken ← IO.CancelToken.new
    ref.set { s with
      cancelToken, handoffRequested := false, resultJson := none
      progress := {
        status := "Restarting with compiled binary...", startTimeMs := now
        compilationStatus := .succeeded, allActionLabels := s.progress.allActionLabels } }
    return some cancelToken

section Utilities

variable {σ κ σₕ asm : Type} [fp : StateFingerprint σ σₕ] [inst : ActionStatUpdate κ asm]
  [Monad m] [MonadLiftT BaseIO m] [MonadLiftT IO m] [Repr κ]
  (progressInstanceId : Nat)

@[inline]
def updateProgressDuringBFS (ctx : BaseSearchContext σ κ σₕ asm) (qSize : Nat)
    (distinctNumState : Nat := ctx.log.size) : m Unit := do
  updateProgress progressInstanceId
    ctx.currentFrontierDepth ctx.statesFound distinctNumState qSize
    (inst.dump ctx.actionStatsMap)

-- NOTE: Any attempt to inline these functions might lead to **significant** performance
-- regression, due to certain reason

/-- A thin wrapper around `setViolationFound`.
    If we found a violation, mark it so handoff is prevented. -/
def trySetViolationFound (ctx : BaseSearchContext σ κ σₕ asm) : m Unit := do
  if let some (.earlyTermination cond) := ctx.finished then
    if EarlyTerminationReason.isViolation cond then setViolationFound progressInstanceId

def tryUpdateProgressWithNewFrontierDepth (oldFrontierDepth : Nat) (ctx : BaseSearchContext σ κ σₕ asm) (qSize : Nat) : m Unit := do
  if ctx.currentFrontierDepth > oldFrontierDepth then
    updateProgressDuringBFS progressInstanceId ctx qSize

inductive SearchPeriodicProgressUpdate where
  | searchCancelled
  | noUpdate
  | updateTime (newtime : Nat)

-- FIXME: Use `Option` to unify the two functions?
def checkCancellationWithPeriodicUpdate (lastUpdateTime updateTimeInterval : Nat)
  (cancelToken : IO.CancelToken) (ctx : BaseSearchContext σ κ σₕ asm) (qSize : Nat) : m SearchPeriodicProgressUpdate := do
  let now ← IO.monoMsNow
  if now - lastUpdateTime ≥ updateTimeInterval then
    if ← shouldStop cancelToken progressInstanceId then
      return .searchCancelled
    else
      updateProgressDuringBFS progressInstanceId ctx qSize
      return .updateTime now
  else
    return .noUpdate

def checkCancellationWithoutPeriodicUpdate (lastUpdateTime updateTimeInterval : Nat)
  (cancelToken : IO.CancelToken) : m SearchPeriodicProgressUpdate := do
  let now ← IO.monoMsNow
  if now - lastUpdateTime ≥ updateTimeInterval then
    if ← shouldStop cancelToken progressInstanceId then
      return .searchCancelled
    else
      return .updateTime now
  else
    return .noUpdate

end Utilities

end Veil.ModelChecker.Concrete
