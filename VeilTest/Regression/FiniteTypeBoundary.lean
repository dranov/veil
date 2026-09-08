import Veil.Util.FiniteTypes
import Veil.Util.SortedArray

open Lean Elab Command Veil

-- An executable architecture check: generic collections and enumeration must
-- stay importable without registering DSL syntax, modules, or state fallbacks.
run_cmd do
  for name in (← getEnv).header.moduleNames do
    if (`Veil.Frontend).isPrefixOf name then
      throwError "generic finite types imported frontend module {name}"

inductive FiniteBoundaryExample where
  | one
  | two (flag : Bool)
deriving Enumeration, FinEncodableInjOnly, DecidableEq

#guard (Enumeration.allValues (α := FiniteBoundaryExample)).length == 3
example (a : FiniteBoundaryExample) : a ∈ Enumeration.allValues := Enumeration.complete a

inductive FiniteBoundaryEnum where
  | first
  | second
deriving Enumeration, FinEncodable, DecidableEq

example : FinEncodable.card (α := FiniteBoundaryEnum) = 2 := rfl

-- Keep public JSON behavior stable while making its dependency explicit.
#guard toJson (OrdList.ofList [1, 2]) == Json.arr #[Json.str "1", Json.str "2"]
#guard toJson (OrdArray.ofOrdList (OrdList.ofList [1, 2])) == Json.str "[1, 2]"
