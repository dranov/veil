require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const { shortcutKey } = require('../src/shortcuts.ts');
test('shortcuts respect modifiers, editable controls and focused widget ownership', () => {
  const root = {};
  const event = {key: 'F', currentTarget: root, target: {closest: s => s === '[data-veil-shortcuts]' ? root : null}};
  assert.equal(shortcutKey(event), 'f');
  for (const flag of ['ctrlKey', 'metaKey', 'altKey', 'defaultPrevented', 'isComposing']) assert.equal(shortcutKey({...event, [flag]: true}), null);
  assert.equal(shortcutKey({...event, target: {closest: () => ({})}}), null);
  assert.equal(shortcutKey({...event, currentTarget: {}}), null);
});
