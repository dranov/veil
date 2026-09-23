module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
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

namespace Veil
-- Elaborate independent bounds before introducing the quantified variable.
-- This prevents stuck synthetic instances for literals inside nested binders.
-- If a bound mentions the binder, preserve Lean's ordinary binding semantics.
scoped macro (priority := high) "∀ " x:ident " ∈ " s:term ", " p:term : term => do
  if (s.raw.find? (fun t => t.isIdent && t.getId == x.getId)).isSome then
    `(∀ $x, $x ∈ $s → $p)
  else
    `(let bound := $s; ∀ $x, $x ∈ bound → $p)
scoped macro (priority := high) "∃ " x:ident " ∈ " s:term ", " p:term : term => do
  if (s.raw.find? (fun t => t.isIdent && t.getId == x.getId)).isSome then
    `(Exists (fun $x => $x ∈ $s ∧ $p))
  else
    `(let bound := $s; Exists (fun $x => $x ∈ bound ∧ $p))
end Veil

