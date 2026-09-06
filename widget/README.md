Veil widgets
============

Run `npm ci`, `npm test`, and `npm run build` in this directory. The build type-checks
all sources (including unused locals) and creates the bundles consumed by Lean.
`lake build VeilTest` also checks the public trace command and text result labels.
The component tests render the production React views with an editor transport
stub; they do not replace a VS Code interaction smoke test.

The main boundaries are:

- `protocol.ts`: Lean JSON/RPC data, with separate induction/trace metadata and
  model-checking result variants.
- `verificationSelectors.ts` and `resultSelectors.ts`: pure result decisions.
  Alternatives are a group, and proof style comes from metadata. Pending is a
  meaningful `null`, not a missing selection.
- `editorInsertion.tsx` and `editorEdits.ts`: insertion uses a validated source
  anchor and the server's URI/version. A changed document requires fresh results.
- `valueDiff.ts`: sequence alignment is limited to 250,000 cells. Larger changed
  arrays receive a whole-field change marker instead of allocating a matrix.
- `fieldVisibility.tsx` and `useWidgetShortcuts.ts`: shared controls; shortcuts
  belong to a focused widget and never consume modified/editor input events.
- `sharedStyles.ts` and the component style modules: static styles scoped to the
  corresponding widget root, with namespaced animations.

A satisfying symbolic query uses `found_trace`. Concrete `no_violation_found`
results retain their termination reason and distinguish complete exhaustion from
an incomplete bounded search. Error objects have an `error` field without a
`result` tag. An initializer failure may carry a separate `initialization`
witness; it is displayed independently from successfully reached trace states.

Trace views initially render 100 states and expose subsequent pages explicitly.
Collapsed state diffs and hidden JSON are not computed. The JSON value codec and
proof-admission provenance are owned by their separate backend workstreams.
