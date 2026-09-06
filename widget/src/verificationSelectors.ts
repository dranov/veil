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
  alternativeVC?: VerificationCondition
): VerificationCondition['status'][] {
  const statuses: VerificationCondition['status'][] = [vc.status];
  if (alternativeVC && !alternativeVC.isDormant) {
    statuses.push(alternativeVC.status);
  }
  return statuses;
}

export function getEffectiveStatus(
  vc: VerificationCondition,
  alternativeVC?: VerificationCondition
): VerificationCondition['status'] {
  const statuses = getActiveStatuses(vc, alternativeVC);
  const selected = EFFECTIVE_STATUS_ORDER.find(status => statuses.includes(status));
  return selected === undefined ? vc.status : selected;
}

