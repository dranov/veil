import Veil.Core.UI.Trace.TraceDisplay

open Lean

run_meta do
  let json := Json.mkObj [
    ("result", .str "cancelled"),
    ("diagnostics", toJson #["defaultedMissing: state.x", "decodeError: theory.y"])]
  let message ← (Veil.TraceDisplay.formatModelCheckingResult json).toString
  unless message.contains "defaultedMissing: state.x" && message.contains "decodeError: theory.y" do
    throwError "Trace text discarded the incomplete-projection diagnostics"
