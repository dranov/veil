module

public import VeilTest.ActionExecution
public meta import VeilTest.ActionExecution

open Veil
open VeilTest.ActionExecution

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
set_type Pairs : item × item
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
action chooseReordered {
  let x :| allowed x ∧ (True ∧ x ∈ source)
  picked := some x
}
action chooseContainsReordered {
  let x :| allowed x ∧ TSet.contains x source
  picked := some x
}
action chooseIfReordered {
  if x :| allowed x ∧ x ∈ source then { picked := some x }
  else { picked := none }
}
action noMatchReordered {
  if x :| False ∧ x ∈ source then { assert False; picked := some x }
  else { picked := none }
}
action chooseTupleReordered {
  if (x, y) : item × item :| allowed x ∧ allowed y ∧ (x, y) ∈ (source ×ˢ source : Pairs) then
    picked := some x
  else
    picked := none
}
invariant picked = none ∨ ∃ x ∈ source, picked = some x ∧ allowed x

#gen_spec

-- Check each new action independently: other actions must not hide a lost choice.
#guard exactlyNSuccesses 2
  (__veil_exec_action% { item := Nat } { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
    { picked := none } chooseReordered)
  (fun _ s => s.picked == some 2 || s.picked == some 4)
#guard exactlyNSuccesses 2
  (__veil_exec_action% { item := Nat } { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
    { picked := none } chooseContainsReordered)
  (fun _ s => s.picked == some 2 || s.picked == some 4)
#guard exactlyNSuccesses 2
  (__veil_exec_action% { item := Nat } { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
    { picked := none } chooseIfReordered)
  (fun _ s => s.picked == some 2 || s.picked == some 4)
#guard exactlyOneSuccess
  (__veil_exec_action% { item := Nat } { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
    { picked := some 2 } noMatchReordered)
  (fun _ s => s.picked == none)
#guard exactlyNSuccesses 4
  (__veil_exec_action% { item := Nat } { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
    { picked := none } chooseTupleReordered)
  (fun _ s => s.picked == some 2 || s.picked == some 4)

/-- info: ✅ No violation (explored 3 states) -/
#guard_msgs in
#model_check interpreted { item := Nat }
  { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 }
/-- info: ✅ No violation (explored 3 states) -/
#guard_msgs in
#model_check compiled { item := Nat }
  { source := {1, 2, 3, 4}, allowed := fun n => n % 2 == 0 } (sequential := true)

end BoundedChoice
