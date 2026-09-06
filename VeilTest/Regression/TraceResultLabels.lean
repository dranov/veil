import Veil.Core.UI.Trace.TraceDisplay
open Lean Elab Command

/-- info: ⚠️ No violation within search bounds (explored 2 states; depth bound 1); search incomplete -/
#guard_msgs in
run_cmd logInfo <| Veil.TraceDisplay.formatModelCheckingResult (json% {
  result: "no_violation_found", explored_states: 2,
  termination_reason: {kind: "early_termination", condition: {kind: "reached_depth_bound", depth: 1}}
})

/-- info: ✅ No violation; explored all reachable states (2 states) -/
#guard_msgs in
run_cmd logInfo <| Veil.TraceDisplay.formatModelCheckingResult (json% {
  result: "no_violation_found", explored_states: 2,
  termination_reason: {kind: "explored_all_reachable_states"}
})

/-- info: 💥 Error: Compiler exited 17 -/
#guard_msgs in
run_cmd logInfo <| Veil.TraceDisplay.formatModelCheckingResult (json% {error: "Compiler exited 17"})
