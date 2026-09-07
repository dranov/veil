import Veil

veil module SingleTermination
individual x : Bool
after_init { x := false }
termination [always] True

/-- error: A Veil module supports only one termination predicate. Combine the intended condition explicitly in that declaration; additional predicates were previously ignored. -/
#guard_msgs in
termination [never] False

/-- error: A Veil module supports only one termination predicate. Combine the intended condition explicitly in that declaration; additional predicates were previously ignored. -/
#guard_msgs in
termination False

-- The rejected declaration must not reserve its name.
invariant [never] True
end SingleTermination

-- The restriction is per module.
veil module AnotherTermination
individual x : Bool
termination False
end AnotherTermination
