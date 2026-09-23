module


public import Veil

-- https://github.com/tlaplus/Examples/blob/c2641e69204ed241cdf548d9645ac82df55bfcd8/specifications/allocator/SimpleAllocator.tla

veil module SimpleAllocator


finite_type client
finite_type resource

set_type ResourceSet : resource
set_type ClientsSet : client
function unsatisfy : client → ResourceSet
function alloc : client → ResourceSet

#gen_state


-- Init ==
--   /\ unsat = [c \in Clients |-> {}]
--   /\ alloc = [c \in Clients |-> {}]
after_init {
  unsatisfy C := ∅
  alloc C := ∅
}


-- Request(c,S) ==
--   /\ unsat[c] = {} /\ alloc[c] = {}
--   /\ S # {} /\ unsat' = [unsat EXCEPT ![c] = S]
--   /\ UNCHANGED alloc
action Request (c : client) {
  -- S \in SUBSET Resources /\ S # {}
  let S ⊆ (TSet.univ resource : ResourceSet) :| TSet.Nonempty S
  require card (unsatisfy c) == 0
  require card (alloc c) == 0
  unsatisfy c := S
}



-- Allocate(c,S) ==
--   /\ S # {} /\ S \subseteq available \cap unsat[c]
--   /\ alloc' = [alloc EXCEPT ![c] = @ \cup S]
--   /\ unsat' = [unsat EXCEPT ![c] = @ \ S]
action Allocate (c : client) {
  let available := (TSet.univ resource : ResourceSet) \ (⋃ c' ∈ (TSet.univ client : ClientsSet), alloc c')
  let S ⊆ (available ∩ unsatisfy c) :| TSet.Nonempty S
  /- `/\ S \subseteq available \cap unsat[c]` -/
  alloc c := alloc c ∪ S
  unsatisfy c := unsatisfy c \ S
}

-- Return(c,S) ==
--   /\ S # {} /\ S \subseteq alloc[c]
--   /\ alloc' = [alloc EXCEPT ![c] = @ \ S]
--   /\ UNCHANGED unsat
action Return (c : client) {
  /- `/\ S # {} /\ S \subseteq alloc[c]` -/
  let S ⊆ alloc c :| TSet.Nonempty S
  alloc c := alloc c \ S
}

-- Next ==
--   \E c \in Clients, S \in SUBSET Resources :
--      Request(c,S) \/ Allocate(c,S) \/ Return(c,S)
-- ResourceMutex ==
--   \A c1,c2 \in Clients : c1 # c2 => alloc[c1] \cap alloc[c2] = {}
invariant [resource_mutex] ∀ c1 c2 : client, c1 ≠ c2 → TSet.Disjoint (alloc c1) (alloc c2)
#gen_spec


#model_check
{ client := Fin 2, resource := Fin 2 }
{}

end SimpleAllocator
