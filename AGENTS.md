# Working on Veil

Read [CONTRIBUTORS.md](CONTRIBUTORS.md) for setup, commit conventions, commands,
and review expectations. Use `<type>: <lower-case imperative summary>` commit
titles, with one logical change per commit and problem/solution bodies for
fixes. Consult the checked-out sources when scripts or interfaces differ from
the guide.

- Inspect `git status` before editing or committing. Preserve user changes,
  stay within the assigned worktree/branch, and use the requested remote.
  Keep unrelated fixes and dependency upgrades separate.
- Use the pinned `lean-toolchain`. Run relevant focused checks, then
  `lake build VeilTest` for Lean implementation changes. For widget changes,
  run `npx tsc --noEmit` and `npm run build` from `widget/` after installing
  its locked dependencies. Use proportional checks for documentation-only
  edits. Report actual results and cache/manual/integration limits.
- Follow the import graph. DSL code is in `Veil/Frontend/DSL`, model checking
  and verification in `Veil/Core/Tools`, solver integration in `Veil/Backend`,
  and generic helpers in `Veil/Util`. Avoid adding frontend dependencies to
  generic utilities. Check public API and attribute-driven use before deleting
  apparently unused declarations.
- Preserve proof obligations and theorem meaning. Do not replace proofs with
  `sorry` or new axioms, or change SMT trust settings to make checks pass.
  Retain representation laws, locality proofs, and Lean/Std compatibility
  bridges until replacements satisfy the same contracts.
- Changes to `Veil/Frontend/DSL/Action/DoElab` must preserve statement-kind
  completeness, `ControlInfo`, hygienic binding, state refresh after effects,
  and `letEq` barriers. Exercise affected branches, macros, shadowing, effects
  in expressions, and ordinary Lean isolation using `VeilTest/ActionExecution`.
  Prefer execution/post-state regressions over elaboration-only smoke tests.
- For model-checker changes, check state identity, depth boundaries, terminal
  results, trace validity, cancellation, and relevant sequential/parallel
  behavior. Do not assume native relations and executable conversions coincide
  for every representation; establish the needed refinement or equality.
- For asynchronous verifier/widget changes, test ownership and stale results
  as well as normal completion. Coordinate Lean JSON/RPC producers in
  `Veil/Core/UI` with consumers in `widget/src`; use explicit types and keep
  result statuses distinct. Build success alone does not test editor actions.
- Update the DSL reference or examples when observable language behavior
  changes. Document unresolved design choices and validation limits instead
  of silently changing semantics to simplify an implementation.
