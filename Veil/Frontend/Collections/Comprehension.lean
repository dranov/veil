module
public import Veil.Frontend.Collections.Basic
public meta import Veil.Frontend.Collections.Basic
@[expose] public section
open Veil

namespace TSet

/-- Exact filtering over the members of a finite collection. -/
def filterWhere [TSet α κ] (s : κ) (p : α → Prop) [DecidablePred p] : κ :=
  TSet.filter s (fun x => decide (p x))

/-- Exact comprehension over an explicitly enumerable type. -/
def comprehension (α : Type u) [Enumeration α] [TSet α κ]
    (p : α → Prop) [DecidablePred p] : κ :=
  TSet.ofList (Enumeration.allValues (α := α) |>.filter (fun x => decide (p x)))

@[simp] theorem mem_filterWhere [TSet α κ] [LawfulTSet α κ]
    (x : α) (s : κ) (p : α → Prop) [DecidablePred p] :
    x ∈ filterWhere s p ↔ x ∈ s ∧ p x := by
  simp [filterWhere, LawfulTSet.mem_filter]

@[simp] theorem mem_comprehension [Enumeration α] [TSet α κ] [LawfulTSet α κ]
    (x : α) (p : α → Prop) [DecidablePred p] :
    x ∈ (comprehension α p : κ) ↔ p x := by
  simp [comprehension, LawfulTSet.mem_ofList, Enumeration.complete]

end TSet

namespace Veil
-- Prefer filtering when both sides of `|` contain membership. Otherwise a
-- predicate such as `m.sender ∈ senders` can be parsed as an image binder.
scoped syntax (name := boundedSetComprehension) (priority := high)
  "{" ident " ∈ " term " | " term "}" : term
scoped syntax (name := finiteSetComprehension) "{" ident " : " term " | " term "}" : term
macro_rules
  | `({$x:ident ∈ $s:term | $p:term}) => `(TSet.filterWhere $s (fun $x => $p))
  | `({$x:ident : $t:term | $p:term}) => `(TSet.comprehension $t (fun $x => $p))
end Veil
