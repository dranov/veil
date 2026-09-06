require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const { getEffectiveStatus } = require('../src/verificationSelectors.ts');
const statuses = ['proven', 'disproven', null, 'error', 'timeout', 'unknown'];
test('related verification outcomes preserve pending and ignore dormant attempts', () => {
  for (const primary of statuses) for (const alternative of statuses) {
    const expected = statuses.find(s => s === primary || s === alternative);
    assert.equal(getEffectiveStatus({status: primary}, {status: alternative}), expected);
    assert.equal(getEffectiveStatus({status: primary}, {status: alternative, isDormant: true}), primary);
  }
});
