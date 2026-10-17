module

public import Veil

open Veil

#guard ({x % 2 | x ∈ ({1, 2, 3} : OrdList Nat)}) = {0, 1}
#guard ({decide (x > 1) | x ∈ ({1, 2, 3} : OrdList Nat)}) =
  ({false, true} : Std.ExtTreeSet Bool)
#guard (({1, 2} : OrdList Nat) ×ˢ ({true} : OrdList Bool)) =
  ({(1, true), (2, true)} : Std.ExtTreeSet (Nat × Bool))
#guard ((∅ : OrdArray Nat) ×ˢ ({true} : OrdList Bool) : OrdList (Nat × Bool)) = ∅

example [TSet α κ] [TSet β ν] (s : κ) (f : α → β) : True := by
  let image := {f x | x ∈ s}
  have : ν := image
  trivial

example [TSet α κ] [TSet β ν] [TSet β μ] (s : κ) (f : α → β) : True := by
  fail_if_success let ambiguous := {f x | x ∈ s}
  let selected : ν := {f x | x ∈ s}
  have : ν := selected
  trivial

-- Polymorphic bodies can obtain their result type from a unique carrier.
example [TSet (List Nat) ν] : True := by
  let image := {[] | _x ∈ ({1} : OrdList Nat)}
  have : ν := image
  trivial

-- Candidate probing must not commit the first matching element type.
example [TSet (List Nat) ν] [TSet (List Bool) μ] : True := by
  fail_if_success let ambiguous := {[] | _x ∈ ({1} : OrdList Nat)}
  let selected : μ := {[] | _x ∈ ({1} : OrdList Nat)}
  have : μ := selected
  trivial

example [TSet (List Bool) μ] [TSet (List Nat) ν] : True := by
  fail_if_success let ambiguous := {[] | _x ∈ ({1} : OrdList Nat)}
  trivial

-- Products associate like their element type, α × β × γ.
example [TSet α κ] [TSet β ν] [TSet γ μ]
    [TSet (β × γ) bc] [TSet (α × β × γ) abc]
    (a : κ) (b : ν) (c : μ) : True := by
  let product := a ×ˢ b ×ˢ c
  have : abc := product
  trivial

/-- error: cannot infer the result set carrier; add a type annotation or declare a set_type for the result elements -/
#guard_msgs in
def missingImageCarrier {β : Type} (f : Nat → β) :=
  {f x | x ∈ ({1} : OrdList Nat)}

example [TSet α κ] [TSet β ν] [LawfulTSet β ν] (s : κ) (f : α → β) (y : β) :
    y ∈ ({f x | x ∈ s} : ν) ↔ ∃ x ∈ s, f x = y := by simp

-- Function-valued images must retain the entire function type as their element type.
example {β γ : Type} [TSet α κ] [TSet (β → γ) ν] (s : κ) (f : α → β → γ) : True := by
  let image := {f x | x ∈ s}
  have : ν := image
  trivial

veil module SetImage

type node
set_type Nodes : node

@[veil_decl]
structure Packet (n : Type) where
  sender : n
  receiver : n
  deriving DecidableEq, Inhabited

set_type Packets : Packet node
immutable individual members : Nodes
immutable individual sender : node
individual packets : Packets

after_init { packets := ∅ }
action broadcast {
  packets := {{ sender := sender, receiver := n } | n ∈ members}
}
invariant packets = ∅ ∨ packets = {Packet.mk sender n | n ∈ members}

#gen_spec
#model_check interpreted { node := Fin 2, Packets := OrdList (Packet (Fin 2)) }
  { members := {(0 : Fin 2), (1 : Fin 2)}, sender := 0 }
#model_check compiled { node := Fin 2, Packets := OrdList (Packet (Fin 2)) }
  { members := {(0 : Fin 2), (1 : Fin 2)}, sender := 0 } (sequential := true)

end SetImage
