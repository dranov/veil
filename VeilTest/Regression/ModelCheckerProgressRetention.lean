import Veil.Frontend.DSL.Module.Util.ForModelChecker

open Lean Veil.ModelChecker.Concrete Veil.ModelChecker.Compilation

#eval show IO Unit from do
  let (active, _) ← allocProgressInstance
  let (old, _) ← allocProgressInstance
  let some oldHandle ← getProgressRefs old | throw <| IO.userError "Missing run"
  let result := Json.mkObj [("result", "no_violation_found")]
  finishProgress old result
  for _ in [:maxRetainedResults + 1] do
    let (id, _) ← allocProgressInstance
    finishProgress id result
  unless (← getProgressRefs old).isNone && (← getProgressRefs active).isSome do
    throw <| IO.userError "Retention did not evict old results or evicted an active run"
  unless (← getProgressSnapshot oldHandle).2 == some result do
    throw <| IO.userError "Eviction invalidated an owned panel/worker handle"
  unless !(← getProgress old).isRunning do
    throw <| IO.userError "Expired results poll forever"
  for n in [:maxProgressHistory * 2] do updateProgress active n n n n
  for n in [:maxCompilationLogLines * 2] do
    updateCompilationLog active n (String.ofList (List.replicate 5000 'x')) false
  let p ← getProgress active
  unless p.history.size == maxProgressHistory && p.history.back!.diameter == maxProgressHistory * 2 - 1 do
    throw <| IO.userError "Progress history is unbounded or lost the latest sample"
  let .inProgress _ lines := p.compilationStatus | throw <| IO.userError "Missing compiler log"
  unless lines.size == maxCompilationLogLines && lines.all (·.content.length <= maxCompilationLineChars) do
    throw <| IO.userError "Compiler log retention is unbounded"
  cancelProgress active

#guard (retainOutputTail "0123456789" 5).length == 5
#guard retainOutputTail "small output" 100 == "small output"
#guard (retainOutputTail (String.ofList (List.replicate 100 'x') ++ "last error") 40).endsWith "last error"
