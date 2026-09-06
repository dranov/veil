import * as React from 'react';
import { createDiffCache, ChangeInfo } from './valueDiff';

const NO_CHANGES = new Map<string, ChangeInfo>();

/** Preserve diff results across unrelated controls and structurally unchanged RPC snapshots. */
export function useValueDiff(previous: Record<string, unknown> | null | undefined,
  current: Record<string, unknown>, enabled = true) {
  const diff = React.useMemo(createDiffCache, []);
  return enabled ? diff(previous, current) : NO_CHANGES;
}
