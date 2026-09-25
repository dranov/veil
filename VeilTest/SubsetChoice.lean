module

public import Veil

open Veil

#guard (TSet.subsetsOfSize ({1, 2, 3} : OrdList Nat) 2).length = 3
#guard (TSet.subsetsOfSize (∅ : OrdArray Nat) 0) = [∅]
#guard (TSet.subsetsOfSize ({1, 2} : OrdList Nat) 3).isEmpty
#guard decide (∃ s ⊆ ({1, 2} : OrdList Nat), card s = 2)
#guard decide (∀ s ⊆ ({1, 2} : OrdList Nat), card s ≤ 2)
#guard decide (¬∃ s ⊆ (∅ : OrdList Nat), TSet.Nonempty s)

-- A subset bound followed by additional predicates retains its finite candidates.
#guard (Enumeration.allValues (α := {s : OrdList Nat //
    s ⊆ ({1, 2, 3} : OrdList Nat) ∧ card s = 2})).length = 3

example [TSet α κ] : (∀ s ⊆ (s : κ), True) ↔ (∀ s : κ, s ⊆ s → True) := Iff.rfl

example [TSet α κ] (pool : κ) : ∀ s ⊆ pool, s ⊆ pool := by
  intro s hs
  exact hs

#guard decide (∀ s ⊆ ({1, 2} : OrdList Nat), ∃ t ⊆ s, t = s)

veil module SubsetChoice

type item
set_type Items : item
immutable individual pool : Items
individual chosen : Items

after_init { chosen := ∅ }
action anySubset {
  let s ⊆ pool
  chosen := s
}
action nonemptySubset {
  let s ⊆ (pool ∩ pool) :| TSet.Nonempty s
  assert card s > 0
  chosen := s
}
action pairSubset {
  let s ⊆ pool :| card s = 2
  assert card s = 2
  chosen := s
}
action impossibleSubset {
  if s :| s ⊆ pool ∧ card s > card pool then { assert False; chosen := s }
  else { chosen := ∅ }
}
invariant chosen ⊆ pool

#gen_spec
/-- info: ✅ No violation (explored 8 states) -/
#guard_msgs in
#model_check interpreted { item := Nat } { pool := {1, 2, 3} }
/-- info: ✅ No violation (explored 8 states) -/
#guard_msgs in
#model_check compiled { item := Nat } { pool := {1, 2, 3} } (sequential := true)

end SubsetChoice
