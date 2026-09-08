import Veil.Util.FiniteTypes
import Veil.Frontend.DSL.Module.Names

/-! # State representation tactics

The generic finite-type API is re-exported from `Veil.Util.FiniteTypes` for
existing imports. Only representation-specific tactics belong in this layer.
-/

namespace Veil

open Lean in
macro "dsimp_state_representation" : tactic =>
  `(tactic| (try dsimp only [$fieldConcreteDispatcher:ident]) <;> (try dsimp only [$fieldAbstractDispatcher:ident]) <;>
   (try dsimp only [$instFieldRepresentation:ident]) <;> (try dsimp only [$instAbstractFieldRepresentation:ident]) <;>
   (try dsimp only [$(mkIdent ``IteratedProd'):ident, $(mkIdent `State.Label.toDomain):ident, $(mkIdent `State.Label.toCodomain):ident, $(mkIdent ``id):ident]) <;>
   (try dsimp))
open Lean in
macro "infer_instance_for_iterated_prod'" : tactic =>
  `(tactic| dsimp_state_representation <;> infer_instance)


end Veil
