import Veil.Backend.SMT.Model

open Lean Meta Veil

private def rejects (value expectedType : Expr) (message : String) : MetaM Unit := do
  let rejected ← try
    let _ ← adaptSmtExprType value expectedType
    pure false
  catch ex => pure ((← ex.toMessageData.toString).contains message)
  unless rejected do throwError "Expected adaptation rejection containing {message}"

run_meta do
  rejects (mkNatLit 1) (← mkArrow (mkConst ``Nat) (mkConst ``Nat)) "expected 1 arguments"
  rejects (mkConst ``Nat.succ) (mkConst ``Nat) "expected 0 arguments"
  rejects (mkConst ``Nat.succ) (← mkArrow (mkConst ``String) (mkConst ``Nat)) "argument 0"
  rejects (mkConst ``Bool.true) (mkConst ``String) "result"
  let adapted ← adaptSmtExprType (mkConst ``Int.neg) (← mkArrow (mkConst ``Nat) (mkConst ``Nat))
  unless ← isDefEq (← inferType adapted) (← mkArrow (mkConst ``Nat) (mkConst ``Nat)) do
    throwError "Supported Int/Nat adaptation has the wrong type"
