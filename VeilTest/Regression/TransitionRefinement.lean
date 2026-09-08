import Veil.Frontend.DSL.Action.Semantics.TransitionRefinement

open Veil

-- Whole-state conversion preserves arbitrary relations in both action modes.
example (tr : Transition Unit Bool) :
    (Transition.toVeilM (σ := Bool) (m := .external) tr).toTransitionDerived = tr :=
  Transition.toVeilM_wholeState tr

example (tr : Transition Unit Bool) :
    (Transition.toVeilM (σ := Bool) (m := .internal) tr).toTransitionDerived = tr :=
  Transition.toVeilM_wholeState tr

-- A lawful proper substate can leave part of the state unchanged. Its native
-- relation and executable conversion are not interchangeable in general.
local instance : IsSubStateOf Unit Bool where
  getFrom _ := ()
  setIn _ s := s
  setIn_getFrom_idempotent _ := rfl
  setIn_setIn_last _ _ _ := rfl
  getFrom_setIn_idempotent u _ := by cases u; rfl

example : ¬(Transition.toVeilM (σ := Unit) (m := .external)
    (fun (_ : Unit) (_ _ : Bool) => True)).toTransitionDerived () false true := by
  rw [Transition.toVeilM_transition_iff]
  simp [setIn]
