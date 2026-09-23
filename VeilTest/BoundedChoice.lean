module

public import Veil

open Veil

def selected := Enumeration.allValues
  (α := {x : Nat // x ∈ ({1, 2, 3, 4} : OrdList Nat) ∧ x % 2 = 0 ∧ x > 0})
#guard selected.map Subtype.val == [2, 4]
#guard (Enumeration.allValues
  (α := {x : Nat // x ∈ (∅ : OrdArray Nat) ∧ x > 0})).isEmpty
#guard (Enumeration.allValues
  (α := {x : Nat // x ∈ ({1, 3} : OrdArray Nat) ∧ x % 2 = 0})).isEmpty

#guard let source := ({1, 2, 3} : OrdList Nat)
  (Enumeration.allValues (α := {x : Nat // TSet.contains x source ∧ x > 1})).length = 2

veil module BoundedChoice

type item
set_type Items : item
immutable individual source : Items
immutable relation allowed : item → Bool
individual picked : Option item

after_init { picked := none }
action choose {
  let x :| x ∈ source ∧ allowed x
  picked := some x
}
action chooseContains {
  let x :| TSet.contains x source ∧ allowed x
  picked := some x
}
action chooseIf {
  if x :| x ∈ source ∧ allowed x then { picked := some x }
  else { picked := none }
}
action noMatch {
  if x :| x ∈ source ∧ False then { assert False; picked := some x }
  else { picked := none }
}
invariant picked = none ∨ ∃ x ∈ source, picked = some x ∧ allowed x

#gen_spec
/-- info: ✅ No violation (explored 3 states) -/
#guard_msgs in
#model_check interpreted { item := Nat }
  { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
/-- info: ✅ No violation (explored 3 states) -/
#guard_msgs in
#model_check compiled { item := Nat }
  { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 } (sequential := true)

end BoundedChoice
