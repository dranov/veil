module

public import Veil

open Veil

#guard decide (∀ x ∈ ({1, 2, 3} : OrdList Nat), x < 4)
#guard decide (¬∀ x ∈ ({1, 2, 3} : OrdArray Nat), x < 3)
#guard decide (∃ x ∈ ({1, 2, 3} : Std.ExtTreeSet Nat), x = 3)
#guard decide (¬∃ x ∈ (∅ : OrdList Nat), x = 3)
#guard decide (∀ x ∈ (∅ : OrdList Nat), x = 3)
#guard decide (∀ x ∈ ({1, 2} : OrdList Nat), ∃ y ∈ ({2, 3} : OrdArray Nat), y = x + 1)
-- Bounded syntax continues to work with Lean lists, including dependent bounds.
#guard decide (∀ x ∈ [1, 2], ∃ y ∈ [x + 1], y > x)

example [TSet α κ] (s : κ) (p : α → Prop) :
    (∀ x ∈ s, p x) ↔ ∀ x, x ∈ s → p x := Iff.rfl
example [TSet α κ] (s : κ) (p : α → Prop) :
    (∃ x ∈ s, p x) ↔ ∃ x, x ∈ s ∧ p x := Iff.rfl

-- Preserve the meaning of bounds that refer to the quantified variable.
example : (∀ x ∈ ({x} : OrdList Nat), x = x) ↔
    (∀ x : Nat, x ∈ ({x} : OrdList Nat) → x = x) := Iff.rfl

-- The first introduced binder is the element, not a generated let binding.
example (s : OrdList Nat) : ∀ x ∈ s, x = x := by
  intro x hx
  rfl

def Nat.boundedSuccessors (n : Nat) : OrdList Nat := {n, n + 1}

-- Dotted occurrences also refer to the quantified variable.
example : (∀ x ∈ x.boundedSuccessors, x = (x : Nat)) ↔
    (∀ x : Nat, x ∈ x.boundedSuccessors → x = x) := Iff.rfl
example : (∃ x ∈ x.boundedSuccessors, x = (x : Nat)) ↔
    (∃ x : Nat, x ∈ x.boundedSuccessors ∧ x = x) := Iff.rfl

example : ∀ x ∈ (let x : OrdList Nat := {1}; x), x = x := by
  intro x hx
  rfl

veil module BoundedQuantifiers

type item
set_type Items : item
immutable individual source : Items
immutable relation allowed : item → Bool
individual checked : Bool

after_init { checked := false }
action allAllowed {
  require ∀ x ∈ source, allowed x
  checked := true
}
action someAllowed {
  require ∃ x ∈ source, allowed x
  checked := true
}
invariant checked → ∃ x ∈ source, allowed x

#gen_spec
-- Nat is infinite. Evaluation must only traverse source.
#model_check interpreted { item := Nat } { source := {1, 2}, allowed := fun n => n == 2 }
#model_check compiled { item := Nat } { source := {1, 2}, allowed := fun n => n == 2 }
  (sequential := true)

end BoundedQuantifiers
