import Veil.Core.Tools.ModelChecker.ParallelConfig
import Mathlib.Tactic.DeriveFintype

/-! # Compatibility API for array chunking

Current exploration uses `ListSplit` and `IteratedProd.taskSplit`. The older
array chunking functions and their proofs remain public, so retain them here
and re-export them from `Interface` rather than deleting external APIs based
only on the absence of repository callers. New scheduler code should use the
active split API and import `ParallelConfig` for configuration alone.
-/

namespace Veil.ModelChecker
open Lean

/-- Core chunking logic: split `[0, totalSize)` into `numSplits` ranges.
Returns a list of `(left, right)` index pairs. -/
def computeChunkRanges (numSplits : Nat) (totalSize : Nat) : List (Nat × Nat) :=
  let numSplits := max 1 numSplits
  let chunkSize := totalSize / numSplits
  List.range numSplits |>.map fun i =>
    let l := i * chunkSize
    let r := if i == numSplits - 1 then totalSize else (i + 1) * chunkSize
    (l, r)

/-- Compute chunk ranges for splitting a worklist, with threshold check.
Returns a list of (left, right) index pairs representing subarrays. -/
def ParallelConfig.chunkRanges (cfg : ParallelConfig) (totalSize : Nat) : List (Nat × Nat) :=
  if totalSize < cfg.thresholdToParallel then
    [(0, totalSize)]
  else
    computeChunkRanges cfg.numSubTasks totalSize

/-- ParallelConfig.chunkRanges produces valid ranges (within bounds). -/
theorem ParallelConfig.chunkRanges_valid (cfg : ParallelConfig) (n : Nat) :
  ∀ lr ∈ cfg.chunkRanges n, lr.1 ≤ lr.2 ∧ lr.2 ≤ n := by
  intro lr h_lr_in
  unfold ParallelConfig.chunkRanges at h_lr_in
  split at h_lr_in
  · simp at h_lr_in
    grind
  · rename_i h_not_small
    simp at h_not_small
    unfold computeChunkRanges at h_lr_in
    simp [List.mem_map] at h_lr_in
    obtain ⟨i, h_i_in, h_lr_eq⟩ := h_lr_in
    split
    . simp
    . simp
      rename_i h_lr_eq
      apply Nat.div_le_self
    constructor
    . rename_i h_lr_eq
      obtain ⟨a, h_a_lt, h_eq⟩ := h_lr_eq
      rw [← h_eq]
      dsimp
      split_ifs
      · apply Nat.le_trans (Nat.mul_le_mul_right _ (Nat.le_of_lt (Nat.lt_of_lt_of_le h_a_lt (le_max_right _ _))))
        rw [Nat.mul_comm]
        apply Nat.div_mul_le_self
      · apply Nat.mul_le_mul_right
        apply Nat.le_succ
    . rename_i h_lr_eq
      obtain ⟨a, h_a_lt, h_eq⟩ := h_lr_eq
      rw [← h_eq]; dsimp
      split_ifs <;> try apply Nat.le_refl
      trans (max 1 cfg.numSubTasks) * (n / max 1 cfg.numSubTasks)
      · apply Nat.mul_le_mul_right; omega
      · rw [Nat.mul_comm]; apply Nat.div_mul_le_self


/-- ParallelConfig.chunkRanges covers all indices. -/
theorem ParallelConfig.chunkRanges_cover (cfg : ParallelConfig) (n : Nat) :
  ∀ i, i < n → ∃ lr ∈ cfg.chunkRanges n, lr.1 ≤ i ∧ i < lr.2 := by
  intro i h_i_lt
  unfold ParallelConfig.chunkRanges
  split
  · exists (0, n)
    simp
    omega
  · rename_i h_not_small
    unfold computeChunkRanges
    let k := max 1 cfg.numSubTasks
    let s := n / k
    have hk_pos : 0 < k := Nat.le_max_left 1 _
    let idx := if i < (k - 1) * s then i / s else k - 1
    let l := idx * s
    let r := if idx == k - 1 then n else (idx + 1) * s
    exists (l, r)
    constructor
    · apply List.mem_map_of_mem
      rw [List.mem_range]
      dsimp [idx]
      split_ifs with h_cond
      · have hs_pos : 0 < s := Nat.pos_of_ne_zero (fun h => by simp [h] at h_cond)
        calc
          i / s < k - 1 := Nat.div_lt_of_lt_mul (by grind)
          _     < k     := Nat.pred_lt (by grind)
      · apply Nat.pred_lt (by grind)
    . simp
      constructor
      . dsimp [l, idx]
        split_ifs with h_cond
        . exact Nat.div_mul_le_self i s
        . omega
      . dsimp [r]
        split_ifs with h_is_last
        . exact h_i_lt
        . simp [idx] at h_is_last
          have h_idx_val : idx = i / s := by
            dsimp [idx]; split_ifs; rfl; grind
          rw [h_idx_val]
          rw [Nat.add_mul]
          rw [Nat.one_mul]
          apply Nat.lt_div_mul_add
          refine Nat.pos_of_ne_zero (fun h_s_zero => ?_)
          have h_lt := h_is_last.1
          rw [h_s_zero, Nat.mul_zero] at h_lt
          exact Nat.not_lt_zero i h_lt


def ParallelConfig.taskSplit (cfg : ParallelConfig) (f : Array α → IO β) (worklist : Array α)
  : IO (List (Task (Except IO.Error β))) := do
  if worklist.size < cfg.thresholdToParallel then
    return [← IO.asTask (f worklist)]
  else
    let numSubTasks := max 1 cfg.numSubTasks
    let chunkSize := worklist.size / numSubTasks
    List.range numSubTasks |>.mapM fun i => do
      let l := i * chunkSize
      let r := if i == numSubTasks - 1 then worklist.size else (i + 1) * chunkSize
      IO.asTask (f (worklist.toSubarray l r))


end Veil.ModelChecker
