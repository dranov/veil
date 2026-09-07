import assert from 'node:assert/strict';
import test from 'node:test';
import { renderToStaticMarkup } from 'react-dom/server';
import { formatActionLabel, renderValueInline, renderValue } from '../dist/veilUtils.js';

test('ordinary strings retain punctuation, namespaces and whitespace', () => {
  for (const value of ['node.example.org', 'hello, world!', '(value)', 'A.B.ctor', '  spaced  value  ']) {
    assert.equal(renderToStaticMarkup(renderValueInline(value)), `<code>${value}</code>`);
    assert.equal(renderToStaticMarkup(renderValue(value)), `<code>${value}</code>`);
    assert.equal(formatActionLabel({send: {message: value}}), `send(message = ${value})`);
  }
});
