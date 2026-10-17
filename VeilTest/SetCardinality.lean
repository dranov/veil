module

public import Veil

open Veil

#guard card ({1, 2, 2} : OrdList Nat) == 2
#guard TSet.countWhere ({1, 2, 3} : OrdArray Nat) (fun n => n > 1) == 2
#guard TSet.countDistinct ({1, 2, 3} : Std.ExtTreeSet Nat) (· % 2) == 2
#guard countFinite Bool (· = true) == 1
#guard card (∅ : OrdArray Nat) == 0

-- A complete enumeration need not be duplicate-free.
section
local instance : Enumeration Bool where
  allValues := [false, false, true, true]
  complete := by intro x; cases x <;> simp

#guard countFinite Bool (fun _ => True) == 2
end

example [TSet α κ] [LawfulTSet α κ] (s : κ) (h : card s = 0) (x : α) : x ∉ s :=
  (TSet.card_eq_zero_iff s).mp h x

veil module SetCardinality

type node
set_type Nodes : node
individual seen : Nodes

after_init { seen := ∅ }
action add (n : node) {
  require card seen < 2
  seen := seen ∪ {n}
}
invariant card seen ≤ 2

#gen_spec
#model_check interpreted { node := Fin 3 } {}
#model_check compiled { node := Fin 3 } {} (sequential := true)

end SetCardinality
