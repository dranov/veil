import Veil

open Veil
set_option veil.__modelCheckCompileMode true
set_option veil.__modelCheckCompileTarget false

-- Feedback guards must be suppressed together with replayed checks. These
-- intentionally run outside a module, where actual verification would fail.
/-- info: This feedback is intentionally suppressed during compiled replay. -/
#guard_msgs in
#model_check interpreted {} {}

/-- info: This feedback is intentionally suppressed during compiled replay. -/
#guard_msgs in
#check_invariants

/-- info: This feedback is intentionally suppressed during compiled replay. -/
#guard_msgs in
sat trace { }

-- Ordinary message guards still check their contents in compiled mode.
/-- info: 2 -/
#guard_msgs in
#eval (1 + 1 : Nat)
