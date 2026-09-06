import Veil

veil module ModelCheckerConfigCommand

individual x : Bool
#gen_state
after_init { x := false }
action idle { pure () }
invariant true
#gen_spec

-- Reject unsupported configuration before compiled mode can omit it from native
-- command-line arguments. These checks do not invoke the compiler or a subprocess.
/-- error: Parallel model checking does not support numSubSteps other than 1 -/
#guard_msgs in
#model_check interpreted {} {} (parallelCfg := some { numSubSteps := 2 })

/-- error: Parallel model checking does not support numSubSteps other than 1 -/
#guard_msgs in
#model_check compiled {} {} (parallelCfg := some { numSubSteps := 2 })

/-- error: Parallel model checking does not support numSubSteps other than 1 -/
#guard_msgs in
#model_check {} {} (parallelCfg := some { numSubSteps := 2 })

end ModelCheckerConfigCommand
