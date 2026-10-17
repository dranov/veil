module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
@[expose] public section
open Veil

namespace Veil

/-- Preserve a known enumeration bound when a choice adds more conditions.
In particular, membership on the left keeps selection inside the collection. -/
instance (priority := high) enumerationSubtypeAnd
    {α : Type u} (p q : α → Prop) [Enumeration {x : α // p x}] [DecidablePred q] :
    Enumeration {x : α // p x ∧ q x} where
  allValues := (Enumeration.allValues (α := {x : α // p x})).filterMap fun x =>
    if h : q x.val then some ⟨x.val, x.property, h⟩ else none
  complete := by
    rintro ⟨x, hp, hq⟩
    simp only [List.mem_filterMap]
    refine ⟨⟨x, hp⟩, Enumeration.complete _, ?_⟩
    simp [hq]

end Veil
