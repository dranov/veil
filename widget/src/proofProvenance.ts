export interface ProofProvenance {
  hasAdmissions: boolean;
  trustsSmt: boolean;
  /** All transitive axioms except sorryAx, which is represented by the flags. */
  axioms: string[];
  incomplete: boolean;
}

interface ProofResult {
  status?: string | null;
  isDormant?: boolean;
  proofProvenance?: ProofProvenance | null;
}

const standardAxioms = new Set(['propext', 'Classical.choice', 'Quot.sound']);

/** Never infer solver trust merely from an old proofHasSorry flag. */
export function summarizeProofProvenance(results: readonly ProofResult[]) {
  let trustedCount = 0;
  let admittedCount = 0;
  let unavailableCount = 0;
  const additionalAxioms = new Set<string>();
  for (const result of results) {
    if (result.status !== 'proven' || result.isDormant) continue;
    const provenance = result.proofProvenance;
    if (!provenance) {
      unavailableCount++;
      continue;
    }
    if (provenance.trustsSmt) trustedCount++;
    if (provenance.hasAdmissions) admittedCount++;
    if (provenance.incomplete) unavailableCount++;
    for (const axiom of provenance.axioms) {
      if (!standardAxioms.has(axiom)) additionalAxioms.add(axiom);
    }
  }
  return { trustedCount, admittedCount, unavailableCount,
    additionalAxioms: [...additionalAxioms].sort() };
}
