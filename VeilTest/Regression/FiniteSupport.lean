import Veil

open Veil

-- Equality and hashing must ignore insertion order and erased default writes.
private def base : FiniteSupportMap Nat Nat := ⟨5, {}⟩
private def leftFirst := base.insert 0 7 |>.insert 1 9
private def rightFirst := base.insert 1 9 |>.insert 0 7
#guard leftFirst == rightFirst
#guard hash leftFirst == hash rightFirst
#guard leftFirst.get 0 == 7 && leftFirst.get 1 == 9 && leftFirst.get 200 == 5
#guard (base.insert 0 7 |>.insert 0 5) == base
#guard hash (base.insert 0 7 |>.insert 0 5) == hash base

private abbrev NatRelation := NotNecessarilyFinmapLikeUpdates.HybridFinmapLike Nat [Nat] Bool
@[implicit_reducible] private def natRelationRep : FieldRepresentation [Nat] Bool NatRelation :=
  NotNecessarilyFinmapLikeUpdates.instHybridFinmapLikeAsFieldRep
    (IteratedProd'.equiv (ts := [Nat])) (⟨⟨none⟩, ()⟩) (⟨inferInstance, ()⟩)
private def explicitEmpty : NatRelation := natRelationRep.set [((none, ()), .constant false)] default
#guard explicitEmpty == (default : NatRelation)
#guard hash explicitEmpty == hash (default : NatRelation)
private def populated := natRelationRep.set [((some 0, ()), .constant true)] explicitEmpty
private def reset := natRelationRep.set [((none, ()), .constant false)] populated
#guard reset == explicitEmpty
#guard hash reset == hash explicitEmpty
private def cofinite := natRelationRep.set [((none, ()), .constant true)] populated
#guard natRelationRep.get cofinite 1000
private def cofiniteWithHole := natRelationRep.set [((some 0, ()), .constant false)] cofinite
#guard !natRelationRep.get cofiniteWithHole 0 && natRelationRep.get cofiniteWithHole 1000
#guard cofinite != cofiniteWithHole

-- A complete reset can recover a finite representation even from an opaque field.
private def opaqueRelation : NatRelation := .canonical ⟨fun n => n == 0⟩
#guard !ModelCheckRepresentation.isRepresentable opaqueRelation
#guard natRelationRep.set [((none, ()), .constant false)] opaqueRelation == explicitEmpty

veil module FunctionDefaults
function f : Nat → Nat
after_init { f N := 5 }
action a { require f 0 = 5; f 0 := 7 }
action b { require f 0 = 7; f 1 := 9 }
action reset { f N := 5 }
invariant [f1_unchanged] f 1 ≠ 9
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: f1_unchanged)
  State 0 (via init):
    f = {default: 5, entries: []}
  State 1 (via a):
    f = {default: 5, entries: [[0, 7]]}
  State 2 (via b):
    f = {default: 5, entries: [[0, 7], [1, 9]]}
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end FunctionDefaults

veil module CofiniteRelation
relation r : Nat → Bool
after_init { r N := true }
action a { r 0 := false }
action b { require ¬ r 0; r 1 := false }
invariant [r1_true] r 1
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: r1_true)
  State 0 (via init):
    r = {default: true, entries: []}
  State 1 (via a):
    r = {default: true, entries: [[0, false]]}
  State 2 (via b):
    r = {default: true, entries: [[0, false], [1, false]]}
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end CofiniteRelation

veil module PartialInfiniteUpdate
relation r : Nat → Nat → Bool
after_init { r N M := false }
action row { r N 0 := true }
invariant True
termination True
#gen_spec
/--
error: 💥 Error: Cannot model check: state field 'r' cannot be fully represented. An assignment over a non-enumerable domain produced an opaque function, so distinct states cannot be distinguished. Use a finite domain or finite point updates.
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end PartialInfiniteUpdate

veil module MixedDomainRelation
relation r : Nat → Bool → Bool
after_init { r N B := false }
action a { r 0 B := true }
action b { require r 0 true; r 1 true := true }
invariant [r1_false] ¬ r 1 true
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: r1_false)
  State 0 (via init):
    r = []
  State 1 (via a):
    r = [[0, false], [0, true]]
  State 2 (via b):
    r = [[0, false], [0, true], [1, true]]
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end MixedDomainRelation

veil module CapturedDefault
function f : Nat → Nat
after_init { f N := 5 }
action update { f 0 := 7; f N := f 0 }
invariant [f1_unchanged] f 1 = 5
termination True
#gen_spec
/--
error: ❌ Violation: safety_failure (violates: f1_unchanged)
  State 0 (via init):
    f = {default: 5, entries: []}
  State 1 (via update):
    f = {default: 7, entries: []}
-/
#guard_msgs in
#model_check interpreted {} {} (sequential := true)
end CapturedDefault

-- Symbolic verification uses exactly the same update semantics.
veil module ConstantResetProof
function f : Nat → Nat
after_init { f N := 5 }
action reset { f N := 5 }
invariant [default_preserved] f 17 = 5
termination True
#gen_spec
#guard_msgs(error, warning) in
#check_invariants
end ConstantResetProof
