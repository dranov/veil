import Veil

open Lean Elab Command Veil

veil module ProcedureBodyKinds
individual x : Bool
after_init { x := false }
procedure helper { x := true }
action step { helper }
transition flip { x' = !x }

run_cmd do
  let mod ← getCurrentModule
  let some helper := mod.procedures.find? (·.info.name == `helper)
    | throwError "missing helper metadata"
  let some flip := mod.procedures.find? (·.info.name == `flip)
    | throwError "missing transition metadata"
  unless helper.body matches .imperative _ do
    throwError "imperative body stored with the wrong category"
  unless flip.body matches .relational _ do
    throwError "transition body stored with the wrong category"
end ProcedureBodyKinds
