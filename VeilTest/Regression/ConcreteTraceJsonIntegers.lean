import Veil.Core.Tools.ModelChecker.Trace

open Lean Veil.ModelChecker

private def trace : Trace Nat Nat Int := {
  theory := 9007199254740993
  initialState := 9007199254740993
  steps := #[{transitionLabel := -9007199254740993, nextState := 9007199254740992}]
}

#guard ((toJson trace).getObjValD "theory").compress == "{\"$veilInteger\":\"9007199254740993\"}"
#guard ((toJson trace).getObjValD "states").compress.contains "\"$veilInteger\":\"-9007199254740993\""
#guard ((toJson trace).getObjValD "states").compress.contains "\"$veilInteger\":\"9007199254740992\""
