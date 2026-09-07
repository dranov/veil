import Veil.Base

open Lean Veil

run_cmd do
  for solver in [VeilSolver.smt, .grind, .grindAndSMT, .custom] do
    let encoded := KVMap.Value.toDataValue solver
    let decoded : Option VeilSolver := KVMap.Value.ofDataValue? encoded
    unless decoded.map toString == some (toString solver) do
      throwError "solver codec failed to round-trip {solver}"
    let options := ({} : Options).set `veil.solver solver
    unless toString (veil.solver.get options) == toString solver do
      throwError "programmatic option silently changed solver {solver}"

-- Preserve old serialized values as an input alias, but emit the documented spelling.
#guard toString VeilSolver.grindAndSMT == "grind+smt"
#guard ((KVMap.Value.ofDataValue? (.ofString "grindAndSMT") : Option VeilSolver).map toString) == some "grind+smt"
#guard ((KVMap.Value.ofDataValue? (.ofString "invalid") : Option VeilSolver).map toString) == none
