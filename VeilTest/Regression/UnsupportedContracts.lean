import Veil

veil module UnsupportedContracts
individual x : Bool

/-- error: Declaration-level action and procedure contracts are not supported. Put require/assert statements inside the body; contract blocks were previously ignored. -/
#guard_msgs in
action ignored
  require does_not_exist
  assert False
{ x := true }

/-- error: Declaration-level action and procedure contracts are not supported. Put require/assert statements inside the body; contract blocks were previously ignored. -/
#guard_msgs in
procedure ignoredProcedure (b : Bool)
  require b
{ x := b }

-- Rejected contracts must not register a declaration or prevent a corrected one.
action ignored { require ¬ x; x := true; assert x }
procedure ignoredProcedure (b : Bool) { require b; x := b }
end UnsupportedContracts
