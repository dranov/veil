module
public import Veil.Frontend.Collections.Cardinality
public import Veil.Frontend.Collections.Choice
public meta import Veil.Frontend.Collections.Cardinality
public meta import Veil.Frontend.Collections.Binders
public meta import Veil.Frontend.DSL.Action.Syntax
@[expose] public section
open Veil

namespace TSet

/-- Enumerate exactly the subsets with the requested number of distinct members. -/
def subsetsOfSize [TSet α κ] (pool : κ) (size : Nat) : List κ :=
  (TSet.subsets pool).filter (fun s => Veil.card s == size)

@[simp] theorem mem_subsetsOfSize [TSet α κ] (s pool : κ) (size : Nat) :
    s ∈ subsetsOfSize pool size ↔ s ⊆ pool ∧ Veil.card s = size := by
  simp only [subsetsOfSize, List.mem_filter, TSet.subsets_iff, beq_iff_eq]
  rfl

instance (priority := high) decidableSubsetEx [TSet α κ] (pool : κ)
    (p : κ → Prop) [DecidablePred p] : Decidable (∃ s, s ⊆ pool ∧ p s) :=
  decidable_of_iff (∃ s ∈ TSet.subsets pool, p s) (by
    simp only [TSet.subsets_iff]; rfl)

instance (priority := high) decidableSubsetAll [TSet α κ] (pool : κ)
    (p : κ → Prop) [DecidablePred p] : Decidable (∀ s, s ⊆ pool → p s) :=
  decidable_of_iff (∀ s ∈ TSet.subsets pool, p s) (by
    simp only [TSet.subsets_iff]; rfl)

end TSet

end

public meta section
open Lean Elab Term
namespace Veil

scoped syntax (name := subsetForall) (priority := high) "∀ " ident " ⊆ " term ", " term : term
scoped syntax (name := subsetExists) (priority := high) "∃ " ident " ⊆ " term ", " term : term

@[term_elab subsetForall] def elabSubsetForall : TermElab := fun stx expected? => do
  let `(∀ $s:ident ⊆ $pool:term, $p:term) := stx | throwUnsupportedSyntax
  elabBoundedQuantifier s pool (fun pool => `(∀ $s, $s ⊆ $pool → $p)) expected?

@[term_elab subsetExists] def elabSubsetExists : TermElab := fun stx expected? => do
  let `(∃ $s:ident ⊆ $pool:term, $p:term) := stx | throwUnsupportedSyntax
  elabBoundedQuantifier s pool (fun pool => `(Exists (fun $s => $s ⊆ $pool ∧ $p))) expected?

scoped syntax (name := letSubset) (priority := high)
  "let " ident " ⊆ " term (" :| " term)? : doElem
macro_rules
  | `(doElem| let $s:ident ⊆ $pool:term $[:| $p:term]?) => do
    match p with
    | none => `(doElem| let $s:ident :| $s ⊆ $pool)
    | some p => `(doElem| let $s:ident :| $s ⊆ $pool ∧ $p)
end Veil
