import Lean

namespace Veil.ModelChecker
open Lean

structure ParallelConfig where
  /-- Number of sub-tasks to split the worklist into. -/
  numSubTasks : Nat := 4
  /-- Threshold of worklist size to start parallel processing.
  If the worklist size is below this threshold, sequential processing
  is used. -/
  thresholdToParallel : Nat := 20
  -- /-- Number of states processed in a batch by each worker. -/
  -- batchSize : Nat := 512
  /-- Number of sub-steps per BFS layer. Each sub-step processes
  ~(1/numSubSteps) of the frontier, then runs the reduce step to update
  the global seen set. Higher values reduce redundant state exploration
  but add synchronization overhead. 1 = no sub-stepping (original behavior). -/
  numSubSteps : Nat := 1
deriving Inhabited, Repr

instance ParallelConfig.hasQuote : Quote ParallelConfig `term where
  quote cfg :=
    Syntax.mkCApp ``ParallelConfig.mk
      #[Syntax.mkNumLit (toString cfg.numSubTasks),
        Syntax.mkNumLit (toString cfg.thresholdToParallel),
        Syntax.mkNumLit (toString cfg.numSubSteps)]

end Veil.ModelChecker
