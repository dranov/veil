module

public import VeilTest.ActionExecution
public meta import VeilTest.ActionExecution

/-! Partial functions are relation-backed, with checked coherence and no
totality requirement. These tests cover execution and both verification paths. -/

set_option linter.unusedVariables false

open VeilTest.ActionExecution

veil module PartialFunctionExecution

partial function owner : Bool → Bool
partial function multi (key : Bool) (slot : Bool) : Bool
individual marker : Bool

veil_set_field_representation relation Veil.CanonicalField

#gen_state

open scoped PartialFunctionExecution

procedure write (value : Bool) {
  owner false true := value
}

procedure erase_present {
  owner false false := false
}

procedure write_all {
  owner X true := true
}

procedure conditional_write_all {
  owner X false := X
}

procedure write_multiple_inputs {
  multi false true true := true
}

procedure replace_twice {
  owner false true := true
  owner false false := owner false true
  return owner false false && !owner false true
}

procedure produce {
  marker := true
  return true
}

procedure arrow_write {
  owner false true ← produce
}

procedure point_havoc {
  owner false true := *
}

procedure clear_row {
  owner false Y := false
}

procedure lookup {
  if value :| owner false value then
    return some value
  else
    return none
}

-- A local with the same name retains ordinary local assignment semantics.
#guard_msgs(drop warning) in
procedure local_shadow {
  let mut owner := fun (_ _ : Bool) => true
  owner false true := false
  return owner false false && !owner false true
}

def initial : State FieldConcreteType := {
  owner := fun x y => x == y
  multi := fun _ _ y => !y
  marker := false
}

def readOwner (state : State FieldConcreteType) : Bool → Bool → Bool := state.owner
def readMulti (state : State FieldConcreteType) : Bool → Bool → Bool → Bool := state.multi

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial (write true)) fun _ state =>
  !readOwner state false false && readOwner state false true &&
  !readOwner state true false && readOwner state true true && !state.marker

-- Writing false to an absent edge preserves the existing, different output.
#guard exactlyOneSuccess (__veil_exec_action% {} {} initial (write false)) fun _ state =>
  readOwner state false false && !readOwner state false true &&
  !readOwner state true false && readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial erase_present) fun _ state =>
  !readOwner state false false && !readOwner state false true &&
  !readOwner state true false && readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial write_all) fun _ state =>
  !readOwner state false false && readOwner state false true &&
  !readOwner state true false && readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial conditional_write_all) fun _ state =>
  !readOwner state false false && !readOwner state false true &&
  readOwner state true false && !readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial write_multiple_inputs) fun _ state =>
  !readMulti state false true false && readMulti state false true true &&
  readMulti state false false false && !readMulti state false false true &&
  readMulti state true false false && !readMulti state true false true &&
  readMulti state true true false && !readMulti state true true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial replace_twice) fun value state =>
  value && readOwner state false false && !readOwner state false true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial arrow_write) fun _ state =>
  state.marker && !readOwner state false false && readOwner state false true

#guard exactlyNSuccesses 2 (__veil_exec_action% {} {} initial point_havoc) fun _ state =>
  readOwner state false false != readOwner state false true &&
  !readOwner state true false && readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial clear_row) fun _ state =>
  !readOwner state false false && !readOwner state false true && readOwner state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial local_shadow) fun value state =>
  value && readOwner state false false && !readOwner state false true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial lookup) fun value _ =>
  value == some false

#guard exactlyOneSuccess (__veil_exec_action% {} {} (default : State FieldConcreteType) lookup)
  fun value _ => value == none

end PartialFunctionExecution

veil module PartialFunctionVerification

type node
partial function owner : node → node
partial function multi : node → node → node

-- Exercise implicit state generation and the default tree-set representation.
after_init {
  owner X Y := false
  multi X Y Z := false
}

action write (key value : node) (present : Bool) {
  owner key value := present
  multi key key value := present
}

action clear (key : node) {
  owner key Y := false
  multi key X Y := false
}

action write_all (value : node) {
  owner X value := true
}

#gen_spec
#gen_theorems

-- Coherence must become actual proof obligations, including initialization.
run_cmd do
  let env ← Lean.getEnv
  unless env.contains `PartialFunctionVerification.write_owner_coherence &&
      env.contains `PartialFunctionVerification.write_multi_coherence do
    throwError "partial-function coherence was not included in the verification conditions"

#check_invariants
#model_check interpreted { node := Fin 2 } {}

end PartialFunctionVerification

veil module PartialFunctionArray

partial function owner : Bool → Bool
veil_set_field_representation relation Veil.ArrayAsFinset

after_init { owner X Y := false }

action write (key value : Bool) { owner key value := true }
action erase (key value : Bool) { owner key value := false }

#gen_spec
#model_check interpreted {} {}
#model_check compiled {} {} (sequential := true)

end PartialFunctionArray

veil module PartialFunctionImmutable

type node
immutable partial function owner : node → node

after_init { pure () }
action skip { pure () }
invariant True

#gen_spec

-- An empty graph is a valid partial function: no totality axiom is generated.
/-- info: ✅ No violation (explored 1 states) -/
#guard_msgs in
#model_check interpreted { node := Fin 2 } { owner := fun _ _ => false }

/-- error: ❌ Violation: assumption_failure (violates: owner_coherence) -/
#guard_msgs in
#model_check interpreted { node := Fin 2 } { owner := fun _ _ => true }

end PartialFunctionImmutable

veil module PartialFunctionInvalidUpdate

partial function owner : Bool → Bool

after_init { owner X Y := false }

-- Bulk graph updates remain available, but cannot bypass coherence checking.
action corrupt { owner X Y := true }

transition corrupt_relational { ∀ (x y : Bool), owner' x y }

#gen_spec
set_option veil.printCounterexamples false

/--
error: Initialization must establish the invariant:
  doesNotThrow ... ✅
  owner_coherence ... ✅
The following set of actions must preserve the invariant and successfully terminate:
  corrupt_relational
    doesNotThrow ... ✅
    owner_coherence ... ❌
  corrupt
    doesNotThrow ... ✅
    owner_coherence ... ❌
-/
#guard_msgs in
#check_invariants

end PartialFunctionInvalidUpdate

veil module PartialFunctionInvalidInit

partial function owner : Bool → Bool

after_init { owner X Y := true }
action skip { pure () }

#gen_spec
set_option veil.printCounterexamples false

/--
error: Initialization must establish the invariant:
  doesNotThrow ... ✅
  owner_coherence ... ❌
The following set of actions must preserve the invariant and successfully terminate:
  skip
    doesNotThrow ... ✅
    owner_coherence ... ✅
-/
#guard_msgs in
#check_invariants

end PartialFunctionInvalidInit

veil module PartialFunctionDiagnostics

/-- error: a partial function needs at least one input type and an output type -/
#guard_msgs in
partial function missingInput : Bool

end PartialFunctionDiagnostics
