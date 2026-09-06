import Veil.Core.Tools.ModelChecker.Concrete.Progress

open Lean Veil.ModelChecker.Concrete

private def require (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw <| IO.userError message

#eval show IO Unit from do
  let (id, _) ← allocProgressInstance
  let some refs ← getProgressRefs id | throw <| IO.userError "Missing run"
  let result := Json.mkObj [("result", "no_violation_found")]
  finishProgress id result
  cancelProgress id
  updateProgress id 99 99 99 99
  updateCompiledProgress id { diameter := 99 }
  let (progress, finalResult) ← getProgressSnapshot refs
  require (!progress.isRunning && !progress.isCancelled && progress.diameter == 0 && finalResult == some result)
    "Late cancellation/progress replaced a published result"
  require (!(← requestHandoff id)) "Completed run accepted handoff"

  -- Stop during the handoff gap must survive replacement of the worker token.
  let (stopped, _) ← allocProgressInstance
  require (← requestHandoff stopped) "Active run rejected handoff"
  requestCancellation stopped
  require (← isCancelled stopped) "Stop request was lost"
  require (← resetProgressForHandoff stopped).isNone "Handoff discarded Stop"
  cancelProgress stopped

  -- A violation discovered while the interpreted worker drains beats handoff.
  let (violated, _) ← allocProgressInstance
  require (← requestHandoff violated) "Active run rejected handoff"
  setViolationFound violated
  let violation := Json.mkObj [("result", "found_violation")]
  require (← publishResult violated violation) "Handoff discarded a discovered violation"
  require (← resetProgressForHandoff violated).isNone "Handoff reopened violation"
  require ((← waitForResult violated) == some violation) "Wrong violation result"

  -- Both status and result are observed under the same publication lock.
  for _ in [:100] do
    let (racing, _) ← allocProgressInstance
    let some racingRefs ← getProgressRefs racing | throw <| IO.userError "Missing run"
    let finish ← IO.asTask (finishProgress racing result)
    let cancel ← IO.asTask (cancelProgress racing)
    let _ ← IO.ofExcept (← IO.wait finish)
    let _ ← IO.ofExcept (← IO.wait cancel)
    let (p, r) ← getProgressSnapshot racingRefs
    require (!p.isRunning && r.isSome) "Terminal publication had no result"
    require (p.isCancelled == (r == some (Json.mkObj [("result", "cancelled")])))
      "Terminal status did not match its result"
