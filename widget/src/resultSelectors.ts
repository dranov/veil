import type { ModelCheckingResult } from './protocol';

export function resultSummary(result: ModelCheckingResult) {
  if ('error' in result) return {severity: 'violation', icon: '💥', label: 'Model Checking Failed', details: result.error};
  if (!('result' in result)) return null;
  switch (result.result) {
    case 'found_trace': return {severity: 'success', icon: '✓', label: 'Satisfying Trace Found', details: 'The requested trace query is satisfiable.'};
    case 'cancelled': return {severity: 'cancelled', icon: '⊘', label: 'Cancelled', details: 'Model checking was cancelled before completion.'};
    case 'found_violation': {
      const violation = result.violation;
      const labels = {deadlock: 'Deadlock Detected', assertion_failure: 'Assertion Failed', initialization_failure: 'Initialization Assertion Failed', assumption_failure: 'Assumption Violation Found', safety_failure: 'Safety Violation Found'};
      const info = violation.assertion_info;
      return {severity: 'violation', icon: '⚠️', label: labels[violation.kind], details: info
        ? `${info.moduleName}.${info.procedureName} (line ${info.line}, column ${info.column})`
        : violation.violates?.join(', ')};
    }
    case 'no_violation_found': {
      const reason = result.termination_reason;
      const exhausted = reason?.kind === 'explored_all_reachable_states';
      const bound = reason?.condition?.kind === 'reached_depth_bound' ? reason.condition.depth : undefined;
      return {severity: exhausted ? 'success' : 'cancelled', icon: exhausted ? '✓' : '⚠️',
        label: exhausted ? 'No Violation — Search Exhausted' : 'No Violation Within Search Bounds',
        details: `${bound === undefined ? '' : `Depth bound ${bound}. `}Explored ${result.explored_states} states.${exhausted ? '' : ' Search is incomplete.'}`};
    }
  }
}
