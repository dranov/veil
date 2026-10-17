module

public import Veil.Frontend.Std
public meta import Lean

@[expose] public section

namespace Veil

/-- Default concrete representation for finite sets. -/
abbrev DefaultSet (α : Type u) [Ord α] := Std.ExtTreeSet α

/-- Retains the element type in the goal of an instantiation-field default.
The carrier is still a freely selectable type. -/
abbrev SetCarrier (_ : Type) := Type

end Veil

public meta section

open Lean Elab Tactic

/-- Resolve the representation after the element type has been instantiated,
when its concrete ordering instances are available. -/
elab "veil_default_set_carrier" : tactic => do
  let target ← instantiateMVars (← getMainTarget)
  unless target.isAppOfArity ``Veil.SetCarrier 1 do
    throwError "expected a set carrier default"
  let elem ← Term.exprToSyntax target.appArg!
  evalTactic (← `(tactic| exact Veil.DefaultSet $elem))
