module

public import Veil

open Veil

section Laws
variable [TSet α κ] [LawfulTSet α κ]

example (s t : κ) : s ∪ t = t ∪ s := by
  apply TSet.ext; intro x; simp [or_comm]
example (s t : κ) : s ∩ t ⊆ s := by
  intro x h; exact (TSet.mem_inter x s t).mp h |>.1
example (x : α) (s : κ) : x ∈ ({x} ∪ s : κ) := by simp
example (s t : κ) : TSet.Disjoint (s \ t) t := by
  intro x h; exact (TSet.mem_diff x s t).mp h |>.2
end Laws

#guard (({1, 2} : OrdList Nat) ∪ {2, 3}) = {1, 2, 3}
#guard (({1, 2} : OrdArray Nat) ∩ {2, 3}) = {2}
#guard (({1, 2} : Std.ExtTreeSet Nat) \ {2}) = {1}
#guard ({1, 2} : OrdList Nat) ⊆ {1, 2, 3}
#guard TSet.Disjoint ({1, 2} : OrdArray Nat) {3}
#guard TSet.Nonempty ({1} : Std.ExtTreeSet Nat)
#guard ¬TSet.Nonempty (∅ : OrdList Nat)

veil module SetVocabulary

type node
set_type Nodes : node
individual seen : Nodes

after_init { seen := ∅ }
action add (n : node) { seen := seen ∪ {n} }
action remove (n : node) { seen := seen \ {n} }

invariant seen ⊆ seen

-- Prove the generated VCs directly from the set interface. This avoids the
-- SMT backend's preprocessing of higher-order TSet fields and their laws.
macro_rules
  | `(tactic| veil_solve) => `(tactic|
      simp_all [TSet.isSubset, Subset, Veil.instHasSubsetOfTSet])

#gen_spec
#check_invariants
#model_check interpreted { node := Fin 2 } {}

end SetVocabulary
