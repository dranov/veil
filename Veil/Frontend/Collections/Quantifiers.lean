module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Binders
@[expose] public section
open Veil

namespace TSet

/-- Decide bounded quantifiers by visiting the collection, not the element type. -/
instance (priority := high) decidableBAll [TSet α κ] (s : κ)
    (p : α → Prop) [DecidablePred p] : Decidable (∀ x ∈ s, p x) :=
  decidable_of_iff (∀ x ∈ TSet.toList s, p x) (by
    simp only [← TSet.toList_contains_iff]; rfl)

instance (priority := high) decidableBEx [TSet α κ] (s : κ)
    (p : α → Prop) [DecidablePred p] : Decidable (∃ x ∈ s, p x) :=
  decidable_of_iff (∃ x ∈ TSet.toList s, p x) (by
    simp only [← TSet.toList_contains_iff]; rfl)

end TSet

end

public meta section
open Lean Elab Term
namespace Veil

scoped syntax (name := boundedForall) (priority := high) "∀ " ident " ∈ " term ", " term : term
scoped syntax (name := boundedExists) (priority := high) "∃ " ident " ∈ " term ", " term : term

@[term_elab boundedForall] def elabBoundedForall : TermElab := fun stx expected? => do
  let `(∀ $x:ident ∈ $s:term, $p:term) := stx | throwUnsupportedSyntax
  elabBoundedQuantifier x s (fun s => `(∀ $x, $x ∈ $s → $p)) expected?

@[term_elab boundedExists] def elabBoundedExists : TermElab := fun stx expected? => do
  let `(∃ $x:ident ∈ $s:term, $p:term) := stx | throwUnsupportedSyntax
  elabBoundedQuantifier x s (fun s => `(Exists (fun $x => $x ∈ $s ∧ $p))) expected?
end Veil
