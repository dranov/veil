import Veil

/-! Opaque function storage must never silently collapse reachable states. -/
veil module ConstantInitializer
relation r : Nat → Bool
after_init { r N := false }
action a { r 0 := true }
action b { require r 0; r 1 := true }
invariant [r1_false] ¬ r 1
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: r1_false)
  State 0 (via init):
    r = []
  State 1 (via a):
    r = [0]
  State 2 (via b):
    r = [0, 1]
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
/--
error: ❌ Violation: safety_failure (violates: r1_false)
  State 0 (via init):
    r = []
  State 1 (via a):
    r = [0]
  State 2 (via b):
    r = [0, 1]
-/
#guard_msgs in
#model_check interpreted {} {} (parallelCfg := some { numSubTasks := 2, thresholdToParallel := 0 })
end ConstantInitializer

veil module OpaqueSuccessor
relation r : Nat → Bool
after_init { pure () }
action assignOpaque { r N := N == 0 }
invariant True
termination True
#gen_spec
/-- error: 💥 Error: Cannot model check: state field 'r' cannot be fully represented. An assignment over a non-enumerable domain produced an opaque function, so distinct states cannot be distinguished. Use a finite domain or finite point updates. -/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
/-- error: 💥 Error: Cannot model check: state field 'r' cannot be fully represented. An assignment over a non-enumerable domain produced an opaque function, so distinct states cannot be distinguished. Use a finite domain or finite point updates. -/
#guard_msgs in
#model_check interpreted {} {} (parallelCfg := some { numSubTasks := 2, thresholdToParallel := 0 })
end OpaqueSuccessor

veil module FinitePointUpdates
relation r : Nat → Bool
after_init { pure () }
action a { r 0 := true }
action b { require r 0; r 1 := true }
invariant [r1_false] ¬ r 1
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: r1_false)
  State 0 (via init):
    r = []
  State 1 (via a):
    r = [0]
  State 2 (via b):
    r = [0, 1]
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end FinitePointUpdates

-- Compilation emits the same checked entry point. Execute it directly here;
-- this also checks that callers receive an IO error rather than false success.
veil module CompiledRepresentationGuard
relation r : Nat → Bool
after_init { r N := N == 0 }
action idle { pure () }
invariant True
termination True
#gen_spec
set_option veil.__modelCheckCompileMode true
#model_check compiled {}
set_option veil.__modelCheckCompileMode false

/-- info: rejected unrepresentable compiled state -/
#guard_msgs in
#eval show IO Unit from do
  let token ← IO.CancelToken.new
  try
    let _ ← modelCheckerResult none 0 token
    throw (IO.userError "unexpected model checking success")
  catch error =>
    unless (error.toString.splitOn "cannot be fully represented").length > 1 do
      throw error
    IO.println "rejected unrepresentable compiled state"

-- Opaque wrappers remain unrepresentable inside supported container types.
private def opaqueWrapper : Veil.CanonicalFieldWrapper [Nat] Bool := ⟨fun _ => false⟩
#guard !Veil.ModelCheckRepresentation.isRepresentable opaqueWrapper
#guard !Veil.ModelCheckRepresentation.isRepresentable [(some opaqueWrapper, true)]
#guard !Veil.ModelCheckRepresentation.isRepresentable #[Sum.inl opaqueWrapper (β := Nat)]
#guard Veil.ModelCheckRepresentation.isRepresentable [(some (3 : Nat), true)]

veil module ExcludedOpaqueState
relation r : Nat → Bool
after_init { r N := N == 0 }
action idle { pure () }
invariant True
state_constraint False
termination True
#gen_spec
-- Constraints exclude this state before its identity is needed.
/-- info: ✅ No violation (explored 0 states) -/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end ExcludedOpaqueState
