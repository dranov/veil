module
public import Veil.Frontend.Collections.Basic
public import Veil.Frontend.SetType
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
    -- Testing a candidate must not constrain later candidates. Commit only
    -- after finding a unique carrier, so local instance order is irrelevant.
    if ← withoutModifyingState (isDefEq ty.getAppArgs[0]! elem) then
      let carrier := ty.getAppArgs[1]!
      unless ← candidates.anyM (fun c => withoutModifyingState (isDefEq carrier c)) do
        candidates := candidates.push carrier
  if candidates.size == 1 then
    let carrier := candidates[0]!
    discard <| isDefEq elem (← setElementType carrier)
    return carrier
  if candidates.size > 1 then
    throwError "ambiguous result set carrier; add a type annotation to the comprehension"
  try
    let carrier ← mkAppOptM ``Veil.DefaultSet #[some elem]
    discard <| setElementType carrier
    return carrier
  catch ex =>
    if ex.isInterrupt then throw ex
    throwError "cannot infer the result set carrier; add a type annotation or declare a set_type for the result elements"

scoped syntax (name := setImage) "{" term " | " ident " ∈ " term "}" : term
scoped syntax:70 (name := setProduct) term:71 " ×ˢ " term:70 : term

@[term_elab setImage] def elabSetImage : TermElab := fun stx expected? => do
  Term.tryPostponeIfNoneOrMVar expected?
  let `({$body:term | $x:ident ∈ $source:term}) := stx | throwUnsupportedSyntax
  let term ← `(TSet.image (fun $x => $body) $source)
  if let some expected := expected? then
    unless (← instantiateMVars expected).getAppFn.isMVar do
      return ← Term.elabTerm term expected?
  let sourceExpr ← Term.withSynthesize (postpone := .partial) <| Term.elabTerm source none
  let carrier ← instantiateMVars (← inferType sourceExpr)
  let elem ← setElementType carrier
  -- Allocate the result type outside the lambda's scope. In particular, the
  -- element type of a polymorphic body such as [] must not capture its binder.
  let outElem ← mkFreshTypeMVar
  let f ← Term.withSynthesize (postpone := .partial) <|
    Term.elabTerm (← `(fun $x => $body)) (some (← mkArrow elem outElem))
  let outCarrier ← inferImageCarrier outElem (some (elem, carrier))
  mkAppOptM ``TSet.image #[some elem, some carrier, some outElem, some outCarrier,
    none, none, some f, some sourceExpr]

@[term_elab setProduct] def elabSetProduct : TermElab := fun stx expected? => do
  Term.tryPostponeIfNoneOrMVar expected?
  let `($s:term ×ˢ $t:term) := stx | throwUnsupportedSyntax
  let term ← `(TSet.product $s $t)
  if let some expected := expected? then
    unless (← instantiateMVars expected).getAppFn.isMVar do
      return ← Term.elabTerm term expected?
  let sExpr ← Term.withSynthesize (postpone := .partial) <| Term.elabTerm s none
  let tExpr ← Term.withSynthesize (postpone := .partial) <| Term.elabTerm t none
  let α ← setElementType (← inferType sExpr)
  let β ← setElementType (← inferType tExpr)
  let pair ← mkAppM ``Prod #[α, β]
  let outCarrier ← inferImageCarrier pair
  mkAppOptM ``TSet.product #[some α, some (← inferType sExpr),
    some β, some (← inferType tExpr), some outCarrier, none, none, none,
    some sExpr, some tExpr]

end Veil

end
