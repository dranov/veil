import Lean

namespace Veil
open Lean

/-- Encode actual name components rather than pretty-printed identifier syntax. -/
private def traceNameComponents : Name → List Json
  | .anonymous => []
  | .str parent value => traceNameComponents parent ++ [.str value]
  | .num parent value => traceNameComponents parent ++ [toJson value]

def encodeTraceName (name : Name) : String :=
  (Json.arr (traceNameComponents name).toArray).compress

def decodeTraceName (encoded : String) : Option Name := do
  let parts ← ((Json.parse encoded).toOption.bind fun value => value.getArr?.toOption)
  parts.foldlM (init := Name.anonymous) fun parent part => do
    match part with
    | .str value => return .str parent value
    | .num _ => return .num parent (← part.getNat?.toOption)
    | _ => none

def traceActionParamPrefix (transition : Nat) (action : Name) : String :=
  let encoded := encodeTraceName action
  s!"_tr{transition}_act{encoded.length}_{encoded}"

def traceParamName (prefix_ : String) (index : Nat) (param : Name) : Name :=
  .mkSimple s!"{prefix_}_arg{index}_{encodeTraceName param}"

end Veil
