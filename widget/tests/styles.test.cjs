require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const {scopeStyles} = require('../src/scopeStyles.ts');
test('styles are scoped without changing root selectors, media rules or animation steps', () => {
  const css = scopeStyles('.vr-root', '.vr-root { color: red; } .row, .icon { color: blue; } @media (min-width: 1px) { .row {display: block;} } @keyframes pulse { from {opacity: 0;} to {opacity: 1;} }');
  assert.ok(css.includes('.vr-root .row, .vr-root .icon'));
  assert.ok(css.includes('@media (min-width: 1px) { .vr-root .row'));
  assert.ok(css.includes('from {opacity: 0;}'));
  assert.ok(!css.includes('.vr-root .vr-root'));
});

test('comments before selectors cannot bypass widget scoping', () => {
  assert.match(scopeStyles('.vr-root', '/* panel */ .state-card {color:red;}'), /\.vr-root \.state-card/);
});
