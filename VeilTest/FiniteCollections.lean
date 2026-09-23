module

public import Veil

open Veil

#guard (TSet.univ Bool : OrdList Bool) = {false, true}
#guard card (TSet.univ (Fin 0) : OrdList (Fin 0)) = 0
#guard typeCard (Fin 3) = 3
#guard typeCard Empty = 0
#guard ({2 ..= 4} : OrdArray Nat) = {2, 3, 4}
#guard ({4 ..= 2} : OrdList Nat) = ∅
#guard ({0 ..= 0} : Std.ExtTreeSet Nat) = {0}
#guard (TSet.intInterval (-2) 1 : OrdList Int) = ({-2, -1, 0, 1} : OrdList Int)
#guard (TSet.intInterval (-1) (-2) : OrdArray Int) = ∅

section
local instance : Enumeration Bool where
  allValues := [false, false, true, true]
  complete := by intro x; cases x <;> simp
#guard card (TSet.univ Bool : OrdArray Bool) = 2
end

example [TSet Nat κ] [LawfulTSet Nat κ] (lo hi : Nat) :
    card ({lo ..= hi} : κ) = hi + 1 - lo := TSet.card_interval lo hi

veil module FiniteUniverse

finite_type node
set_type Nodes : node
individual nodes : Nodes
individual amount : Nat

after_init { nodes := TSet.univ node; amount := typeCard node }
action reset { nodes := {_n : node | True}; amount := typeCard node }
invariant nodes = TSet.univ node ∧ amount = typeCard node

#gen_spec
#model_check interpreted { node := Fin 3 } {}
#model_check compiled { node := Fin 3 } {} (sequential := true)

end FiniteUniverse

veil module InclusiveIntervals

set_type Numbers : Nat
individual values : Numbers

after_init { values := {2 ..= 4} }
action extend { values := {1 ..= 4} }
invariant 4 ∈ values ∧ card values ≤ 4

#gen_spec
#model_check interpreted {} {}
#model_check compiled {} {} (sequential := true)

end InclusiveIntervals

veil module FiniteTypeDuplicate

type node_enum
/-- error: node_enum is already declared (as a moduleParameter) in module FiniteTypeDuplicate. Cannot redeclare it! -/
#guard_msgs in
finite_type node
-- Failure must not leave a partially declared sort behind.
type node

end FiniteTypeDuplicate
