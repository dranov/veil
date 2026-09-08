import Lean
import Lean.Util.CollectAxioms

namespace Veil
open Lean

/-- Informational provenance of a proof, including declaration dependencies.
`trustsSmt` records marked Veil SMT admissions, not every use of `sorryAx`.
Other axioms remain visible; absence of admissions is not absence of axioms. -/
structure ProofProvenance where
  hasAdmissions : Bool := false
  trustsSmt : Bool := false
  axioms : Array String := #[]
  incomplete : Bool := false
  deriving Inhabited, BEq, Repr, ToJson, FromJson, Server.RpcEncodable

private def trustedSmtKey : Name := `veil.trustedSmtProof
private def cachedProvenanceKey : Name := `veil.cachedProofProvenance

/-- Mark the proof goal handed to a trust-enabled Veil SMT call. This metadata
is diagnostic, not a kernel certificate or an authorization mechanism. -/
def markTrustedSmtProof (proof : Expr) : Expr :=
  .mdata (MData.empty.insert trustedSmtKey (.ofBool true)) proof

/-- Summaries travel with witnesses across asynchronous elaboration environments,
so rendering does not repeatedly traverse theorem bodies or use a stale environment. -/
def cachedProofProvenance? : Expr → Option ProofProvenance
  | .mdata md _ => do
    let encoded := md.getString cachedProvenanceKey
    let json ← (Json.parse encoded).toOption
    (fromJson? json).toOption
  | _ => none

private structure ProvenanceState where
  seen : NameSet := {}
  result : ProofProvenance := {}

private def mergeProvenance (a b : ProofProvenance) : ProofProvenance := {
  hasAdmissions := a.hasAdmissions || b.hasAdmissions
  trustsSmt := a.trustsSmt || b.trustsSmt
  axioms := (b.axioms.foldl (fun acc ax => if acc.contains ax then acc else acc.push ax) a.axioms).qsort (· < ·)
  incomplete := a.incomplete || b.incomplete
}

mutual
  private partial def collectProofExpr (e : Expr) (trusted : Bool := false) :
      StateT ProvenanceState CoreM Unit := do
    if let some cached := cachedProofProvenance? e then
      modify fun s => { s with result := mergeProvenance s.result cached }
      return
    match e with
    | .mdata md body => collectProofExpr body (trusted || md.getBool trustedSmtKey)
    | .const name _ =>
      if name == ``sorryAx then
        modify fun s => { s with result := { s.result with
          hasAdmissions := s.result.hasAdmissions || !trusted
          trustsSmt := s.result.trustsSmt || trusted } }
      else
        -- A referenced declaration has its own provenance. A trust marker in the
        -- caller must not turn an admitted helper into an SMT-produced proof.
        collectProofConstant name
    | .app f a => collectProofExpr f trusted; collectProofExpr a trusted
    | .lam _ t b _ | .forallE _ t b _ => collectProofExpr t trusted; collectProofExpr b trusted
    | .letE _ t v b _ => collectProofExpr t trusted; collectProofExpr v trusted; collectProofExpr b trusted
    | .proj name _ b => collectProofConstant name; collectProofExpr b trusted
    | .mvar _ | .fvar _ => modify fun s => { s with result.incomplete := true }
    | .bvar _ | .sort _ | .lit _ => pure ()

  private partial def collectProofConstant (name : Name) :
      StateT ProvenanceState CoreM Unit := do
    if (← get).seen.contains name then return
    modify fun s => { s with seen := s.seen.insert name }
    let env := (← getEnv).setExporting false
    let some info := env.find? name
      | modify fun s => { s with result.incomplete := true }
    -- Lean caches imported declarations' transitive axiom dependencies. Most
    -- dependencies can therefore be summarized without traversing their bodies.
    let axioms ← collectAxioms name
    let otherAxioms := axioms.filter (· != ``sorryAx) |>.map (·.toString)
    modify fun s => { s with result := mergeProvenance s.result { axioms := otherAxioms } }
    unless axioms.contains ``sorryAx do return
    collectProofExpr info.type
    if let some value := info.value? (allowOpaque := true) then
      collectProofExpr value
    else if let .inductInfo value := info then
      value.ctors.forM collectProofConstant
end

/-- Inspect direct and transitive dependencies, reusing an attached summary. -/
def proofProvenance (proof : Expr) : CoreM ProofProvenance := do
  let (_, state) ← (collectProofExpr proof).run {}
  return state.result

/-- Compute once, while the witness's declaration environment is available. -/
def cacheProofProvenance (proof : Expr) : CoreM Expr := do
  if (cachedProofProvenance? proof).isSome then return proof
  let provenance ← proofProvenance proof
  return .mdata (MData.empty.insert cachedProvenanceKey
    (.ofString (toJson provenance).compress)) proof

end Veil
