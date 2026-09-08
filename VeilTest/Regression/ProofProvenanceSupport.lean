import Veil

set_option warn.sorry false

namespace ProofProvenanceSupport

theorem admitted : True := by sorry
theorem indirect : True := admitted
theorem twiceIndirect : True := indirect
axiom userAxiom : True
theorem usesAxiom : True := userAxiom
theorem clean : True := True.intro

-- Both trust modes are explicit; VeilTest's weak default is reconstruction.
set_option veil.smt.trust true in
theorem trusted (p : Prop) : p ∨ ¬p := by veil_smt

set_option veil.smt.trust false in
theorem reconstructed (p : Prop) : p ∨ ¬p := by veil_smt

theorem mixed : (True ∨ ¬True) ∧ True := ⟨trusted True, admitted⟩

end ProofProvenanceSupport
