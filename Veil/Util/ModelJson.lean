import Lean

namespace Veil
open Lean

/-- Preserve integers outside JavaScript's exact range throughout a JSON value.
The tagged decimal is a value, not an identifier, and must never pass through JS Number. -/
partial def losslessModelJson : Json → Json
  | value@(.num _) =>
    match value.getInt? with
    | .ok n => if n.natAbs > 9007199254740991 then
        Json.mkObj [("$veilInteger", .str (toString n))]
      else value
    | .error _ => value
  | .arr items => .arr (items.map losslessModelJson)
  | .obj fields => Json.mkObj (fields.toList.map fun (key, value) => (key, losslessModelJson value))
  | value => value

/-- Bitvectors use their unsigned decimal value without losing high bits in JSON. -/
instance {width : Nat} : ToJson (BitVec width) where
  toJson value := losslessModelJson (toJson value.toNat)

end Veil
