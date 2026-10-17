module

public import Veil

open Veil

#guard (⋃ n ∈ ({1, 2} : OrdList Nat), ({n, n + 1} : OrdList Nat)) = {1, 2, 3}
#guard (⋃ n ∈ (∅ : OrdList Nat), ({n} : OrdList Nat)) = ∅
#guard (⋂ n ∈ ({1, 2} : OrdList Nat) within ({0, 1, 2, 3} : OrdList Nat), {n, n + 1}) = {2}
#guard (⋂ n ∈ (∅ : OrdList Nat) within ({0, 1} : OrdList Nat), {n}) = {0, 1}
#guard TSet.flatten ({{1, 2}, {2, 3}} : OrdList (OrdList Nat)) = {1, 2, 3}
#guard TSet.flatten (∅ : OrdList (OrdArray Nat)) = ∅
#guard (⋃ s ∈ ({{1, 2}, {3}} : Std.ExtTreeSet (OrdArray Nat)), s) = {1, 2, 3}

example [TSet ι ν] [TSet α κ] (indices : ν) (f : ι → κ) (x : α) :
    x ∈ (⋃ i ∈ indices, f i) ↔ ∃ i ∈ indices, x ∈ f i := by simp

example [TSet ι ν] [TSet α κ] [LawfulTSet α κ]
    (indices : ν) (f : ι → κ) (ambient : κ) (x : α) :
    x ∈ (⋂ i ∈ indices within ambient, f i) ↔
      x ∈ ambient ∧ ∀ i ∈ indices, x ∈ f i := by simp

veil module IndexedSets

type item
set_type Items : item
set_type Families : Items
immutable individual family : Families
individual flattened : Items

after_init { flattened := ∅ }
action collect { flattened := ⋃ s ∈ family, s }
invariant flattened = ∅ ∨ flattened = TSet.flatten family

#gen_spec
#model_check interpreted { item := Nat } { family := {{1, 2}, {2, 3}} }
#model_check compiled { item := Nat } { family := {{1, 2}, {2, 3}} }
  (sequential := true)

end IndexedSets
