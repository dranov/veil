import type { VerificationCondition } from './protocol';

const EFFECTIVE_STATUS_ORDER: VerificationCondition['status'][] = [
  'proven',
  'disproven',
  null,
  'error',
  'timeout',
  'unknown',
];

function getActiveStatuses(
  vc: VerificationCondition,
  alternatives: VerificationCondition[] = []
): VerificationCondition['status'][] {
  const statuses: VerificationCondition['status'][] = [vc.status];
  statuses.push(...alternatives.filter(vc => !vc.isDormant).map(vc => vc.status));
  return statuses;
}

export function getEffectiveStatus(
  vc: VerificationCondition,
  alternatives: VerificationCondition[] = []
): VerificationCondition['status'] {
  const statuses = getActiveStatuses(vc, alternatives);
  const selected = EFFECTIVE_STATUS_ORDER.find(status => statuses.includes(status));
  return selected === undefined ? vc.status : selected;
}


export function buildAlternativeMap(vcs: VerificationCondition[]): Map<number, VerificationCondition[]> {
  const map = new Map<number, VerificationCondition[]>();
  for (const vc of vcs) {
    if (vc.alternativeFor != null) {
      const alternatives = map.get(vc.alternativeFor) ?? [];
      alternatives.push(vc);
      map.set(vc.alternativeFor, alternatives);
    }
  }
  return map;
}

export function proofStyle(vc: VerificationCondition): string {
  return vc.metadata.type === 'induction' ? vc.metadata.data.style?.toUpperCase() ?? 'Proof' : 'Trace';
}

export function firstCounterexample(vc: VerificationCondition) {
  if (vc.status !== 'disproven') return null;
  for (const discharger of vc.timing.dischargers) {
    const counterexample = discharger.result?.data?.counterexamples?.[0];
    if (counterexample) return counterexample;
  }
  return null;
}

export function selectWitness(vc: VerificationCondition, alternatives: VerificationCondition[] = []) {
  const active = [vc, ...alternatives.filter(v => !v.isDormant)];
  const status = getEffectiveStatus(vc, alternatives);
  return active.find(v => v.status === status) ?? vc;
}
