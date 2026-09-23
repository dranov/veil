module
public import Veil.Frontend.Std
public meta import Veil.Frontend.Std
public meta import Veil.Frontend.DSL.Infra.SmtSimp
@[expose] public section
open Std Veil

/-- Extensional laws used by the collection vocabulary and comprehensions. -/
class LawfulTSet (α : outParam (Type u)) (κ : Type v) [TSet α κ] : Prop where
  ext {s t : κ} : (∀ x : α, x ∈ s ↔ x ∈ t) → s = t
  mem_intersection (x : α) (s t : κ) :
    x ∈ TSet.intersection s t ↔ x ∈ s ∧ x ∈ t
  mem_filter (x : α) (s : κ) (p : α → Bool) :
    x ∈ TSet.filter s p ↔ x ∈ s ∧ p x = true
  mem_ofList (x : α) (xs : List α) : x ∈ (TSet.ofList xs : κ) ↔ x ∈ xs
  toList_nodup (s : κ) : (TSet.toList s).Nodup
  count_eq_length (s : κ) : TSet.count s = (TSet.toList s).length

instance [Ord α] [TransOrd α] [LawfulEqOrd α] [DecidableEq α] :
    LawfulTSet α (ExtTreeSet α) where
  ext h := ExtTreeSet.ext_mem h
  mem_intersection := by intros; change _ ∈ ExtTreeSet.filter _ _ ↔ _; simp
  mem_filter := by intros; change _ ∈ ExtTreeSet.filter _ _ ↔ _; simp
  mem_ofList := by intros; change _ ∈ ExtTreeSet.ofList _ _ ↔ _; simp
  toList_nodup := by intros; exact ExtTreeMap.nodup_keys
  count_eq_length := by intros; exact ExtTreeSet.length_toList.symm

open OrdList in
instance [Ord α] [TransOrd α] [LawfulEqOrd α] [DecidableEq α] :
    LawfulTSet α (OrdList α) where
  ext := by
    intro s t h; apply Subtype.ext; apply sorted_unique s.property t.property
    intro x
    have hx := h x
    change sortedContains x s.val = true ↔ sortedContains x t.val = true at hx
    simpa only [sortedContains_iff _ _ s.property, sortedContains_iff _ _ t.property] using hx
  mem_intersection := by
    intro x s t
    change sortedContains x (sortedIntersectNoDup s.val t.val) = true ↔ _
    rw [sortedIntersectNoDup_contains x s.val t.val s.property t.property]
    exact Bool.and_eq_true_iff
  mem_filter := by
    intro x s p
    change sortedContains x (s.val.filter p) = true ↔ _
    rw [sortedContains_iff _ _ (sorted_filter _ _ s.property), List.mem_filter]
    change (x ∈ s.val ∧ p x = true) ↔ (sortedContains x s.val = true ∧ p x = true)
    rw [sortedContains_iff _ _ s.property]
  mem_ofList := by
    intro x xs
    change sortedContains x (ofList.inner xs) = true ↔ _
    rw [sortedContains_iff _ _ (ofList.inner_spec xs).1, (ofList.inner_spec xs).2]
  toList_nodup s := sorted_nodup s.property
  count_eq_length _ := rfl

open OrdList OrdArray in
instance [Ord α] [TransOrd α] [LawfulEqOrd α] [DecidableEq α] :
    LawfulTSet α (OrdArray α) where
  ext := by
    intro s t h; apply Subtype.ext; apply Array.toList_inj.mp
    apply sorted_unique s.property t.property
    intro x
    have hx := h x
    change sortedContains x s.val.toList = true ↔ sortedContains x t.val.toList = true at hx
    simpa only [sortedContains_iff _ _ s.property, sortedContains_iff _ _ t.property] using hx
  mem_intersection := by
    intro x s t
    change sortedContains x (ordArrayIntersect s.val t.val).toList = true ↔ _
    rw [ordArrayIntersect_toList, sortedIntersectNoDup_contains x _ _ s.property t.property]
    exact Bool.and_eq_true_iff
  mem_filter := by
    intro x s p
    change sortedContains x (s.val.filter p).toList = true ↔ _
    rw [Array.toList_filter, sortedContains_iff _ _ (sorted_filter _ _ s.property), List.mem_filter]
    change (x ∈ s.val.toList ∧ p x = true) ↔ (sortedContains x s.val.toList = true ∧ p x = true)
    rw [sortedContains_iff _ _ s.property]
  mem_ofList := by
    intro x xs
    change sortedContains x (ofList.inner xs).toArray.toList = true ↔ _
    rw [sortedContains_iff _ _ (ofList.inner_spec xs).1, (ofList.inner_spec xs).2]
  toList_nodup s := sorted_nodup s.property
  count_eq_length s := Array.size_eq_length_toList

namespace Veil

instance (priority := low) [TSet α κ] : EmptyCollection κ := ⟨TSet.empty⟩
instance (priority := low) [TSet α κ] : Singleton α κ := ⟨fun x => TSet.insert x TSet.empty⟩
instance (priority := low) [TSet α κ] : Insert α κ := ⟨TSet.insert⟩
instance (priority := low) [TSet α κ] : Union κ := ⟨TSet.union⟩
instance (priority := low) [TSet α κ] : Inter κ := ⟨TSet.intersection⟩
instance (priority := low) [TSet α κ] : SDiff κ := ⟨TSet.diff⟩
instance (priority := low) [TSet α κ] : HasSubset κ := ⟨TSet.isSubset⟩
instance [TSet α κ] (s t : κ) : Decidable (s ⊆ t) := inferInstanceAs (Decidable (TSet.isSubset s t))

end Veil

namespace TSet

variable [TSet α κ]

@[smtSimp] theorem subset_iff (s t : κ) :
    s ⊆ t ↔ ∀ x : α, x ∈ s → x ∈ t := Iff.rfl

@[simp, smtSimp] theorem subset_refl (s : κ) : s ⊆ s := fun _ h => h

@[simp] theorem mem_empty (x : α) : ¬x ∈ (∅ : κ) := by
  change ¬TSet.contains x TSet.empty = true
  simp [TSet.empty_contains]

@[simp] theorem mem_insert (x y : α) (s : κ) : x ∈ insert y s ↔ x = y ∨ x ∈ s := by
  change TSet.contains x (TSet.insert y s) = true ↔ _
  by_cases h : x = y
  · subst y; simp [TSet.contains_insert_self]
  · rw [TSet.contains_insert_other x y s h]; simp [h]; rfl

@[simp] theorem mem_singleton (x y : α) : x ∈ ({y} : κ) ↔ x = y := by
  change x ∈ insert y (∅ : κ) ↔ _
  simp

@[simp] theorem mem_union (x : α) (s t : κ) : x ∈ s ∪ t ↔ x ∈ s ∨ x ∈ t := by
  change TSet.contains x (TSet.union s t) = true ↔ _
  rw [TSet.contains_union]
  exact Bool.or_eq_true_iff

@[simp] theorem mem_diff (x : α) (s t : κ) : x ∈ s \ t ↔ x ∈ s ∧ x ∉ t := by
  change TSet.contains x (TSet.diff s t) = true ↔ _
  rw [TSet.contains_diff]
  simp [Membership.mem]

@[simp] theorem mem_inter [LawfulTSet α κ] (x : α) (s t : κ) :
    x ∈ s ∩ t ↔ x ∈ s ∧ x ∈ t := LawfulTSet.mem_intersection x s t

theorem ext [LawfulTSet α κ] {s t : κ} (h : ∀ x : α, x ∈ s ↔ x ∈ t) : s = t :=
  LawfulTSet.ext h

def Nonempty (s : κ) : Prop := ∃ x : α, x ∈ s

def Disjoint (s t : κ) : Prop := ∀ x : α, x ∈ s → x ∉ t

instance (s : κ) : Decidable (Nonempty s) :=
  decidable_of_iff (∃ x ∈ TSet.toList s, True) (by
    simp only [Nonempty, ← TSet.toList_contains_iff, and_true]; rfl)

instance (s t : κ) : Decidable (Disjoint s t) :=
  decidable_of_iff (∀ x ∈ TSet.toList s, x ∉ t) (by
    simp only [Disjoint, ← TSet.toList_contains_iff]; rfl)

end TSet

attribute [smtSimp] TSet.mem_empty TSet.mem_insert TSet.mem_singleton
  TSet.mem_union TSet.mem_diff TSet.mem_inter TSet.Nonempty TSet.Disjoint
