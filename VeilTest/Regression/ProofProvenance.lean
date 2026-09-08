import VeilTest.Regression.ProofProvenanceSupport

open Lean Elab Command Veil

-- Imported theorem dependencies must carry the same provenance as local ones.
run_cmd do
  for name in [`ProofProvenanceSupport.admitted, `ProofProvenanceSupport.indirect,
      `ProofProvenanceSupport.twiceIndirect] do
    let provenance ← liftCoreM <| proofProvenance (mkConst name)
    unless provenance.hasAdmissions && !provenance.trustsSmt && !provenance.incomplete do
      throwError "missed transitive admission in {name}: {repr provenance}"
  for name in [`ProofProvenanceSupport.clean, `ProofProvenanceSupport.reconstructed] do
    let provenance ← liftCoreM <| proofProvenance (mkConst name)
    unless !provenance.hasAdmissions && !provenance.trustsSmt && !provenance.incomplete do
      throwError "misclassified reconstructed proof {name}: {repr provenance}"
  let trustedInfo ← liftCoreM <| proofProvenance (mkConst `ProofProvenanceSupport.trusted)
  unless trustedInfo.trustsSmt && !trustedInfo.hasAdmissions && !trustedInfo.incomplete do
    throwError "trusted SMT origin did not survive declaration export: {repr trustedInfo}"
  let mixed ← liftCoreM <| proofProvenance (mkConst `ProofProvenanceSupport.mixed)
  unless mixed.hasAdmissions && mixed.trustsSmt do
    throwError "mixed proof lost one source of trust: {repr mixed}"
  let userAxiom ← liftCoreM <| proofProvenance (mkConst `ProofProvenanceSupport.usesAxiom)
  unless userAxiom.axioms.contains "ProofProvenanceSupport.userAxiom" && !userAxiom.hasAdmissions do
    throwError "lost declared axiom: {repr userAxiom}"
  -- A trust marker in a caller must not relabel a manually admitted dependency.
  let masked ← liftCoreM <| proofProvenance (markTrustedSmtProof (mkConst `ProofProvenanceSupport.indirect))
  unless masked.hasAdmissions && !masked.trustsSmt do
    throwError "caller trust marker masked a manual admission"
  let cached ← liftCoreM <| cacheProofProvenance (mkConst `ProofProvenanceSupport.twiceIndirect)
  unless (cachedProofProvenance? cached).any (·.hasAdmissions) do
    throwError "missing cached witness provenance"
  -- Polling reuses the summary across discharger environment snapshots.
  let emptyEnv ← mkEmptyEnvironment
  let fromEmpty ← liftCoreM <| withEnv emptyEnv (proofProvenance cached)
  unless fromEmpty.hasAdmissions && !fromEmpty.incomplete do
    throwError "cached witness unexpectedly needed its original environment"
  let absent ← liftCoreM <| proofProvenance (mkConst `missingDeclaration)
  unless absent.incomplete do throwError "unknown dependency was silently treated as clean"
  let cachedAgain ← liftCoreM <| cacheProofProvenance cached
  unless cachedAgain == cached do throwError "cache operation must be idempotent"
