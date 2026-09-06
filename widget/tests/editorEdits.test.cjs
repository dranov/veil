require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const { insertionText, insertionEdit } = require('../src/editorEdits.ts');
test('theorem insertion separates commands, handles EOF and normalizes CRLF', () => {
  const theorem = 'theorem example : True := by\r\n  sorry';
  for (const suffix of ['end Foo', '\nend Foo', '']) {
    assert.match(insertionText(theorem) + suffix, /sorry\n\n/);
    assert.ok(!(insertionText(theorem) + suffix).includes('sorryend'));
  }
  const edit = insertionEdit('file:///test', 17, {line: 3, character: 0}, theorem);
  assert.equal(edit.documentChanges[0].textDocument.version, 17);
});

test('server rejection diagnostics remain readable', () => {
  const {insertionErrorMessage} = require('../src/editorEdits.ts');
  assert.equal(insertionErrorMessage({code: -32602, message: 'The document changed.'}), 'The document changed.');
});
