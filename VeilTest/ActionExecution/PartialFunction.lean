module

public import VeilTest.ActionExecution
public meta import VeilTest.ActionExecution

/-!
Concrete tests for assignments to `partial function`s. Each assignment
`f a b := v`, whatever its right-hand side, must behave exactly as
`f a Y := false` followed by the relation assignment `f a b := v`. Every
procedure below is paired with a spelled-out reference procedure over an
ordinary relation, and the two must produce the same results.
-/

set_option linter.unusedVariables false

open VeilTest.ActionExecution

veil module ActionExecutionPartialFunction

-- `f` is the partial function, `r` the relation spelling out its semantics.
partial function f : Bool → Bool
relation r : Bool → Bool → Bool
-- Binder syntax, and a partial function without inputs.
partial function g (k : Bool) (k' : Bool) : Bool
partial function c : Bool
relation plain : Bool → Bool → Bool
individual marker : Bool

veil_set_field_representation relation Veil.CanonicalField

#gen_state

open scoped ActionExecutionPartialFunction

procedure point {
  f true false := true
  r true Y := false
  r true false := true
}

-- Clearing applies to *any* right-hand side, including `false`.
procedure point_false {
  f true false := False
  r true Y := false
  r true false := False
}

-- The right-hand side reads the cleared state.
procedure state_dependent_rhs {
  f true false := f true true
  r true Y := false
  r true false := r true true
}

-- Clear all selected inputs together, before reading any of them.
procedure universal_rhs {
  f X false := f (!X) true
  r X Y := false
  r X false := r (!X) true
}

procedure output_reads_state {
  f true (f true true) := true
  r true Y := false
  r true (r true true) := true
}

procedure whole_reads_state {
  f := fun x y => f x y
  r X Y := false
  r := fun x y => r x y
}

-- Local mutations in an arrow RHS must survive the enclosing branch.
procedure arrow_rhs_branch {
  let mut changed := false
  if true then
    f true false ← do
      changed := true
      pure (f true true)
  else
    pure ()
  return changed
}

procedure universal_input {
  f X true := true
  r X Y := false
  r X true := true
}

-- A universal output is cleared, then written: here, made incoherent.
procedure universal_output {
  f true Y := true
  r true Y := false
  r true Y := true
}

procedure whole {
  f := fun a b => a && b
  r X Y := false
  r := fun a b => a && b
}

procedure omitted_output {
  f false := fun b => !b
  r false Y := false
  r false := fun b => !b
}

procedure binders_and_no_input {
  g true false true := true
  c true := true
}

procedure observe_f { return f true true }
procedure observe_r { return r true true }
procedure observe_whole_f { return f }
procedure observe_whole_r { return r }

procedure whole_arrow {
  f ← observe_whole_f
  r X Y := false
  r ← observe_whole_r
}

procedure arrow {
  f true true ← observe_f
  r true Y := false
  r true true ← observe_r
}

/- Each procedure returns `true` exactly if it observes `true true` cleared,
then writes `true false`. -/
procedure cleared_then_set_f {
  let cleared := !f true true
  f true false := true
  return cleared
}

procedure cleared_then_set_r {
  let cleared := !r true true
  r true Y := false
  r true false := true
  return cleared
}

/- The called procedure observes the cleared state, and the write after the
call is an ordinary relation write, with no second clear: `f true false`, set
by the call, stays set. -/
procedure arrow_call_writes {
  f true true ← cleared_then_set_f
  r true Y := false
  r true true ← cleared_then_set_r
}

-- The same for a call embedded in a larger right-hand side.
procedure nested_action {
  f true true := (← cleared_then_set_f) && !marker
  r true Y := false
  r true true := (← cleared_then_set_r) && !marker
}

-- Havoc is cleared too: two outcomes, both with `f true true` cleared.
procedure havoc {
  f true false := *
  return f true true
}

-- Fixed indices are evaluated on the state each statement executes in.
procedure index_reads_state {
  f (f true true) false := true
  r (r true true) Y := false
  r (r true true) false := true
}

-- A `let mut` local named `f` shadows the partial function: no clearing.
/-- warning: local `f` shadows mutable state component `f`; references to this name resolve to the local -/
#guard_msgs in
procedure local_shadow {
  let mut f := fun (_ _ : Bool) => true
  f true false := false
  return (f true true, f true false)
}

-- Control flow: a write inside a branch, with a local mutated alongside it.
procedure in_branch (b : Bool) {
  let mut seen := false
  if b then
    f true false := true
    seen := true
  else
    r true Y := false
  return seen
}

-- Ordinary relations are not cleared.
procedure plain_write {
  plain true false := true
}

def initial : State FieldConcreteType := {
  f := fun a b => a && b
  r := fun a b => a && b
  g := fun _ _ out => out
  c := fun b => !b
  plain := fun _ _ => true
  marker := false
}

def readF (state : State FieldConcreteType) : Bool → Bool → Bool :=
  (state.f : Bool → Bool → Bool)

def readR (state : State FieldConcreteType) : Bool → Bool → Bool :=
  (state.r : Bool → Bool → Bool)

def allBools : List Bool := [false, true]

/-- `f` agrees with `r`, its spelled-out reference. -/
def fIsR (state : State FieldConcreteType) : Bool :=
  allBools.all fun a => allBools.all fun b => readF state a b == readR state a b

def fIs (state : State FieldConcreteType) (expected : Bool → Bool → Bool) : Bool :=
  allBools.all fun a => allBools.all fun b => readF state a b == expected a b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial point) fun _ state =>
  fIsR state && fIs state fun a b => if a then !b else false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial point_false) fun _ state =>
  fIsR state && fIs state fun _ _ => false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial state_dependent_rhs) fun _ state =>
  fIsR state && fIs state fun _ _ => false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial universal_input) fun _ state =>
  fIsR state && fIs state fun _ b => b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial universal_output) fun _ state =>
  fIsR state && fIs state fun a _ => a

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial whole) fun _ state =>
  fIsR state && fIs state fun a b => a && b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial omitted_output) fun _ state =>
  fIsR state && fIs state fun a b => a == b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial binders_and_no_input) fun _ state =>
  let g := (state.g : Bool → Bool → Bool → Bool)
  let c := (state.c : Bool → Bool)
  g true false true && !g true false false && !g false false false && g false false true &&
  c true && !c false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial arrow) fun _ state =>
  fIsR state && fIs state fun _ _ => false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial arrow_call_writes) fun _ state =>
  fIsR state && fIs state fun a _ => a

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial nested_action) fun _ state =>
  fIsR state && fIs state fun a _ => a

#guard exactlyNSuccesses 2 (__veil_exec_action% {} {} initial havoc) fun observed state =>
  !observed && !readF state true true && !readF state false false && !readF state false true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial index_reads_state) fun _ state =>
  fIsR state && fIs state fun a b => !a && !b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial local_shadow) fun observed state =>
  observed == (true, false) && fIs state fun a b => a && b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial (in_branch true)) fun seen state =>
  seen && fIs state fun a b => a && !b

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial (in_branch false)) fun seen state =>
  !seen && fIs state fun a b => a && b && !readR state true true

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial plain_write) fun _ state =>
  let plain := (state.plain : Bool → Bool → Bool)
  plain true true && plain true false && plain false true && plain false false

#guard exactlyOneSuccess (__veil_exec_action% {} {} initial universal_rhs) fun _ state =>
  fIsR state && fIs state fun _ _ => false
#guard exactlyOneSuccess (__veil_exec_action% {} {} initial output_reads_state) fun _ state =>
  fIsR state && fIs state fun a b => a && !b
#guard exactlyOneSuccess (__veil_exec_action% {} {} initial whole_arrow) fun _ state =>
  fIsR state && fIs state fun _ _ => false
#guard exactlyOneSuccess (__veil_exec_action% {} {} initial whole_reads_state) fun _ state =>
  fIsR state && fIs state fun _ _ => false
#guard exactlyOneSuccess (__veil_exec_action% {} {} initial arrow_rhs_branch) fun changed state =>
  changed && fIs state fun _ _ => false

-- Populated neighboring rows must survive both replacement and deletion.
def initiallyDefined : State FieldConcreteType :=
  { initial with f := fun _ y => y, r := fun _ y => y }
#guard exactlyOneSuccess (__veil_exec_action% {} {} initiallyDefined point) fun _ state =>
  fIsR state && fIs state fun a b => a != b
#guard exactlyOneSuccess (__veil_exec_action% {} {} initiallyDefined point_false) fun _ state =>
  fIsR state && fIs state fun a b => !a && b
-- Re-evaluating the input after the clear can select a different, uncleared row.
#guard exactlyOneSuccess (__veil_exec_action% {} {} initiallyDefined index_reads_state) fun _ state =>
  fIsR state && fIs state fun a _ => !a

end ActionExecutionPartialFunction
