import Veil.Frontend.DSL.Module.Util.Assertions

open Lean Elab Term Meta

namespace Veil

/-- Collect references before normalization can erase, for example, an unused
`let` RHS. The elaborator's term information records resolved local identities,
so macros and shadowing have the same meaning here as in ordinary Lean terms.
Binder declarations themselves are not references. -/
private partial def transitionReferences (tree : InfoTree)
    (refs : FVarIdSet := {}) : TermElabM FVarIdSet := do
  match tree with
  | .context _ tree => transitionReferences tree refs
  | .hole id =>
    if let some tree ← getInfoHoleIdAssignment? id then
      transitionReferences tree refs
    else
      return refs
  | .node info children =>
    let mut refs := refs
    if let .ofTermInfo info := info then
      unless info.isBinder do
        let expr ← instantiateMVars info.expr
        for id in (collectFVars {} expr).fvarIds do
          refs := refs.insert id
    children.foldlM (fun refs tree => transitionReferences tree refs) refs

/-- Internal wrapper, elaborated inside the generated theory/state scope. -/
syntax (name := framedTransition) "veil_framed_transition% " term : term

@[term_elab framedTransition]
def elabFramedTransition : TermElab := fun stx _ => do
  let `(veil_framed_transition% $body) := stx | throwUnsupportedSyntax
  let mod ← getCurrentModule
  -- Resolve these *before* entering the user term's scopes. Comparing the
  -- resulting fvars distinguishes a state field from a shadowing local.
  let fields ← mod.mutableComponents.mapM fun field => do
    let before ← elabTerm (mkIdent field.name) none
    let after ← elabTerm (mkIdent (field.name.appendAfter "'")) none
    return (before, after)
  -- Immutable fields have no post-state. Temporary primed locals let normal
  -- name resolution distinguish an illegal reference from a harmless binder
  -- or a hygienic macro local, and preserve the useful immutability diagnostic.
  -- Do not shadow existing parameters or constants named `field'`: those
  -- already have a valid meaning independent of the immutable field.
  let immutableComponents ← mod.immutableComponents.filterM fun field => do
    return (← resolveId? (mkIdent (field.name.appendAfter "'"))).isNone
  let immutableDecls ← immutableComponents.mapM fun field => do
    let value ← elabTerm (mkIdent field.name) none
    return (field.name.appendAfter "'", ← inferType value)
  withLocalDeclsDND immutableDecls fun immutableFields => do
    withEnableInfoTree true do
      let savedTrees ← getResetInfoTrees
      let getReferences := do
        (← getInfoTrees).foldlM (fun refs tree => transitionReferences tree refs) {}
      let checkImmutable (refs : FVarIdSet) := do
        for (field, value) in immutableComponents.zip immutableFields do
          if refs.contains value.fvarId! then
            mod.throwIfImmutable field.name (isTransition := true)
      try
        let expr ← try
          let expr ← elabTermEnsuringType body (some (mkSort .zero))
          -- Resolve postponed terms before deciding which fields were mentioned.
          -- Decidable instances can remain unsolved: the outer transition
          -- elaborator extracts them as parameters.
          synthesizeSyntheticMVars (postpone := .no) (ignoreStuckTC := true)
          pure expr
        catch ex =>
          -- Prefer the immutable-field diagnostic even if the surrounding
          -- expression also has a type error.
          checkImmutable (← getReferences)
          throw ex
        let refs ← getReferences
        checkImmutable refs
        let mut frames : Array Expr := #[]
        for (before, after) in fields do
          unless refs.contains after.fvarId! do
            frames := frames.push (← mkEq before after)
        let frame := frames.toList.foldr
          (fun eq rest => some (rest.elim eq (mkAnd eq))) none
          |>.getD (mkConst ``True)
        return mkAnd frame expr
      finally
        -- Keep the user's editor information in its original parent tree.
        modifyInfoState fun state => { state with trees := savedTrees ++ state.trees }

end Veil
