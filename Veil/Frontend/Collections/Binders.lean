module

public meta import Lean

public meta section
open Lean Elab Term

namespace Veil

/-- Elaborate an independent bound before its binder, so collection literals
can resolve their instances. Embed the resulting expression directly: inserting
a `let` here would change the binders seen by tactics such as `intro`.

The dependency check is deliberately conservative, including dotted names and
shadowed occurrences. A possibly dependent bound uses ordinary Lean binding. -/
def elabBoundedQuantifier (x : Ident) (bound : Term)
    (expand : Term → TermElabM Term) (expected? : Option Expr) : TermElabM Expr := do
  let depends := bound.raw.find? fun stx =>
    stx.isIdent && stx.getId.eraseMacroScopes.getRoot == x.getId.eraseMacroScopes
  let bound ← if depends.isSome then pure bound else do
    let value ← withSynthesize (postpone := .partial) <| elabTerm bound none
    exprToSyntax value
  elabTerm (← expand bound) expected?

end Veil
