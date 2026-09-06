import Veil

veil module InitializerAssertionExtraction

individual x : Nat
#gen_state

after_init {
  let b ← pick Bool
  x := 7
  assert b
}

action idle { pure () }
invariant true

#guard_msgs (drop error) in
#gen_spec

#guard_msgs (drop error) in
#model_check interpreted {} {}

-- Inspect the generated enumerable system, independently of the initialization VC.
#eval show IO Unit from do
  let sys := InitializerAssertionExtraction.enumerableTransitionSystem ({} : Theory)
  unless sys.initStates.length == 1 && sys.initFailures.length == 1 do
    throw <| IO.userError "generated initializer lost successful or failing branches"
  unless sys.initFailures.head!.2.x == 7 do
    throw <| IO.userError "initializer failure did not preserve the state at assertion"

end InitializerAssertionExtraction
