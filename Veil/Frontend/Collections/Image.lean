module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
public meta import Lean
@[expose] public section

namespace TSet

/-- Map a finite set, removing duplicate images in the result carrier. -/
def image [TSet α κ] [TSet β ν] (f : α → β) (s : κ) : ν := TSet.map s f

/-- Cartesian product over the two finite collections. -/
def product [TSet α κ] [TSet β ν] [TSet (α × β) μ] (s : κ) (t : ν) : μ :=
  TSet.ofList ((TSet.toList s).product (TSet.toList t))

@[simp] theorem mem_image [TSet α κ] [TSet β ν] [LawfulTSet β ν]
    (y : β) (s : κ) (f : α → β) :
    y ∈ (image f s : ν) ↔ ∃ x ∈ s, f x = y := by
  simp only [image, TSet.map, LawfulTSet.mem_ofList, List.mem_map,
    ← TSet.toList_contains_iff]
  rfl

@[simp] theorem mem_product [TSet α κ] [TSet β ν] [TSet (α × β) μ] [LawfulTSet (α × β) μ]
    (x : α) (y : β) (s : κ) (t : ν) :
    (x, y) ∈ (product s t : μ) ↔ x ∈ s ∧ y ∈ t := by
  simp only [product, LawfulTSet.mem_ofList, List.pair_mem_product,
    ← TSet.toList_contains_iff]
  rfl
end TSet

end

public meta section
open Lean Meta Elab Term

namespace Veil

private def setElementType (carrier : Expr) : TermElabM Expr := do
  let elem ← mkFreshTypeMVar
  discard <| synthInstance (mkApp2 (← mkConstWithFreshMVarLevels ``TSet) elem carrier)
  instantiateMVars elem

private def inferImageCarrier (elem : Expr) (source? : Option (Expr × Expr) := none) : TermElabM Expr := do
  if let some (sourceElem, sourceCarrier) := source? then
    if ← isDefEq elem sourceElem then return sourceCarrier
  let mut candidates : Array Expr := #[]
  for inst in (← getLocalInstances) do
    if inst.className != ``TSet then continue
    let ty ← instantiateMVars (← inferType inst.fvar)
    if !ty.isAppOfArity ``TSet 2 then continue
    if ← isDefEq ty.getAppArgs[0]! elem then
      let carrier := ty.getAppArgs[1]!
      unless ← candidates.anyM (fun c => isDefEq carrier c) do
        candidates := candidates.push carrier
  if candidates.size == 1 then return candidates[0]!
  if candidates.size > 1 then
    throwError "ambiguous result set carrier; add a type annotation to the comprehension"
  let elemStx ← Term.exprToSyntax elem
  try
    Term.elabType (← `(Std.ExtTreeSet $elemStx))
  catch ex =>
    if ex.isInterrupt then throw ex
    throwError "cannot infer the result set carrier; add a type annotation or declare a set_type for the result elements"

scoped syntax (name := setImage) "{" term " | " ident " ∈ " term "}" : term
scoped syntax:70 (name := setProduct) term:70 " ×ˢ " term:71 : term

@[term_elab setImage] def elabSetImage : TermElab := fun stx expected? => do
  Term.tryPostponeIfNoneOrMVar expected?
  let `({$body:term | $x:ident ∈ $source:term}) := stx | throwUnsupportedSyntax
  let term ← `(TSet.image (fun $x => $body) $source)
  if let some expected := expected? then
    unless (← instantiateMVars expected).isMVar do
      return ← Term.elabTerm term expected?
  let sourceExpr ← Term.elabTerm source none
  let carrier ← instantiateMVars (← inferType sourceExpr)
  let elem ← setElementType carrier
  let elemStx ← Term.exprToSyntax elem
  let f ← Term.elabTerm (← `(fun ($x : $elemStx) => $body)) none
  Term.synthesizeSyntheticMVarsNoPostponing
  let outElem ← forallBoundedTelescope (← inferType f) (some 1) fun _ ty => instantiateMVars ty
  let outCarrier ← inferImageCarrier outElem (some (elem, carrier))
  Term.elabTerm term (some outCarrier)

@[term_elab setProduct] def elabSetProduct : TermElab := fun stx expected? => do
  Term.tryPostponeIfNoneOrMVar expected?
  let `($s:term ×ˢ $t:term) := stx | throwUnsupportedSyntax
  let term ← `(TSet.product $s $t)
  if let some expected := expected? then
    unless (← instantiateMVars expected).isMVar do
      return ← Term.elabTerm term expected?
  let sExpr ← Term.elabTerm s none
  let tExpr ← Term.elabTerm t none
  let α ← setElementType (← inferType sExpr)
  let β ← setElementType (← inferType tExpr)
  let pair ← mkAppM ``Prod #[α, β]
  let outCarrier ← inferImageCarrier pair
  Term.elabTerm term (some outCarrier)

end Veil

end
