require('./load.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const React = require('react');
const {renderToStaticMarkup} = require('react-dom/server');
const Module = require('node:module');
const originalLoad = Module._load;
const editorContext = React.createContext({api: {}});
Module._load = function(name, ...args) {
  if (name === '@leanprover/infoview') return {EditorContext: editorContext, useRpcSession: () => ({call: async () => 1})};
  return originalLoad.call(this, name, ...args);
};
const VerificationResults = require('../src/verificationResults.tsx').default;
const TraceDisplay = require('../src/traceDisplay.tsx').default;
Module._load = originalLoad;

const vc = (id, status, style, extra = {}) => ({id, name: `vc${id}`, status,
  metadata: {type:'induction', data:{property:'safe', action:'step', style}},
  timing:{totalTime:1, dischargers:[]}, theoremText:'theorem safe := by sorry', ...extra});

function renderVerification(vcs) {
  return renderToStaticMarkup(React.createElement(VerificationResults, {
    results: {vcs,totalVCs:vcs.length,totalSolved:0,totalDischarged:0,serverTime:10},
    theoremInsertPos:{line:1,character:0},documentUri:'file:///test',insertionSourceHash:'123',
  }));
}

test('real verification rows keep a running alternative pending and label native transition styles', () => {
  const html = renderVerification([vc(1,'unknown','tr'),vc(2,null,'wp',{alternativeFor:1})]);
  assert.match(html, /property-row status-pending/);
  assert.doesNotMatch(html, /Insert to prove interactively/);
  assert.match(html, />TR<\/span>/);
  assert.match(html, />WP\.\.\.<\/span>/);
});

test('every alternative participates in the real verification view', () => {
  const html = renderVerification([vc(1,'unknown','tr'),vc(2,'proven','wp',{alternativeFor:1}),vc(3,'error','wp',{alternativeFor:1})]);
  assert.match(html, /property-row status-proven/);
  assert.doesNotMatch(html, /Insert to prove interactively/);
});

test('trace view shows failed compilation and dedicated initializer witness', () => {
  const failure = renderToStaticMarkup(React.createElement(TraceDisplay, {result:{error:'Compiler exited 17'}}));
  assert.match(failure,/Model Checking Failed/);
  assert.match(failure,/Compiler exited 17/);
  const init = renderToStaticMarkup(React.createElement(TraceDisplay, {result:{result:'found_violation',violation:{kind:'initialization_failure'},trace:null,initialization:{theory:{},state:{n:1}}}}));
  assert.match(init,/Initialization Assertion Failed/);
  assert.match(init,/State at initializer failure/);
});

test('large traces initially render only the first page', () => {
  const states = Array.from({length:250},(_,index)=>({index,fields:{n:index},transition:'step'}));
  const html = renderToStaticMarkup(React.createElement(TraceDisplay,{result:{trace:{theory:{},states}}}));
  assert.equal((html.match(/class="state-card/g) ?? []).length,100);
  assert.match(html,/Show next 100 states/);
});

test('trust banner counts selected proof witnesses once per visible obligation', () => {
  const proven = vc(1,'proven','tr');
  const trustedAlternative = vc(2,'proven','wp',{alternativeFor:1,proofHasSorry:true});
  assert.doesNotMatch(renderVerification([proven,trustedAlternative]),/Trusting SMT solver/);
  const html = renderVerification([vc(1,'unknown','tr'),trustedAlternative,vc(3,'proven','wp',{alternativeFor:1,proofHasSorry:true})]);
  assert.match(html,/Trusting SMT solver for 1 goal/);
});
