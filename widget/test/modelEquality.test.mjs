import assert from 'node:assert/strict';
import test from 'node:test';
import { deepEqual } from '../dist/veilUtils.js';

test('JSON equality distinguishes arrays, objects, nulls and primitive kinds', () => {
  assert.equal(deepEqual([], {}), false);
  assert.equal(deepEqual([1], {'0': 1}), false);
  assert.equal(deepEqual({value: []}, {value: {}}), false);
  assert.equal(deepEqual(null, {}), false);
  assert.equal(deepEqual('1', 1), false);
  assert.equal(deepEqual({a: [1, {b: null}]}, {a: [1, {b: null}]}), true);
  assert.equal(deepEqual({a: 1}, Object.assign(Object.create({a: 1}), {b: 1})), false);
});
