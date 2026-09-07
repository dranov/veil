import Veil

veil module UnsupportedIsolates
individual x : Bool

/-- error: Assertion isolates are not supported. Veil checks the module's assertions together. -/
#guard_msgs in
open_isolate separate with first second

/-- error: Assertion isolates are not supported. Veil checks the module's assertions together. -/
#guard_msgs in
close_isolate

invariant [first] True
invariant [second] True
end UnsupportedIsolates
