module

public import Veil.Frontend.Collections.Cardinality
public meta import Veil.Frontend.Collections.Cardinality

@[expose] public section
open Veil

namespace Veil

/-- Cardinality of a finite type, independent of its set carrier. -/
abbrev typeCard (α : Type u) [FinEncodable α] : Nat := FinEncodable.card (α := α)
end Veil

namespace TSet

/-- All values of an explicitly enumerable type. -/
def univ (α : Type u) [Enumeration α] [TSet α κ] : κ :=
  TSet.ofList (Enumeration.allValues (α := α))

/-- Inclusive natural-number interval; descending intervals are empty. -/
def interval [TSet Nat κ] (lo hi : Nat) : κ :=
  TSet.ofList (List.range' lo (hi + 1 - lo))

/-- Inclusive integer interval, including negative endpoints. -/
def intInterval [TSet Int κ] (lo hi : Int) : κ :=
  TSet.ofList ((List.range (hi - lo + 1).toNat).map (fun (n : Nat) => lo + (n : Int)))

@[simp] theorem mem_univ [Enumeration α] [TSet α κ] [LawfulTSet α κ] (x : α) :
    x ∈ (univ α : κ) := by simp [univ, LawfulTSet.mem_ofList, Enumeration.complete]

@[simp] theorem mem_interval [TSet Nat κ] [LawfulTSet Nat κ] (x lo hi : Nat) :
    x ∈ (interval lo hi : κ) ↔ lo ≤ x ∧ x ≤ hi := by
  simp only [interval, LawfulTSet.mem_ofList, List.mem_range'_1]
  omega

@[simp] theorem mem_intInterval [TSet Int κ] [LawfulTSet Int κ] (x lo hi : Int) :
    x ∈ (intInterval lo hi : κ) ↔ lo ≤ x ∧ x ≤ hi := by
  simp only [intInterval, LawfulTSet.mem_ofList, List.mem_map, List.mem_range]
  constructor
  · rintro ⟨n, hn, rfl⟩; omega
  · intro ⟨hlo, hhi⟩
    exact ⟨(x - lo).toNat, by omega, by omega⟩

@[simp] theorem card_interval [TSet Nat κ] [LawfulTSet Nat κ] (lo hi : Nat) :
    Veil.card (interval lo hi : κ) = hi + 1 - lo := by
  rw [interval, card_ofList_of_nodup _ (List.nodup_range' _), List.length_range']
end TSet

namespace Veil

scoped macro "{" lo:term " ..= " hi:term "}" : term => `(TSet.interval $lo $hi)
end Veil

end
