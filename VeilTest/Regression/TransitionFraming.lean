import Veil

/-! Framing follows resolved references, including macro expansion, rather than
raw identifier spelling or the dependencies left after simplification. -/

namespace TransitionFramingGlobals
abbrev x' : Bool := false
abbrev fixed' : Bool := false
macro "framing_global" : term => `(x' = false)
end TransitionFramingGlobals

veil module TransitionFraming

individual x : Bool
individual y : Bool
immutable individual fixed : Bool

after_init { pure () }

macro "framing_hidden_flip" : term => `($(Lean.mkIdent `x') = !$(Lean.mkIdent `x))
macro "framing_nested_flip" : term => `(framing_hidden_flip)
macro "framing_local" : term => `(let x' : Bool := false; x' = false)
macro "framing_immutable_local" : term => `(let fixed' : Bool := false; fixed' = false)
macro "framing_illegal" : term => `($(Lean.mkIdent `fixed') = false)
macro "framing_discard" t:term : term => `(let _ := $t; True)
macro "framing_erase" _t:term : term => `(True)

elab "framing_without_info " cmd:command : command =>
  Lean.Elab.withEnableInfoTree false (Lean.Elab.Command.elabCommand cmd)

transition direct { x' = !x }
transition hidden { framing_nested_flip }
transition next_alias { let next := x'; next = !x }
transition tactic_body { by exact x' = !x }
framing_without_info transition info_disabled { framing_hidden_flip }
transition noop { True }
transition let_shadow { let x' : Bool := false; x' = false }
transition lambda_shadow { (fun (x' : Bool) => x' = false) false }
transition forall_shadow { ∀ x' : Bool, x' = x' }
transition exists_shadow { ∃ x' : Bool, x' = false }
transition match_shadow { match false with | x' => x' = false }
transition hygienic { framing_local }
transition qualified { TransitionFramingGlobals.x' = false }
transition preresolved_global { framing_global }
transition both { x' = !x ∧ y' = !y }
transition mixed { x' = !x ∧ (let y' : Bool := false; y' = false) }
transition dead_reference { let _ := x'; True }
transition dead_macro_reference { framing_discard x' }
transition dead_tactic_reference { by let _ := x'; exact True }
transition erased_macro_argument { framing_erase x' }
transition inner_reference { let x' := x'; x' = !x }
transition immutable_shadow { let fixed' : Bool := false; fixed' = false }
transition immutable_hygienic { framing_immutable_local }
transition immutable_parameter (fixed' : Bool) { fixed' = false }
transition immutable_qualified { TransitionFramingGlobals.fixed' = false }
open TransitionFramingGlobals in
transition immutable_global { fixed' = false }

/-- error: Error in action illegal_direct: individual fixed in module TransitionFraming was declared immutable, but the transition might modify it (since it mentions its primed version fixed')! -/
#guard_msgs in
transition illegal_direct { fixed' = false }

/-- error: Error in action illegal_macro: individual fixed in module TransitionFraming was declared immutable, but the transition might modify it (since it mentions its primed version fixed')! -/
#guard_msgs in
transition illegal_macro { framing_illegal }

/-- error: Error in action illegal_dead: individual fixed in module TransitionFraming was declared immutable, but the transition might modify it (since it mentions its primed version fixed')! -/
#guard_msgs in
transition illegal_dead { let _ := fixed'; True }

-- This equality holds for all representations and enclosing theory/state types.
example : @direct.ext.tr = @hidden.ext.tr := rfl
example : @direct.ext.tr = @next_alias.ext.tr := rfl
example : @direct.ext.tr = @inner_reference.ext.tr := rfl
example : @direct.ext.tr = @tactic_body.ext.tr := rfl
example : @direct.ext.tr = @info_disabled.ext.tr := rfl
example : @noop.ext.tr = @erased_macro_argument.ext.tr := rfl
example : @qualified.ext.tr = @preresolved_global.ext.tr := rfl
example : @immutable_qualified.ext.tr = @immutable_global.ext.tr := rfl

abbrev S := State FieldAbstractType

example (th : Theory) (s t : S) :
    hidden.ext.tr th s t ↔ s.y = t.y ∧ t.x = !s.x := by
  simp [hidden.ext.tr, getFrom, FieldRepresentation.get]

-- All forms of shadowing retain the frame for both fields.
example (th : Theory) (s t : S) :
    let_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [let_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    lambda_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [lambda_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    forall_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [forall_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    exists_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [exists_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    match_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [match_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    hygienic.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [hygienic.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    qualified.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [qualified.ext.tr, getFrom, FieldRepresentation.get, TransitionFramingGlobals.x']

example (th : Theory) (s t : S) :
    both.ext.tr th s t ↔ t.x = !s.x ∧ t.y = !s.y := by
  simp [both.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    mixed.ext.tr th s t ↔ s.y = t.y ∧ t.x = !s.x := by
  simp [mixed.ext.tr, getFrom, FieldRepresentation.get]

-- Even a discarded reference permits x to change; y remains framed.
example (th : Theory) (s t : S) : dead_reference.ext.tr th s t ↔ s.y = t.y := by
  simp [dead_reference.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) : dead_macro_reference.ext.tr th s t ↔ s.y = t.y := by
  simp [dead_macro_reference.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) : dead_tactic_reference.ext.tr th s t ↔ s.y = t.y := by
  simp [dead_tactic_reference.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    immutable_shadow.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [immutable_shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    immutable_hygienic.ext.tr th s t ↔ s.x = t.x ∧ s.y = t.y := by
  simp [immutable_hygienic.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) (v : Bool) :
    immutable_parameter.ext.tr v th s t ↔ (s.x = t.x ∧ s.y = t.y) ∧ v = false := by
  simp [immutable_parameter.ext.tr, getFrom, FieldRepresentation.get]

-- Exercise concrete state pairs as well as symbolic relation equivalences.
example : hidden.ext.tr ⟨false⟩ (⟨false, false⟩ : S) (⟨true, false⟩ : S) := by
  simp [hidden.ext.tr, getFrom, FieldRepresentation.get]
example : ¬ let_shadow.ext.tr ⟨false⟩ (⟨false, false⟩ : S) (⟨true, false⟩ : S) := by
  simp [let_shadow.ext.tr, getFrom, FieldRepresentation.get]
example : ¬ hidden.ext.tr ⟨false⟩ (⟨false, false⟩ : S) (⟨true, true⟩ : S) := by
  simp [hidden.ext.tr, getFrom, FieldRepresentation.get]

end TransitionFraming

veil module TransitionFramingFunctions

function counter : Bool → Nat
relation marked : Bool → Bool
immutable function fixed : Bool → Nat

after_init { pure () }

macro "framing_hidden_function" : term =>
  `(∀ b, $(Lean.mkIdent `counter') b = $(Lean.mkIdent `counter) b + 1)
macro "framing_hidden_relation" : term =>
  `(∀ b, $(Lean.mkIdent `marked') b = !$(Lean.mkIdent `marked) b)

transition direct { ∀ b, counter' b = counter b + 1 }
transition hidden { framing_hidden_function }
transition relation_only { framing_hidden_relation }
transition shadow { (∀ (counter' : Nat), counter' = counter') ∧ (∀ (marked' : Bool), marked' = marked') }
transition both { framing_hidden_function ∧ framing_hidden_relation }

/-- error: Error in action illegal: function fixed in module TransitionFramingFunctions was declared immutable, but the transition might modify it (since it mentions its primed version fixed')! -/
#guard_msgs in
transition illegal { fixed' true = 0 }

example : @direct.ext.tr = @hidden.ext.tr := rfl

abbrev S := State FieldAbstractType

-- Function equalities may require extracted Decidable parameters. The proofs
-- check their propositions, using classical decidability only in the tests.
open scoped Classical

example (th : Theory) (s t : S) :
    hidden.ext.tr th s t ↔ s.marked = t.marked ∧ ∀ b, t.counter b = s.counter b + 1 := by
  classical
  simp [hidden.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    relation_only.ext.tr th s t ↔ s.counter = t.counter ∧ ∀ b, t.marked b = !s.marked b := by
  classical
  simp [relation_only.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    shadow.ext.tr th s t ↔ s.counter = t.counter ∧ s.marked = t.marked := by
  classical
  simp [shadow.ext.tr, getFrom, FieldRepresentation.get]

example (th : Theory) (s t : S) :
    both.ext.tr th s t ↔ (∀ b, t.counter b = s.counter b + 1) ∧ (∀ b, t.marked b = !s.marked b) := by
  classical
  simp [both.ext.tr, getFrom, FieldRepresentation.get]

end TransitionFramingFunctions
