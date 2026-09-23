module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
@[expose] public section
open Veil

namespace TSet

def unionList [TSet α κ] (sets : List κ) : κ := sets.foldr TSet.union TSet.empty

def intersectListWithin [TSet α κ] (ambient : κ) (sets : List κ) : κ :=
  sets.foldr TSet.intersection ambient

/-- Union a finite indexed family; an empty index set produces the empty set. -/
def unions [TSet ι ν] [TSet α κ] (indices : ν) (f : ι → κ) : κ :=
  unionList ((TSet.toList indices).map f)

/-- Union the members of a finite set of finite sets. -/
def flatten [TSet α κ] [TSet κ ν] (sets : ν) : κ := unions sets id

/-- Intersect an indexed family inside an explicit ambient set.
The empty family produces the ambient set. -/
def intersectionsWithin [TSet ι ν] [TSet α κ]
    (ambient : κ) (indices : ν) (f : ι → κ) : κ :=
  intersectListWithin ambient ((TSet.toList indices).map f)

@[simp] theorem mem_unionList [TSet α κ] (x : α) (sets : List κ) :
    x ∈ unionList sets ↔ ∃ s ∈ sets, x ∈ s := by
  induction sets with
  | nil => change x ∈ (∅ : κ) ↔ _; simp
  | cons s ss ih =>
    change x ∈ (s ∪ unionList ss) ↔ _
    simp [ih]

@[simp] theorem mem_intersectListWithin [TSet α κ] [LawfulTSet α κ]
    (x : α) (ambient : κ) (sets : List κ) :
    x ∈ intersectListWithin ambient sets ↔ x ∈ ambient ∧ ∀ s ∈ sets, x ∈ s := by
  induction sets with
  | nil => simp [intersectListWithin]
  | cons s ss ih =>
    change x ∈ TSet.intersection s (intersectListWithin ambient ss) ↔ _
    rw [LawfulTSet.mem_intersection, ih]
    simp only [List.mem_cons, forall_eq_or_imp]
    simp [and_left_comm]

@[simp] theorem mem_unions [TSet ι ν] [TSet α κ] (x : α) (indices : ν) (f : ι → κ) :
    x ∈ unions indices f ↔ ∃ i ∈ indices, x ∈ f i := by
  simp only [unions, mem_unionList, List.mem_map, ← TSet.toList_contains_iff]
  constructor
  · rintro ⟨_, ⟨i, hi, rfl⟩, hx⟩; exact ⟨i, hi, hx⟩
  · rintro ⟨i, hi, hx⟩; exact ⟨f i, ⟨i, hi, rfl⟩, hx⟩

@[simp] theorem mem_flatten [TSet α κ] [TSet κ ν] (x : α) (sets : ν) :
    x ∈ flatten sets ↔ ∃ s ∈ sets, x ∈ s := mem_unions x sets id

@[simp] theorem mem_intersectionsWithin [TSet ι ν] [TSet α κ] [LawfulTSet α κ]
    (x : α) (ambient : κ) (indices : ν) (f : ι → κ) :
    x ∈ intersectionsWithin ambient indices f ↔ x ∈ ambient ∧ ∀ i ∈ indices, x ∈ f i := by
  simp only [intersectionsWithin, mem_intersectListWithin, List.forall_mem_map,
    ← TSet.toList_contains_iff]
  rfl
end TSet

namespace Veil
scoped macro "⋃ " x:ident " ∈ " s:term ", " body:term : term =>
  `(TSet.unions $s (fun $x => $body))
scoped macro "⋂ " x:ident " ∈ " s:term " within " ambient:term ", " body:term : term =>
  `(TSet.intersectionsWithin $ambient $s (fun $x => $body))
end Veil

