module

public import Veil

/-! Coherence is an ordinary checked invariant; undefined inputs remain valid. -/

veil module PartialFunctionVerification

type key
type value
partial function f : key → value
#gen_state

after_init { f K V := false }
action assign (k : key) (v : value) (b : Bool) { f k v := b }
#gen_spec
#guard_msgs(drop info) in
#check_invariants

-- An empty partial function is permitted: no totality obligation is added.
#guard_msgs(drop info) in
sat trace { assert (∀ k v, ¬ f k v) }

/-- info: ✅ No violation (explored 9 states) -/
#guard_msgs in
#model_check { key := Bool, value := Bool } {} (sequential := true)

end PartialFunctionVerification

set_option veil.printCounterexamples false

veil module PartialFunctionInvalidInit
partial function f : Bool → Bool
#gen_state
after_init { f X Y := true }
action idle { pure () }
#gen_spec
/--
error: Initialization must establish the invariant:
  doesNotThrow ... ✅
  f_coherence ... ❌
The following set of actions must preserve the invariant and successfully terminate:
  idle
    doesNotThrow ... ✅
    f_coherence ... ✅
-/
#guard_msgs in
#check_invariants
end PartialFunctionInvalidInit

veil module PartialFunctionInvalidAction
partial function f : Bool → Bool
#gen_state
after_init { f X Y := false }
action invalid { f false Y := true }
transition invalid_relational { ∀ (x y : Bool), f' x y }
#gen_spec
/--
error: Initialization must establish the invariant:
  doesNotThrow ... ✅
  f_coherence ... ✅
The following set of actions must preserve the invariant and successfully terminate:
  invalid_relational
    doesNotThrow ... ✅
    f_coherence ... ❌
  invalid
    doesNotThrow ... ✅
    f_coherence ... ❌
-/
#guard_msgs in
#check_invariants
end PartialFunctionInvalidAction

veil module PartialFunctionImmutableUnchecked
immutable partial function f : Bool → Bool
#gen_state
after_init { pure () }
action idle { pure () }
#gen_spec
/--
error: Initialization must establish the invariant:
  doesNotThrow ... ✅
  f_coherence ... ❌
The following set of actions must preserve the invariant and successfully terminate:
  idle
    doesNotThrow ... ✅
    f_coherence ... ✅
-/
#guard_msgs in
#check_invariants
end PartialFunctionImmutableUnchecked

veil module PartialFunctionImmutable
immutable partial function f : Bool → Bool
#gen_state
after_init { pure () }
action idle { pure () }
assumption f X Y ∧ f X Z → Y = Z
#gen_spec
#guard_msgs(drop info) in
#check_invariants
end PartialFunctionImmutable

veil module PartialFunctionArray
partial function f : Bool → Bool
veil_set_field_representation relation Veil.ArrayAsFinset

after_init { f X Y := false }
action assign (x y : Bool) (present : Bool) { f x y := present }
#gen_spec

/-- info: ✅ No violation (explored 9 states) -/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
/-- info: ✅ No violation (explored 9 states) -/
#guard_msgs in
#model_check compiled {} {} (sequential := true)
end PartialFunctionArray

veil module PartialFunctionDiagnostics
/-- error: a partial function must declare its output type, e.g. `partial function f (a : A) : B` -/
#guard_msgs in
partial function missing (x : Bool)
end PartialFunctionDiagnostics
