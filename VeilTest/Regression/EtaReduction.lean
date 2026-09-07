import Veil.Util.Meta

open Lean Meta Elab Command

run_meta do
  let nat := mkConst ``Nat
  withLocalDeclD `x nat fun x => do
    let body := mkApp2 (mkConst ``Nat.add) x x
    let result ← mkLambdaFVarsWithAppSuffixEta #[x] body
    let expected ← mkLambdaFVars #[x] body
    unless !result.hasFVar && (← isDefEq result expected) do
      throwError "eta reduction dropped a variable used in an earlier argument"
    let independent := mkApp2 (mkConst ``Nat.add) (mkNatLit 1) x
    let reduced ← mkLambdaFVarsWithAppSuffixEta #[x] independent
    unless reduced == mkApp (mkConst ``Nat.add) (mkNatLit 1) do
      throwError "safe eta reduction was lost"
    withLocalDeclD `y nat fun y => do
      let body := mkApp2 (mkConst ``Nat.add) x y
      let result ← mkLambdaFVarsWithAppSuffixEta #[x, y] body
      unless result == mkConst ``Nat.add do
        throwError "multiple trailing binders did not reduce"
  -- Dependent binder types must remain scoped as well.
  withLocalDeclD `n nat fun n => do
    withLocalDeclD `i (mkApp (mkConst ``Fin) n) fun i => do
      let body ← mkAppM ``Fin.val #[i]
      let result ← mkLambdaFVarsWithAppSuffixEta #[n, i] body
      let expected ← mkLambdaFVars #[n, i] body
      unless !result.hasFVar && (← isDefEq result expected) do
        throwError "eta reduction escaped a dependent binder"
      let _ ← inferType result
