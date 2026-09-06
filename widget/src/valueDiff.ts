/** Maximum DP cells, independent of the size of the displayed counterexample. */
export const MAX_DIFF_CELLS = 250_000;
export function withinDiffBudget(previousLength: number, currentLength: number): boolean {
  return (previousLength + 1) * (currentLength + 1) <= MAX_DIFF_CELLS;
}

// ========== Types ==========

/** Merged element for array diff display */
export interface MergedElement {
  element: unknown;
  status: 'unchanged' | 'added' | 'removed';
}

/** Value change info: either the whole value changed, or specific array indices changed */
export type ChangeInfo =
  | { type: 'full' }  // Entire value changed (non-array or structural change)
  | { type: 'array'; mergedView: MergedElement[] }  // Array with merged view showing elements in original order
  | { type: 'none' };  // No change

// ========== Diff Helpers ==========

/** Deep equality comparison for values */
export function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a == null || b == null) return a === b;

  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!deepEqual(a[i], b[i])) return false;
    }
    return true;
  }

  if (typeof a === 'object' && typeof b === 'object') {
    const ao = a as Record<string, unknown>;
    const bo = b as Record<string, unknown>;
    const ak = Object.keys(ao);
    const bk = Object.keys(bo);
    if (ak.length !== bk.length) return false;
    for (const k of ak) {
      if (!(k in bo)) return false;
      if (!deepEqual(ao[k], bo[k])) return false;
    }
    return true;
  }

  return false;
}

/**
 * Compute LCS (Longest Common Subsequence) using dynamic programming.
 * Returns array of [prevIndex, currIndex] pairs representing matched elements.
 */
function computeLCS(prev: unknown[], curr: unknown[]): [number, number][] {
  const m = prev.length;
  const n = curr.length;

  // Build DP table
  const dp: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      if (deepEqual(prev[i - 1], curr[j - 1])) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  // Backtrack to find the LCS indices
  const lcs: [number, number][] = [];
  let i = m, j = n;
  while (i > 0 && j > 0) {
    if (deepEqual(prev[i - 1], curr[j - 1])) {
      lcs.unshift([i - 1, j - 1]);
      i--;
      j--;
    } else if (dp[i - 1][j] > dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }

  return lcs;
}

/**
 * Compute a merged view using LCS-based diff algorithm.
 * Additions and removals appear at their correct positions.
 */
export function computeMergedView(prev: unknown[], curr: unknown[]): MergedElement[] {
  if (!withinDiffBudget(prev.length, curr.length)) {
    return [...prev.map(element => ({element, status: 'removed' as const})),
      ...curr.map(element => ({element, status: 'added' as const}))];
  }
  const lcs = computeLCS(prev, curr);
  const result: MergedElement[] = [];

  let prevIdx = 0;
  let currIdx = 0;
  let lcsIdx = 0;

  while (prevIdx < prev.length || currIdx < curr.length) {
    const lcsMatch = lcsIdx < lcs.length ? lcs[lcsIdx] : null;

    if (lcsMatch && prevIdx === lcsMatch[0] && currIdx === lcsMatch[1]) {
      // This element is in the LCS - it's unchanged
      result.push({ element: curr[currIdx], status: 'unchanged' });
      prevIdx++;
      currIdx++;
      lcsIdx++;
    } else {
      // Not at an LCS match point - emit removals from prev, then additions from curr

      // Emit all removals up to the next LCS match (or end of prev)
      const nextPrevMatch = lcsMatch ? lcsMatch[0] : prev.length;
      while (prevIdx < nextPrevMatch) {
        result.push({ element: prev[prevIdx], status: 'removed' });
        prevIdx++;
      }

      // Emit all additions up to the next LCS match (or end of curr)
      const nextCurrMatch = lcsMatch ? lcsMatch[1] : curr.length;
      while (currIdx < nextCurrMatch) {
        result.push({ element: curr[currIdx], status: 'added' });
        currIdx++;
      }
    }
  }

  return result;
}

/** Compute change information for each field between prev and curr state */
export function diffChanges(
  prev: Record<string, unknown> | undefined | null,
  curr: Record<string, unknown>
): Map<string, ChangeInfo> {
  const changes = new Map<string, ChangeInfo>();
  if (!prev) return changes;

  const keys = new Set<string>([...Object.keys(prev), ...Object.keys(curr)]);
  for (const k of keys) {
    const hasA = k in prev;
    const hasB = k in curr;

    if (!hasA || !hasB) {
      changes.set(k, { type: 'full' });
      continue;
    }

    const prevVal = prev[k];
    const currVal = curr[k];

    if (deepEqual(prevVal, currVal)) {
      continue;
    }

    if (Array.isArray(prevVal) && Array.isArray(currVal)) {
      if (!withinDiffBudget(prevVal.length, currVal.length)) {
        changes.set(k, {type: 'full'});
        continue;
      }
      // Compute merged view with elements in original order
      const mergedView = computeMergedView(prevVal, currVal);
      // Only mark as changed if there are actual additions or removals
      const hasChanges = mergedView.some(m => m.status !== 'unchanged');
      if (hasChanges) {
        changes.set(k, { type: 'array', mergedView });
      }
    } else {
      changes.set(k, { type: 'full' });
    }
  }

  return changes;
}

/** Keep one immutable state pair, including equivalent snapshots decoded by a later RPC refresh. */
export function createDiffCache() {
  let previous: Record<string, unknown> | null | undefined;
  let current: Record<string, unknown> | undefined;
  let changes: Map<string, ChangeInfo>;
  return (nextPrevious: Record<string, unknown> | null | undefined, nextCurrent: Record<string, unknown>) => {
    if (current !== undefined && deepEqual(previous, nextPrevious) && deepEqual(current, nextCurrent)) return changes;
    previous = nextPrevious;
    current = nextCurrent;
    changes = diffChanges(previous, current);
    return changes;
  };
}
