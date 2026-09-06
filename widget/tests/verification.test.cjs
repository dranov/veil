require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const { getEffectiveStatus } = require('../src/verificationSelectors.ts');
const statuses = ['proven', 'disproven', null, 'error', 'timeout', 'unknown'];
test('related verification outcomes preserve pending and ignore dormant attempts', () => {
  for (const primary of statuses) for (const alternative of statuses) {
    const expected = statuses.find(s => s === primary || s === alternative);
    assert.equal(getEffectiveStatus({status: primary}, [{status: alternative}]), expected);
    assert.equal(getEffectiveStatus({status: primary}, [{status: alternative, isDormant: true}]), primary);
  }
});

test('all alternatives participate and styles come from metadata', () => {
  const { buildAlternativeMap, proofStyle, selectWitness } = require('../src/verificationSelectors.ts');
  const primary = { id: 1, status: 'unknown', metadata: {type: 'induction', data: {style: 'tr'}} };
  const alternatives = [{id: 2, alternativeFor: 1, status: 'proven', metadata: {type: 'induction', data: {style: 'wp'}}}, {id: 3, alternativeFor: 1, status: null}];
  assert.equal(buildAlternativeMap([primary, ...alternatives]).get(1).length, 2);
  assert.equal(getEffectiveStatus(primary, alternatives), 'proven');
  assert.equal(proofStyle(primary), 'TR');
  assert.equal(proofStyle(selectWitness(primary, alternatives)), 'WP');
});
