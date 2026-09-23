module

public import Veil

veil module CollectionAllocation

finite_type client
finite_type resource
set_type Clients : client
set_type Resources : resource
function allocated : client → Resources

after_init { allocated C := ∅ }
action allocate (c : client) {
  let used := ⋃ who ∈ (TSet.univ client : Clients), allocated who
  let available := (TSet.univ resource : Resources) \ used
  let grant ⊆ available :| card grant > 0
  allocated c := allocated c ∪ grant
}
invariant ∀ c d, c ≠ d → TSet.Disjoint (allocated c) (allocated d)

#gen_spec
/-- info: ✅ No violation (explored 27 states) -/
#guard_msgs in
#model_check interpreted { client := Fin 2, resource := Fin 3 } {}
/-- info: ✅ No violation (explored 27 states) -/
#guard_msgs in
#model_check compiled { client := Fin 2, resource := Fin 3 } {} (sequential := true)

end CollectionAllocation
