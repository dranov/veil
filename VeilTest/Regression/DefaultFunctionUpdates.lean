import Veil

open Veil

-- A total map reads absent keys as default. Writing the default must erase
-- existing entries, while ordinary partial-map insert retains its meaning.
#guard (FinmapLike.insert 2 0 (Std.HashMap.ofList [(2, 4), (3, 7)] : Std.HashMap Nat Nat)).toList.length = 1
#guard (FinmapLike.insert 2 0 (Std.TreeMap.ofList [(2, 4), (3, 7)] : Std.TreeMap Nat Nat)).toList = [(3, 7)]
#guard (FinmapLike.insert 2 0 (Std.ExtTreeMap.ofList [(2, 4), (3, 7)] : Std.ExtTreeMap Nat Nat)).toList = [(3, 7)]
#guard (FinmapLike.insert 2 9 ({} : Std.ExtTreeMap Nat Nat)).toList = [(2, 9)]
#guard (Std.ExtTreeMap.insert ({} : Std.ExtTreeMap Nat Nat) 2 0).toList = [(2, 0)]

veil module DefaultFunctionUpdates

type node
function f : node → Nat

after_init { pure () }
action same (n : node) { f n := 0 }
invariant [zero] f N = 0
termination True
#gen_spec

/-- info: ✅ No violation (explored 1 states) -/
#guard_msgs in
#model_check interpreted { node := Fin 5 }

end DefaultFunctionUpdates
