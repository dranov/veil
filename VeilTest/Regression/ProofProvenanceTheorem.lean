import VeilTest.Regression.ProofProvenanceSupport

open Lean Elab Command Veil

set_option warn.sorry false

run_cmd do
  Verifier.runManager
  Verifier.withVCManager fun ref => do
    for name in [`proofProvenanceAdmittedVC, `proofProvenanceReportVC] do
      let vc : VCData VCMetadata := {
        name, params := #[], statement := ← `(term| True), metadata := default
      }
      let (mgr, _) := (← ref.get).addVC vc {}
      ref.set mgr

-- There is no direct sorry syntax here; the imported dependency is admitted.
@[veil]
theorem proofProvenanceAdmittedVC : True := ProofProvenanceSupport.twiceIndirect

run_cmd do
  let mgr ← Verifier.vcManager.atomically fun ref => ref.get
  unless mgr._doneWith[0]? == some .error do
    throwError "@[veil] accepted a transitively admitted theorem"
  let result : Option (DischargerResult SmtResult) := mgr._dischargerResults[(0, 0)]?
  let some (.error errors _) := result
    | throwError "missing admission diagnostic"
  unless errors.any (fun (_, message) => message.compress.contains "depends on an admitted declaration") do
    throwError "transitive admission was not explained"

@[veil]
theorem proofProvenanceReportVC : True := True.intro

-- Custom dischargers can supply an unannotated proof witness. Result rendering
-- must inspect its dependencies, rather than checking only its expression tree.
run_cmd do
  let mgr ← Verifier.vcManager.atomically fun ref => ref.get
  let customResult : DischargerResult SmtResult :=
    .proven (some (mkConst `ProofProvenanceSupport.twiceIndirect)) none 0
  let mgr := { mgr with _dischargerResults := mgr._dischargerResults.insert (1, 0) customResult }
  let result ← liftCoreM <| mkVCResult mgr 1 (includeTheoremText := false)
  unless result.proofHasSorry && result.proofProvenance.any (fun p => p.hasAdmissions && !p.trustsSmt) do
    throwError "result reporting lost transitive admission provenance"
  let json := toJson result
  let .ok provenance := json.getObjValAs? ProofProvenance "proofProvenance"
    | throwError "serialized result lost proof provenance"
  unless provenance.hasAdmissions && !provenance.trustsSmt do
    throwError "serialized provenance misclassified an admitted helper"
