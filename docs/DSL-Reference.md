# Veil DSL Reference

A Veil module specifies a **state transition system**, describing:

- the type of the background theory the system assumes
- the type of the state the system operates on

Every Veil module follows a canonical structure with the following components:

1. Module declaration
2. Type declarations
3. Type class instance declarations
4. State and theory components (individuals, relations, functions)
    - the state consists of the mutable components
    - the background theory consists of the `immutable` components
5. State generation via `#gen_state`
6. Ghost relations (to aid specification)
7. Initial state
8. Procedures, actions, and transitions
    - procedures are internal helper routines that can be called from actions
    - actions are externally visible transitions that the environment can invoke
    - transitions are two-state relations; an alternative, relational way of
      specifying what actions specify imperatively
9. Properties (safety, invariants, assumptions)
10. Specification generation & verification commands

### 1. Module Declaration

A Veil module begins with `veil module <Name>` and ends with `end <Name>`:

```lean
module

public import Veil

veil module Ring
-- module contents go here
end Ring
```

The `module` header enables Lean’s module system and must precede the imports.
The `public import Veil` statement brings in all Veil DSL syntax and utilities. It must be public
because a model exports generated declarations whose types and bodies refer to Veil definitions.
Verification tools are imported for elaboration only; compiled model checkers link the runtime dependencies.
`veil module` sets the visibility and transparency of its declarations automatically;
users do not need a `public section` or `@[expose]` annotation.

### 2. Type Declarations

Veil supports several kinds of type declarations:

#### Uninterpreted Types

Abstract types with no internal structure:

```lean
type node
type round
type value
```

When _verifying_ a module, Veil universally quantifies over its type
parameters, i.e. it checks that the system is correct for **all** types that
satisfy the stated assumptions. When _model checking_, you provide a concrete
instantiation for each of them (e.g. `node := Fin 4`).

#### Parameters

`type` is a special case of the more general `param` command, which declares a
parameter of arbitrary type (`type node` is equivalent to `param node : Type`
plus auto-generated `DecidableEq` and `Inhabited` instances):

```lean
param n : Nat
param m : Fin n   -- dependent parameters are allowed
```

#### Enumerated Types

Types with a finite set of constructors:

```lean
enum color = {red, blue, green}
enum pc_state = {idle, waiting, critical}
```

#### Lean Structures

For complex data types, use the `@[veil_decl]` attribute:

```lean
@[veil_decl] structure Message (node : Type) where
  payload : node
  src : node
  dst : node
```

This marks the structure for use within Veil's verification framework.

### 3. Type Class Instantiation

Veil provides standard type classes for common structures.
Use `instantiate` to introduce them:

```lean
instantiate tot : TotalOrder node
instantiate btwn : Between node
open Between TotalOrder
```

The `open` command makes the type class fields available without qualification.

See `Std.lean` for the complete list of type classes.

### 4. State and Theory Components

Finite-set carriers can be declared with `set_type`:

```lean
type node
set_type Nodes : node
individual seen : Nodes
```

This introduces an abstract type `Nodes` and the instance `Nodes_set : TSet node Nodes`.
Specifications remain independent of the concrete set representation. Model checking
defaults `Nodes` to `Std.ExtTreeSet` of the instantiated node type, so
`#model_check interpreted { node := Fin 3 } {}` suffices. Override the carrier with
`{ node := Fin 3, Nodes := OrdList (Fin 3) }` when desired. Nested declarations
such as `set_type Families : Nodes` receive corresponding nested defaults.

Set values support `∅`, `{x}`, `{x, y, z}`, `insert x S`, `S ∪ T`, `S ∩ T`,
`S \ T`, and `S ⊆ T`. Membership remains `x ∈ S`. `TSet.Nonempty S` and
`TSet.Disjoint S T` are decidable by inspecting the sets, even when their element
type is infinite. These operations also work with manually declared `TSet` carriers.

`set_type` additionally supplies `Nodes_laws : LawfulTSet node Nodes`. This provides
extensional equality (`TSet.ext`), membership laws for filters/intersections/list
construction, duplicate-free enumeration, and the relationship between cardinality
and enumeration length. The tree-set, sorted-list, and sorted-array carriers all
satisfy these laws; custom carriers can implement `LawfulTSet` alongside `TSet`.
The laws support ordinary Lean proofs with `simp` and `TSet.ext`; higher-order
collection operations may require a Lean proof rather than automatic SMT discharge.

Use `card S` for set cardinality, `TSet.countWhere S (fun x => P x)` to count
matching members, and `TSet.countDistinct messages (fun m => m.sender)` to count
distinct images without introducing another set carrier. These operate on the
collection itself. `countFinite node P` counts a predicate over an explicitly
enumerable whole type and removes any duplicates in its enumeration first.

Exact comprehensions use `{x ∈ S | P x}` to filter an existing set and
`({x : node | P x} : Nodes)` to construct a set from an explicitly enumerable
type. The bounded form preserves the source carrier and does not require an
enumeration of the element type. Both forms include every matching member and
exclude every nonmatching one. Whole-type comprehensions require
`Enumeration node`; ordinary `type node` declarations do not assume finiteness.

Set images use `{f x | x ∈ S}`; Cartesian products use `S ×ˢ T`. Record
families are images too, for example
`({{ sender := me, receiver := n } | n ∈ nodes} : Messages)`. These operations
traverse their inputs and remove duplicates in the result. An expected result
carrier takes precedence. Otherwise, images preserve the source carrier when the
element type is unchanged, use a unique matching local `TSet` carrier when one
exists, and fall back to `Std.ExtTreeSet` for concretely ordered output types.
Ambiguous carriers require an annotation. Products use the same result-carrier
inference for their pair type.

Bounded quantifiers `∀ x ∈ S, P x` and `∃ x ∈ S, P x` decide their predicates
by traversing `S`, without requiring `Enumeration` of its element type. They
support empty sets, nested bounds, and ordinary Lean lists. Their logical meaning
is the usual membership implication/conjunction, so existing Lean proofs apply.
A bound depending on its own quantified variable retains Lean's ordinary semantics
and is not a single finite collection to traverse.

A collection bound is preserved when a nondeterministic choice adds predicates:
`let m :| m ∈ messages ∧ P m` and `if m :| m ∈ messages ∧ P m then … else …`
enumerate members of `messages`, then filter them. This also works with
`TSet.contains m messages` and nested conjunctions. Put the bounded predicate
first. No enumeration of the whole message type is required, and every qualifying
member remains a possible choice. The `if` form takes its else branch if none qualify.

State components define the **signature** of your transition system.

#### Individuals

Single values of a given type:

```lean
individual leader : List node           -- mutable (default)
immutable individual maxRound : round   -- immutable/constant
```

#### Relations

Predicates over types:

```lean
relation leader : node -> Bool
relation pending : node -> node -> Bool
relation sent (n : node) : Bool
```

Declare relations as `Bool`-valued (rather than `Prop`-valued): this keeps the
state executable, which is what allows the explicit-state model checker to run
your specification.

#### Functions

Total functions from domain to codomain:

```lean
function currentRound : node -> Nat
immutable function nextNode : node -> node
```

#### Partial Functions

A partial function has at most one output for each input. An input can have no
output:

```lean
partial function owner : vertex -> node
partial function entry : node -> round -> value
immutable partial function parent (child : node) : node
```

These declarations create Boolean relations: `owner v n` tests whether vertex
`v` maps to node `n`. Use a guarded choice such as `if n :| owner v n then ...`
to read an output that might be absent. There is no totality axiom or implicit
default output.

Point assignments maintain the functional interpretation:

```lean
owner v n := true      -- replace any previous output of v with n
owner v n := false     -- remove this edge, preserving a different output
owner v N := false     -- remove every output of v
owner V n := true      -- map every vertex to n
owner V N := false     -- clear the entire partial function
```

A Boolean expression on the right follows the same rule: true replaces the
output; false removes only the specified edge. Arrow assignments and point
havoc use this rule too. Updates with a universal output index, whole-field
assignments, and whole-field havoc retain ordinary relation semantics.

Veil generates `<name>_coherence`, requiring that two outputs for the same input
are equal. For mutable partial functions this is an **invariant to verify**:
initialization, bulk updates, havoc, and relational transitions must establish
or preserve it. For immutable partial functions it is a background assumption,
also checked against the theory supplied to the model checker. Partial functions
use the configured **relation** field representation.

#### Mutability

- **Mutable** (default): Can be modified by actions
- **Immutable**: Part of the background theory, cannot change

```lean
immutable function nextNode : node -> node  -- ring topology is fixed
mutable relation pending : node -> node -> Bool  -- messages can change
```

A constant function or relation can also be a `param` or a type-class field
introduced by `instantiate`. These are parameters of the module rather than
run-time theory values, so the compiled model checker calls them directly and
*might* runs faster; see
[ModelChecker-Guide.md](ModelChecker-Guide.md#constant-functions-and-relations).

### 5. State Generation

After declaring state components, generate the state type:

```lean
#gen_state
```

This assembles all declared state components into a single state structure
that Veil uses for verification.

### 6. Ghost Relations

Ghost relations exist only for specification purposes.
They are defined in terms of other state components:

```lean
ghost relation initial_value (n : address) (r : round) (v : value) :=
  ∀ dst, initial_msg n dst r v

theory ghost relation isMaxRound (r : round) :=
  ∀ r', le r' r
```

- `ghost relation`: Can reference mutable state
- `theory ghost relation`: Only references immutable/background theory

### 7. Initial State

The `after_init` block defines the initial state using an imperative program.
Every Veil model starts in a _default_ state (each field set to its default
value), which the `after_init` program then atomically transitions into the
initial state. The program may be non-deterministic (e.g. use `:= *`
assignments), in which case the model has several initial states:

```lean
after_init {
  leader N := false       -- no initial leader
  pending M N := false    -- no pending messages
}
```

For relation and function state, uppercase variables (like `N`, `M`) are implicitly
universally quantified. The quantified variables are bound on the right-hand
side of the assignment too, so e.g. `W N V := (V == initialValue N)` is
well-formed.

### 8. Actions, Procedures and Transitions

#### Actions

Externally visible transitions that the environment can invoke. Actions are
**atomic**: they execute either fully or not at all (if an assertion fails,
all state changes are discarded).

```lean
action send (n next : node) {
  require ∀ Z, n ≠ next ∧ ((Z ≠ n ∧ Z ≠ next) → btw n next Z)
  pending n next := true
}

action recv (sender n next : node) {
  require pending sender n
  pending sender n := false
  if sender = n then
    leader n := true
  else
    if le n sender then
      pending sender next := true
}
```

#### Procedures

Internal helper routines that can be called from actions and other procedures,
but cannot be invoked by the environment directly (Veil's `procedure`
corresponds to Ivy's `action`, whereas Veil's `action` corresponds to Ivy's
`export action`):

```lean
procedure sendToNext (payload src : node) {
  let msg := Message.mk payload src (nextNode src)
  if msg ∉ messages then
    messages := msg :: messages
}

action send (n : node) {
  sendToNext n n
}
```

Actions can themselves be called from other actions and procedures.

#### Two-State Transitions

Besides imperative `action`s, transitions can be defined directly as two-state
relations via the `transition` keyword, with the post-state accessed through
primed variables. Any field not mentioned in primed form is implicitly framed
(assumed unchanged):

```lean
transition byz {
  ∀ (src dst : node) (r : round) (v : value),
    (¬ is_byz src ∧ (initial_msg src dst r v ↔ initial_msg' src dst r v)) ∨
    (is_byz src ∧ (initial_msg src dst r v → initial_msg' src dst r v))
}
```

The imperative style is generally preferable — it tends to be more readable and
has significantly better execution performance for model checking — but the
relational style is often more convenient for environment transitions (e.g. a
Byzantine adversary), and the two styles can coexist in the same module. Veil
generates the two-state relation equivalent for every imperative action.

#### Imperative DSL Keywords

| Keyword | Description |
|---------|-------------|
| `require P` | Precondition of the transition (see below) |
| `assume P` | Assumption: executions violating `P` are discarded |
| `assert P` | Must hold (verification condition); aborts the action at runtime if false |
| `let x := e` | Local binding |
| `let x :\| P` | Non-deterministic choice satisfying `P` (Hilbert choice) |
| `let x <- pick T` | Pick arbitrary value of type `T` |
| `x := e` | State update |
| `x ← act` | Call `act` and store its result in `x` (see below) |
| `x := *` | Non-deterministic (unconstrained) state update |
| `if P then ... else ...` | Conditional |
| `return e` | Return value from procedure |

`require P` is the recommended way to express preconditions. When the
enclosing action is invoked by the environment, it behaves as an assumption
(the transition is not enabled unless `P` holds); when the enclosing
action/procedure is called from another procedure, it behaves as an assertion
that the caller must satisfy.

For constrained non-deterministic choice, prefer `let x :| P` over
`pick` + `assume`: it has more efficient execution semantics, as it filters
out invalid values before continuing execution rather than discarding
executions after the fact.

`lhs ← act`, where `lhs` is a state component, a `let mut` local, or an
indexed form of either (`r a ← act`), means `lhs := (← act)`: the call `act` and
its arguments are evaluated on the state *before* the call; then the target's
index terms (e.g., `a` in `r a ← act`) are evaluated and the result is stored on the state *after* the
call. For example, if `bump` increments `k` and returns a value, `r k ← bump`
stores that value at the incremented index.

### 9. Properties

#### Safety Properties

The main correctness properties to verify. As in `after_init`, capitalised
variables are implicitly universally quantified:

```lean
safety [single_leader] leader N ∧ leader M → N = M
```

#### Invariants

Properties that hold in all reachable states (used in inductive proofs;
`safety` is a synonym for `invariant`, used to mark the properties you
actually care about):

```lean
invariant [leader_greatest] leader L → le N L
invariant pending S D ∧ btw S N D → le N S
invariant pending L L → le N L
```

#### Assumptions

Axioms about the background theory. Assumptions can refer to `immutable`
state components, `param`s, and type-class fields, but not to `mutable`
components (to assume facts about those, use `trusted invariant`):

```lean
assumption [ring_topology] ∀ n, nextNode (nextNode n) ≠ n
```

Whenever possible, prefer stating assumptions via `instantiate` with a
typeclass from Veil's standard library (e.g. `instantiate tot : TotalOrder
node`): this bundles connected assumptions together, and concrete instances
for execution/model checking are then found automatically by Lean's typeclass
inference.

### 10. Verification Commands

To enable verification, we need to finalize the module specification:

```lean
#gen_spec
```

Then, we can use a number of verification commands to check the properties of
the module.

To check extraction without exploring the state space, use:

```lean
#gen_executable
```

This generates executable actions and the enumerable transition system used by
`#model_check` and `#simulate`, without running either command. It requires
`#gen_spec` first and can be repeated safely; later model checks reuse the
generated definitions.

#### Checking Invariants

Tries to prove, using SMT solvers, that the conjunction of all `safety` and
`invariant` clauses is an _inductive_ invariant, i.e. holds in all initial
states and is preserved by every action:

```lean
#check_invariants
```

Results are streamed into an InfoView widget. For clauses that are not
preserved, clicking on the clause reveals a _counterexample to induction_
(CTI): a pre-state satisfying the invariant, a transition, and a post-state
violating the clause. Strengthening the invariant with clauses that rule out
such (unreachable) pre-states, guided by CTIs, is the recommended way to
discover an inductive invariant.

If the solver cannot discharge a verification condition, Command + Click on
its name in the widget (or the "Insert" button) inserts the corresponding
theorem statement into the editor, where you can prove it interactively using
Lean tactics. The inserted theorem is tagged `@[veil]`, which makes
`#check_invariants` use it to discharge that verification condition.

To check a single action, use `#check_action <name>`.

#### Explicit-State Model Checking

Exhaustive enumeration of the reachable states of a finite instance, checking
every `safety` and `invariant` clause in each state. The first argument
instantiates the module's parameters (`type`s and `param`s); the second gives
concrete values for the theory (`immutable`) components and can be omitted
when there are none:

```lean
#model_check { node := Fin 4 }
```

```lean
#model_check { node := Fin 4 } { nextNode := fun n => n + 1 }
```

Typeclass assumptions introduced via `instantiate` are resolved using Lean's
typeclass inference for the concrete instantiation (the model checker does
_not_ enumerate all possible instances or theories, so treat it as a testing
tool). Progress and action-coverage statistics are displayed live in an
InfoView widget; if a violation is found, Veil shows a concrete counterexample
trace. See the [Model Checker Guide](ModelChecker-Guide.md) for execution modes,
options, deadlocks, state constraints, and performance tuning.

##### Random Simulation

If you do not want exhaustive testing, you can use the `#simulate` command to
perform random walks on the state graph. Provide the type instantiation and
theory, optionally followed by the settings:

```lean
#simulate { node := Fin 3 } {} (numTraces := 2000) (maxSteps := 500) (seed := 42)
```

#### Symbolic Bounded Model Checking

Explore system behaviors with trace queries, discharged via SMT. Unlike
`#model_check`, these queries check **all** instantiations of the module's
parameters at once, but only up to a bounded number of steps:

##### Satisfiable Traces

Find an execution reaching a state:

```lean
sat trace {
  any 3 actions
  assert (∃ l, leader l)
}
```

You can also specify concrete actions to take, and optionally name the trace:

```lean
sat trace [some_progress] {
  send
  send
  recv
}
```

A query worth including in any specification is `sat trace { }` (the empty
trace): it checks that the module's assumptions are satisfiable, guarding
against vacuously-verified specifications.

##### Unsatisfiable Traces

Prove no execution of the given (bounded) shape reaches a state:

```lean
unsat trace {
  any 5 actions
  assert (∃ n₁ n₂, n₁ ≠ n₂ ∧ leader n₁ ∧ leader n₂)
}
```

Note that checking time grows exponentially with the trace length.
