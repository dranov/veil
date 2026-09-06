require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const {diffChanges, computeMergedView, withinDiffBudget, MAX_DIFF_CELLS} = require('../src/valueDiff.ts');
test('small sequence diffs preserve additions and removals in order', () => {
  assert.deepEqual(computeMergedView([1,2,3], [1,4,3]).map(x => [x.element,x.status]), [[1,'unchanged'],[2,'removed'],[4,'added'],[3,'unchanged']]);
});
test('large counterexamples fall back before quadratic allocation', () => {
  const previous = Array.from({length: 10000}, (_, i) => i);
  const current = previous.slice(); current[5000] = -1;
  assert.equal(withinDiffBudget(10000,10000), false);
  assert.equal(withinDiffBudget(1,MAX_DIFF_CELLS), false);
  assert.equal(diffChanges({values:previous}, {values:current}).get('values').type, 'full');
  assert.equal(diffChanges({values:previous}, {values:previous.slice()}).size, 0);
});

test('fresh RPC snapshots reuse alignment until state values actually change', () => {
  const {createDiffCache} = require('../src/valueDiff.ts');
  const diff = createDiffCache();
  const first = diff({values:[1,2,3]}, {values:[1,4,3]});
  assert.equal(diff({values:[1,2,3]}, {values:[1,4,3]}), first);
  assert.notEqual(diff({values:[1,2,3]}, {values:[1,5,3]}), first);
});
