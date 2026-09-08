import Veil.Frontend.DSL.Action.Semantics.WP

namespace Veil
open PartialCorrectness DemonicChoice

/-- A converted native transition may choose only successors obtainable by
updating the selected substate. This precisely states the extra constraint
introduced by `Transition.toVeilM`; no surjectivity assumption is implicit. -/
theorem Transition.toVeilM_transition_iff {ρ σ σ' : Type} [IsSubStateOf σ σ']
    (tr : Transition ρ σ') (r : ρ) (s t : σ') :
    (Transition.toVeilM (σ := σ) (m := m) tr).toTransitionDerived r s t ↔
      (∃ v : σ, setIn v s = t) ∧ tr r s t := by
  simp [Transition.toVeilM, VeilM.toTransitionDerived, VeilSpecM.toTransitionDerived,
    loomLogicSimp, wpSimp, substateSimp, Pi.compl_apply, MonadNonDet.wp_assume, VeilM.wp_set']
  aesop

/-- Executable native transitions refine the supplied relation. -/
theorem Transition.toVeilM_refines {ρ σ σ' : Type} [IsSubStateOf σ σ']
    (tr : Transition ρ σ') (r : ρ) (s t : σ')
    (h : (Transition.toVeilM (σ := σ) (m := m) tr).toTransitionDerived r s t) :
    tr r s t :=
  (Transition.toVeilM_transition_iff tr r s t).mp h |>.2

/-- Conversely, a permitted native successor is executable when the selected
substate can represent its update from this particular pre-state. -/
theorem Transition.toVeilM_complete_of_representable {ρ σ σ' : Type} [IsSubStateOf σ σ']
    (tr : Transition ρ σ') (r : ρ) (s t : σ')
    (representable : ∃ v : σ, setIn v s = t) (h : tr r s t) :
    (Transition.toVeilM (σ := σ) (m := m) tr).toTransitionDerived r s t :=
  (Transition.toVeilM_transition_iff tr r s t).mpr ⟨representable, h⟩

/-- With the canonical whole-state instance, every target is representable,
so conversion preserves the native relation exactly. -/
theorem Transition.toVeilM_wholeState {ρ σ : Type} (tr : Transition ρ σ) :
    (Transition.toVeilM (σ := σ) (m := m) tr).toTransitionDerived = tr := by
  funext r s t
  apply propext
  rw [Transition.toVeilM_transition_iff]
  simp [instIsSubStateOfRefl.setIn_overwrite]

end Veil
