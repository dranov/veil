require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const {resultSummary} = require('../src/resultSelectors.ts');
test('trace queries, bounded searches, exhaustion and failures retain their meaning', () => {
  assert.equal(resultSummary({result:'found_trace'}).label, 'Satisfying Trace Found');
  assert.match(resultSummary({result:'no_violation_found',explored_states:2,termination_reason:{kind:'early_termination',condition:{kind:'reached_depth_bound',depth:1}}}).details, /Depth bound 1.*incomplete/);
  assert.equal(resultSummary({result:'no_violation_found',explored_states:2,termination_reason:{kind:'explored_all_reachable_states'}}).severity, 'success');
  assert.equal(resultSummary({error:'Compiler exited 17'}).details, 'Compiler exited 17');
  assert.equal(resultSummary({result:'found_violation',violation:{kind:'initialization_failure'}}).label, 'Initialization Assertion Failed');
});
