module

public import Veil.Frontend.Collections.Basic

@[expose] public section

namespace Veil

/-- Number of distinct members of a finite set. -/
abbrev card [TSet α κ] (s : κ) : Nat := TSet.count s

/-- Count a predicate on an explicitly finite type. Enumeration may contain
duplicates, so normalize it before counting. -/
def countFinite (α : Type u) [Enumeration α] [DecidableEq α]
    (p : α → Prop) [DecidablePred p] : Nat :=
  (Enumeration.allValues (α := α)).eraseDups.countP (fun x => decide (p x))

end Veil

namespace TSet

/-- Count members satisfying a predicate without enumerating the element type. -/
def countWhere [TSet α κ] (s : κ) (p : α → Prop) [DecidablePred p] : Nat :=
  Veil.card (TSet.filter s (fun x => decide (p x)))

/-- Count distinct images, e.g. distinct senders in a set of messages. No
result-set carrier or enumeration of the output type is needed. -/
def countDistinct [TSet α κ] [DecidableEq β] (s : κ) (f : α → β) : Nat :=
  ((TSet.toList s).map f).eraseDups.length

variable [TSet α κ]

@[simp] theorem card_empty : Veil.card (∅ : κ) = 0 := TSet.empty_count

@[simp] theorem card_insert (x : α) (s : κ) :
    Veil.card (insert x s) = if x ∈ s then Veil.card s else Veil.card s + 1 :=
  TSet.count_insert x s

theorem card_eq_zero_iff [LawfulTSet α κ] (s : κ) :
    Veil.card s = 0 ↔ ∀ x : α, x ∉ s := by
  rw [Veil.card, LawfulTSet.count_eq_length, List.length_eq_zero_iff]
  simp only [List.eq_nil_iff_forall_not_mem, ← TSet.toList_contains_iff]
  rfl

end TSet
