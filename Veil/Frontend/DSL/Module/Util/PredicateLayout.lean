import Veil.Frontend.DSL.Module.Util.AbstractState

open Lean Parser Elab Command Term Meta

namespace Veil

/-- The environment arguments carried by a generated predicate. -/
inductive PredicateContext where
  | theoryOnly
  | withState

/-- Resolve the DSL metadata key used by both locality transformations.
The current metadata stores module-local names; generated Lean declarations
are qualified by the module namespace. -/
def Module.localDeclarationName? (mod : Module) (fullName : Name) : Option Name :=
  if mod._declarations.contains fullName then
    some fullName
  else
    let localName := fullName.updatePrefix Name.anonymous
    if mod._declarations.contains localName then some localName else none

/-- Exact expression parameter order for the supported predicate generators.
Ghost predicates place extracted instances after user parameters; assertions
and assembled predicates append generated environment binders. Keep that
shared contract here until registration records complete elaborated layouts. -/
def Module.predicateExprParams [Monad m] [MonadQuotation m]
    [MonadExceptOf Exception m] [AddErrorMessageContext m]
    (mod : Module) (nm : Name) (dk : DeclarationKind)
    (context : PredicateContext) : m (Array Parameter) := do
  let (baseParams, extraParams, actualParams) ← mod.declarationSplitParams nm dk
  let thParam : Parameter := { kind := .theoryArg, name := `th, «type» := ← `(term| $environmentTheory), userSyntax := .missing }
  let contextParams ← match context with
    | .theoryOnly => pure #[thParam]
    | .withState => pure #[thParam, { kind := .stateArg, name := `st, «type» := ← `(term| $environmentState), userSyntax := .missing }]
  let isGhost ← match context, dk with
    | .theoryOnly, .stateAssertion .assumption
    | .theoryOnly, .derivedDefinition .assumptionLike _ => pure false
    | .theoryOnly, .derivedDefinition (.theoryGhost true) _ => pure true
    | .withState, .stateAssertion .assumption =>
      throwError "{nm} is not a state predicate"
    | .withState, .stateAssertion _
    | .withState, .derivedDefinition .invariantLike _ => pure false
    | .withState, .derivedDefinition (.ghost true) _ => pure true
    | _, _ => throwError "{nm} is not a supported locality predicate"
  if !isGhost then
    return baseParams ++ extraParams ++ contextParams
  let (userParams, environmentParams) := actualParams.partition fun p =>
    p.kind != .theoryArg && p.kind != .stateArg
  unless environmentParams.map (·.kind) == contextParams.map (·.kind) do
    throwError "ghost relation {nm} does not carry the expected environment argument metadata"
  return baseParams ++ userParams ++ extraParams ++ environmentParams

end Veil
