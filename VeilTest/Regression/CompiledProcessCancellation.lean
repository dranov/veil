import Veil.Frontend.DSL.Module.Util.ForModelChecker

open Veil.ModelChecker.Compilation

#eval show IO Unit from do
  -- A cancelled request must not spawn even an invalid executable.
  let stopped ← runProcessWithStatusCallback { cmd := "/nonexistent/veil-cancelled" }
    (fun _ => pure ()) (shouldCancel := pure true)
  unless stopped.interrupted do throw <| IO.userError "Pre-cancelled process was started"
  -- A shell child holds the pipes open. Cancellation must kill/reap the whole
  -- group, not merely the direct process, before reporting completion.
  unless System.Platform.isWindows do
    let cancel ← IO.CancelToken.new
    let start ← IO.monoMsNow
    let result ← runProcessWithStatusCallback
      { cmd := "sh", args := #["-c", "sleep 30 & echo ready; wait"] }
      (fun _ => pure ())
      (fun line _ _ => if line == "ready" then cancel.set else pure ())
      cancel.isSet
    unless result.interrupted && (← IO.monoMsNow) - start < 5000 do
      throw <| IO.userError "Cancellation did not promptly reap the process group"
