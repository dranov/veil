module

public import Veil

open Veil

#guard ({x ∈ ({1, 2, 3} : OrdList Nat) | x > 1}) = {2, 3}
#guard ({x ∈ (∅ : OrdArray Nat) | x > 1}) = ∅
#guard ({x : Bool | x = true} : OrdArray Bool) = {true}
#guard ({_x : Bool | False} : Std.ExtTreeSet Bool) = ∅

example [TSet α κ] [LawfulTSet α κ] (s : κ) (p : α → Prop)
    [DecidablePred p] (x : α) :
    x ∈ {y ∈ s | p y} ↔ x ∈ s ∧ p x := by simp

example [Enumeration α] [TSet α κ] [LawfulTSet α κ] (p : α → Prop)
    [DecidablePred p] (x : α) :
    x ∈ ({y : α | p y} : κ) ↔ p x := by simp

veil module SetComprehension

type node
set_type Nodes : node
immutable individual initial : Nodes
immutable relation allowed : node → Bool
individual filtered : Nodes

after_init { filtered := {n ∈ initial | allowed n} }
action restrict { filtered := {n ∈ filtered | allowed n} }
invariant filtered = {n ∈ initial | allowed n}

#gen_spec
-- No enumeration of Nat is available: bounded construction traverses initial.
#model_check interpreted { node := Nat } { initial := {1, 2, 3}, allowed := fun n => decide (n > 1) }
#model_check compiled { node := Nat } { initial := {1, 2, 3}, allowed := fun n => decide (n > 1) }
  (sequential := true)

end SetComprehension
