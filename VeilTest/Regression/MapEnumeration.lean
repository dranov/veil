import Veil.Frontend.DSL.State.Instances

open Veil

-- Three keys and three values have (3 + 1)^3 partial maps, rather than
-- 2^(3 * 3) overwriting candidates. Raw enumeration must already be unique.
#guard (Enumeration.allValues (α := Std.ExtTreeMap (Fin 3) (Fin 3))).length = 64
#guard (Enumeration.allValues (α := Std.ExtTreeMap (Fin 3) (Fin 3))).dedup.length = 64
#guard (Enumeration.allValues (α := Std.ExtTreeMap (Fin 0) (Fin 3))).length = 1
#guard (Enumeration.allValues (α := Std.ExtTreeMap (Fin 3) (Fin 0))).length = 1

section DuplicateInputs
local instance : Enumeration Bool where
  allValues := [false, true, false, true]
  complete := by intro b; cases b <;> simp

#guard (Enumeration.allValues (α := Std.ExtTreeMap Bool Bool)).length = 9
#guard (Enumeration.allValues (α := Std.ExtTreeMap Bool Bool)).dedup.length = 9
end DuplicateInputs
