import Veil.Frontend.DSL.Module.Util.ForModelChecker

open Veil.ModelChecker.Compilation

-- Dropping the third argument silently changed user configuration to 1.
#guard compiledArguments (some { numSubTasks := 3, thresholdToParallel := 7, numSubSteps := 4 }) ==
  #["3", "7", "4"]
#guard compiledArguments none == #[]
