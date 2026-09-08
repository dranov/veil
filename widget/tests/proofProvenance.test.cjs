const assert = require('node:assert/strict');
const test = require('node:test');
const ts = require('typescript');
const fs = require('node:fs');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022},
}).outputText, filename);
const { summarizeProofProvenance } = require('../src/proofProvenance.ts');
const proof = (overrides = {}) => ({ status: 'proven', proofProvenance: {
  hasAdmissions: false, trustsSmt: false, axioms: [], incomplete: false, ...overrides,
}});

test('separates solver trust, admissions, declared axioms, and unavailable provenance', () => {
  assert.deepEqual(summarizeProofProvenance([
    proof({ trustsSmt: true }), proof({ hasAdmissions: true }),
    proof({ axioms: ['propext', 'User.axiom', 'Classical.choice', 'Quot.sound'] }),
    proof({ axioms: ['User.axiom'] }), proof({ incomplete: true }),
    { status: 'proven', proofHasSorry: true },
  ]), { trustedCount: 1, admittedCount: 1, unavailableCount: 2, additionalAxioms: ['User.axiom'] });
});

test('a proof can both trust SMT and depend on a manual admission', () => {
  assert.deepEqual(summarizeProofProvenance([proof({ trustsSmt: true, hasAdmissions: true })]),
    { trustedCount: 1, admittedCount: 1, unavailableCount: 0, additionalAxioms: [] });
});

test('only active successful witnesses contribute', () => {
  const trusted = proof({ trustsSmt: true, hasAdmissions: true });
  assert.deepEqual(summarizeProofProvenance([
    {...trusted, status: 'error'}, {...trusted, isDormant: true}, {...trusted, status: null},
  ]), { trustedCount: 0, admittedCount: 0, unavailableCount: 0, additionalAxioms: [] });
});
