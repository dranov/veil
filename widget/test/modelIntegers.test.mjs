import assert from 'node:assert/strict';
import test from 'node:test';
import { renderToStaticMarkup } from 'react-dom/server';
import { exactIntegerDecimal, formatActionLabel, renderValueInline, renderValue, deepEqual } from '../dist/veilUtils.js';

test('tagged integers retain adjacent values, sign, display and label precision', () => {
  const a = JSON.parse('{"$veilInteger":"9007199254740993"}');
  const b = JSON.parse('{"$veilInteger":"9007199254740992"}');
  assert.equal(exactIntegerDecimal(a), '9007199254740993');
  assert.equal(deepEqual(a, b), false);
  assert.equal(renderToStaticMarkup(renderValueInline(a)), '<code>9007199254740993</code>');
  assert.equal(renderToStaticMarkup(renderValue(a)), '<code>9007199254740993</code>');
  assert.equal(formatActionLabel({send: {n: a}}), 'send(n = 9007199254740993)');
  assert.equal(exactIntegerDecimal({$veilInteger: '-9007199254740993'}), '-9007199254740993');
  assert.equal(exactIntegerDecimal({$veilInteger: '12oops'}), undefined);
  assert.equal(exactIntegerDecimal({$veilInteger: '12', data: true}), undefined);
});
