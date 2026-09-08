# Counterexample data and presentation

A SAT result retains the solver's `Smt.Model` independently of presentation.
`rawText` is a copyable expression-level fallback. Optional `html` may be null;
`structuredJson` may be null or contain independent unavailable sections.
`diagnostics` explains failed projections and explicit default completion.

`defaultedMissing` means the solver did not provide an interpretation and Veil
used an `Inhabited` default for display. Absence does not establish that the
value was unconstrained. `decodeError` identifies a value that was present but
could not be decoded or rendered. A `$veilUnavailable` object replaces an
unsupported serialized section; other sections remain available. Failure to
construct the typed state itself can still make the entire structured projection
unavailable, but cannot remove the raw witness.

Both symbolic projections and concrete trace payloads encode integer values
outside JavaScript's exact range as `{"$veilInteger":"9007199254740993"}`.
This reserved single-key object stores an exact decimal; consumers must not
convert it through JavaScript `Number`. Bitvector values use their unsigned
value. Strings remain ordinary data, including punctuation and qualified-looking
text. JSON copies preserve the tagged representation.

Symbolic trace names are an internal protocol. Action names use a length-prefixed
payload; action and parameter names encode their actual Lean name components.
Pretty-printed names are not a reversible identifier encoding.

Validation commands:

```bash
lake build VeilTest
cd widget
npm run build
node --test test/*.test.mjs
```

Integration with the independent widget-results branch requires moving the mixed
JSON-kind equality fix into its extracted `valueDiff.ts`, extending
`protocol.ts` with nullable HTML, `rawText`, and diagnostics, and retaining the
trace diagnostic display. Keep its bounded diff implementation and shared
selectors/styles. The concrete trace serializer also overlaps the independent
state-enumeration branch; retain both its trace validation and the lossless JSON
boundary. These branches were validated independently, not merged here.
