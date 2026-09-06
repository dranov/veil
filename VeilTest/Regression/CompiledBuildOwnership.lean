import Veil.Frontend.DSL.Module.Util.ForModelChecker

open Veil.ModelChecker.Compilation

-- Repeated basenames, concurrent commands, and repeated requests must all own
-- separate directories. Check actual files, not just the naming convention.
#eval show IO Unit from do
  let first ← createBuildFolder "/project/a/Ring.lean" "first request" "Ring"
  let secondTask ← IO.asTask (createBuildFolder "/project/b/Ring.lean" "other file" "Ring")
  let thirdTask ← IO.asTask (createBuildFolder "/project/a/Ring.lean" "later command" "Ring")
  let second ← IO.ofExcept (← IO.wait secondTask)
  let third ← IO.ofExcept (← IO.wait thirdTask)
  try
    unless first != second && first != third && second != third do
      throw <| IO.userError "Compiled requests shared a build directory"
    unless (← IO.FS.readFile (first / "Model.lean")) == "first request" &&
        (← IO.FS.readFile (second / "Model.lean")) == "other file" &&
        (← IO.FS.readFile (third / "Model.lean")) == "later command" do
      throw <| IO.userError "A request overwrote another request's model"
  finally
    for path in [first, second, third] do IO.FS.removeDirAll path
