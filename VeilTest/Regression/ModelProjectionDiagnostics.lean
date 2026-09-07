import Veil.Backend.SMT.Model

open Lean Meta Veil

run_meta do
  let present : Std.HashMap Name Expr := { (`observed, mkNatLit 0) }
  let missing := missingModelValueDiagnostics #[`observed, `omitted] present "preState"
  unless missing.size == 1 && missing[0]!.contains "defaultedMissing: preState.omitted" do
    throwError "Absent and observed values were not distinguished"
  let diagnostics ← IO.mkRef missing
  let unavailable ← captureModelProjection diagnostics "theory.bad" (throwError "unsupported serializer")
  let available ← captureModelProjection diagnostics "preState.good" (pure (.str "model data"))
  unless available == .str "model data" && unavailable.compress.contains "$veilUnavailable" do
    throwError "A failed projection erased an independent section"
  let messages ← diagnostics.get
  unless messages.size == 2 && messages[1]!.contains "decodeError: theory.bad" do
    throwError "Decode failure was confused with an absent/defaulted value"
