module

public import Veil

veil module SetType

type node
set_type Nodes : node
set_type Families : Nodes

individual seen : Nodes

after_init { seen := Nodes_set.empty }
action add (n : node) { seen := Nodes_set.insert n seen }
invariant Nodes_set.count seen ≥ 0

#gen_spec

-- Defaults are selected after the concrete element types are known, including
-- nested set carriers. An explicit carrier overrides the default.
example : ({ node := Fin 2 } : Instantiation).Nodes = Std.ExtTreeSet (Fin 2) := rfl
example : ({ node := Fin 2 } : Instantiation).Families =
    Std.ExtTreeSet (Std.ExtTreeSet (Fin 2)) := rfl
example : ({ node := Fin 2, Nodes := OrdList (Fin 2) } : Instantiation).Nodes =
    OrdList (Fin 2) := rfl

#model_check interpreted { node := Fin 2 } {}
#model_check interpreted { node := Fin 2, Nodes := OrdList (Fin 2) } {}
#model_check compiled { node := Fin 2 } {} (sequential := true)

end SetType
