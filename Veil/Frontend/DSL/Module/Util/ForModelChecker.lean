import Veil.Core.UI.Widget.ProgressViewer

namespace Veil.ModelChecker.Compilation

open Lean Meta Elab Command

/-- Parse Lean's module header, including comments and all supported import forms. -/
def findPosAfterImports (src : String) : IO String.Pos.Raw := do
  let (_, state, messages) ← Parser.parseHeader (Parser.mkInputContext src "Model.lean")
  if messages.hasErrors then throw <| IO.userError "Cannot parse the compiled model's imports"
  return state.pos

/-- Replay the entire command prefix. Earlier model checks are suppressed by an option,
while declarations, local instances, options, and namespace commands remain intact. -/
def generateModelSourcePrefix (src : String) (commandStart commandEnd : String.Pos.Raw) : IO String := do
  let afterImports ← findPosAfterImports src
  let preamble := "\nset_option veil.__modelCheckCompileMode true\nset_option veil.__modelCheckCompileTarget false\n"
  return String.Pos.Raw.extract src 0 afterImports ++ preamble ++
    String.Pos.Raw.extract src afterImports commandStart ++
    "\nset_option veil.__modelCheckCompileTarget true\n" ++
    String.Pos.Raw.extract src commandStart commandEnd ++ "\n"

/-- Base directory for model checker build folders. This is an absolute path. -/
def getBuildBaseDir : IO System.FilePath := do
  let pwd ← IO.currentDir
  return pwd / ".lake" / "model_checker_builds"

initialize nextBuildId : IO.Ref Nat ← IO.mkRef 0

/-- Reserve a fresh build directory for this request. Exclusive creation also prevents
collisions between Lean processes or reused process IDs; no active build is overwritten. -/
def generateBuildFolderName (sourceFile : String) : IO System.FilePath := do
  let stem := System.FilePath.mk sourceFile |>.fileStem.getD "model"
  let baseDir ← getBuildBaseDir
  IO.FS.createDirAll baseDir
  repeat
    let id ← nextBuildId.modifyGet fun n => (n, n + 1)
    let path := baseDir / s!"{stem}_{← IO.Process.getPID}_{id}"
    try
      IO.FS.createDir path
      return path
    catch e =>
      unless ← path.pathExists do throw e

/-- Template for the `lakefile.lean` in the temp project. Note that it does
not only require the parent Veil project, but also *all the dependencies*;
otherwise the temp project will clone and build all of them. -/
def lakefileTemplate : String :=
s!"import Lake
open Lake DSL System

require Veil from \"../../..\"
require Cli from \"../../../.lake/packages/Cli\"
require cvc5 from \"../../../.lake/packages/cvc5\"
require smt from \"../../../.lake/packages/smt\"
require Loom from \"../../../.lake/packages/Loom\"
require mathlib from \"../../../.lake/packages/mathlib\"
require auto from \"../../../.lake/packages/auto\"
require plausible from \"../../../.lake/packages/plausible\"
require LeanSearchClient from \"../../../.lake/packages/LeanSearchClient\"
require importGraph from \"../../../.lake/packages/importGraph\"
require proofwidgets from \"../../../.lake/packages/proofwidgets\"
require aesop from \"../../../.lake/packages/aesop\"
require Qq from \"../../../.lake/packages/Qq\"
require batteries from \"../../../.lake/packages/batteries\"

package veilmodel

lean_lib Model where
  globs := #[Glob.one `Model]

lean_exe ModelCheckerMain where
  root := `ModelCheckerMain
  buildType := .relWithDebInfo
"

/-- Template for the ModelCheckerMain.lean in the temp project.
    Takes the namespace of the specification to open scoped instances. -/
def modelCheckerMainTemplate (specNamespace : String) : String :=
"import Model

set_option maxHeartbeats 6400000
set_option synthInstance.maxHeartbeats 200000
set_option synthInstance.maxSize 10000

open " ++ specNamespace ++ "

def flushStdoutAndStderr : IO Unit := do
  let stdout ← IO.getStdout
  let stderr ← IO.getStderr
  stdout.flush
  stderr.flush

def exitWhenParentDies : IO Unit := do
  let stdin ← IO.getStdin
  let _ ← stdin.readToEnd
  flushStdoutAndStderr
  IO.Process.forceExit 2

def main (args : List String) : IO Unit := do
  let _ ← IO.asTask (prio := .dedicated) exitWhenParentDies
  -- Enable progress reporting to stderr for the IDE to read
  Veil.ModelChecker.Concrete.enableCompiledModeProgress
  let pcfg : Option Veil.ModelChecker.ParallelConfig :=
    match args with
    | a :: b :: args' =>
      let numSubSteps := args'.head?.bind String.toNat? |>.getD 1
      match a.toNat?, b.toNat? with
      | some numSubTasks, some thresholdToParallel => some { numSubTasks, thresholdToParallel, numSubSteps : Veil.ModelChecker.ParallelConfig }
      | _, _ => none
    | _ => none
  -- Instance ID is not used in compiled mode, pass 0
  -- Cancel token is created locally; cancellation is handled by killing the process from outside
  let cancelTk ← IO.CancelToken.new
  let res ← modelCheckerResult pcfg 0 cancelTk
  IO.println s!\"{Lean.toJson res}\"
  flushStdoutAndStderr
  IO.Process.forceExit 0
"

/-- Create the temp build folder with all necessary files.
Returns the absolute path to the build folder. -/
def createBuildFolder (sourceFile : String) (modelSource : String) (specNamespace : String) : IO System.FilePath := do
  let veilPath ← IO.currentDir
  let buildFolder ← generateBuildFolderName sourceFile
  -- Create the build folder
  IO.FS.createDirAll buildFolder
  -- Write the lakefile
  IO.FS.writeFile (buildFolder / "lakefile.lean") lakefileTemplate
  -- Write the model source (renamed to Model.lean)
  IO.FS.writeFile (buildFolder / "Model.lean") modelSource
  -- Write the ModelCheckerMain.lean
  IO.FS.writeFile (buildFolder / "ModelCheckerMain.lean") (modelCheckerMainTemplate specNamespace)
  -- Create a minimal lean-toolchain file (copy from parent)
  let toolchainPath := veilPath / "lean-toolchain"
  if ← toolchainPath.pathExists then
    let toolchain ← IO.FS.readFile toolchainPath
    IO.FS.writeFile (buildFolder / "lean-toolchain") toolchain
  return buildFolder

/-- Result of running a compilation process. -/
structure ProcessResult where
  exitCode : UInt32
  stdout : String
  stderr : String
  interrupted : Bool := false
  deriving Inhabited

/-- Run a request-owned process, draining both streams before returning. Cancellation
kills the process group on POSIX so compiler descendants cannot keep pipes or artifacts alive. -/
def runProcessWithStatusCallback (cfg : IO.Process.SpawnArgs)
    (statusCallback : Nat → IO Unit)
    (lineCallback : String → Bool → Nat → IO Unit := fun _ _ _ => pure ())
    (shouldCancel : IO Bool := pure false) : IO ProcessResult := do
  if ← shouldCancel then return { exitCode := 0, stdout := "", stderr := "", interrupted := true }
  let startTime ← IO.monoMsNow
  let proc ← IO.Process.spawn { cfg with stdin := .piped, stdout := .piped, stderr := .piped, setsid := true }
  let stdoutAccum ← IO.mkRef ""
  let stderrAccum ← IO.mkRef ""
  let readLines (handle : IO.FS.Handle) (accum : IO.Ref String) (isError : Bool) : IO Unit := do
    while true do
      let line ← handle.getLine
      if line.isEmpty then break
      accum.modify (· ++ line)
      unless ← shouldCancel do
        lineCallback line.trimAsciiEnd.toString isError ((← IO.monoMsNow) - startTime)
  let stdoutTask ← IO.asTask (prio := .dedicated) (readLines proc.stdout stdoutAccum false)
  let stderrTask ← IO.asTask (prio := .dedicated) (readLines proc.stderr stderrAccum true)
  let waitTask ← IO.asTask (prio := .dedicated) proc.wait
  let mut interrupted := false
  try
    while !(← IO.hasFinished waitTask) do
      if ← shouldCancel then
        interrupted := true
        proc.kill
        break
      statusCallback ((← IO.monoMsNow) - startTime)
      IO.sleep 100
  finally
    -- Also reap on callback exceptions, not only on explicit cancellation.
    unless ← IO.hasFinished waitTask do proc.kill
    let _ ← IO.wait waitTask
    let _ ← IO.wait stdoutTask
    let _ ← IO.wait stderrTask
  interrupted := interrupted || (← shouldCancel)
  let _ ← IO.ofExcept (← IO.wait stdoutTask)
  let _ ← IO.ofExcept (← IO.wait stderrTask)
  let exitCode ← IO.ofExcept (← IO.wait waitTask)
  return { exitCode, stdout := ← stdoutAccum.get, stderr := ← stderrAccum.get, interrupted }

end Veil.ModelChecker.Compilation
