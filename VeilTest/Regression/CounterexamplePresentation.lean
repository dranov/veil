import Veil.Backend.SMT.Result

open Lean Meta Veil

run_meta do
  let raw : Smt.Model := {
    ctx := (← Smt.ModelContext.save)
    sorts := #[]
    values := #[(mkConst ``Nat, mkNatLit 9007199254740993)]
  }
  let htmlFailure ← annotateSmtModel raw (throwError "broken HTML") (pure (.str "projection"))
  unless htmlFailure.raw.values == raw.values && htmlFailure.structuredJson == .str "projection" &&
      htmlFailure.rawHtml.isNone && htmlFailure.diagnostics.size == 1 do
    throwError "HTML failure discarded solver evidence or structured projection"
  let projectionFailure ← annotateSmtModel raw (pure (.text "raw model")) (throwError "unsupported ToJson")
  unless projectionFailure.raw.values == raw.values && projectionFailure.structuredJson == .null &&
      projectionFailure.rawHtml.isSome && projectionFailure.diagnostics.size == 1 do
    throwError "Projection failure discarded solver evidence or raw HTML"
  let bothFail ← annotateSmtModel raw (throwError "broken HTML") (throwError "unsupported ToJson")
  unless bothFail.raw.values == raw.values && bothFail.diagnostics.size == 2 &&
      bothFail.rawText.contains "9007199254740993" do
    throwError "Both renderers failing discarded the copyable raw witness"
  let json := toJson (SmtResult.sat #[some bothFail])
  unless (json.compress.contains "9007199254740993") && (json.compress.contains "unsupported ToJson") do
    throwError "Result serialization lost the raw witness or diagnostics"
