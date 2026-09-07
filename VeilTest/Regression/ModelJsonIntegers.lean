import Veil.Backend.SMT.Model

open Lean Veil

#guard losslessModelJson (toJson (9007199254740991 : Nat)) == toJson (9007199254740991 : Nat)
#guard losslessModelJson (toJson (9007199254740993 : Nat)) == Json.mkObj [("$veilInteger", .str "9007199254740993")]
#guard losslessModelJson (toJson (-9007199254740993 : Int)) == Json.mkObj [("$veilInteger", .str "-9007199254740993")]
#guard losslessModelJson (toJson ("9007199254740993" : String)) == .str "9007199254740993"
#guard losslessModelJson (.arr #[toJson (9007199254740993 : Nat)]) ==
  .arr #[Json.mkObj [("$veilInteger", .str "9007199254740993")]]
#guard losslessModelJson (Json.mkObj [("field", toJson (9007199254740993 : Nat))]) ==
  Json.mkObj [("field", Json.mkObj [("$veilInteger", .str "9007199254740993")])]

#guard toJson (BitVec.ofNat 64 9007199254740993) == Json.mkObj [("$veilInteger", .str "9007199254740993")]
