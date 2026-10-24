# Plan: ViewNode trait decomposition

- **Status**: debt
- **Verdict (2026-10-24)**: the blocker was mis-attributed to blanket impls. It
  is three separate MoonBit limits, and the ergonomic gain this plan expected is
  already delivered by default methods. Do not start unless all three lift.
- **Goal**: Split the 15-method `ViewNode` trait into finer-grained traits
  (`LayoutNode`, `PaintNode`, `SemanticsViewNode`, `FocusNode`, …) so new
  controls implement only the surface they actually participate in, and
  capability-shaped dispatch replaces "every node answers every question".
- **Non-goals**: any runtime behaviour change; any change to
  `View::from_node`/`ViewAdapter` snapshot ownership; adding new capability
  channels beyond the existing four declaration channels.

## Context

`moui/core/view_node.mbt` carried a signpost comment ("Future: when MoonBit
supports blanket trait impls, decompose ViewNode into finer-grained traits") and
`moui/core/any_modifier.mbt` a matching note. Both attributed the limitation to
blanket impls alone. Re-measured against the current toolchain and the current
tree, that attribution is wrong in two directions, and the "14 methods" count
was stale (the trait is 15 methods: `identity` and `layout` are compiler-
required, 13 carry inert defaults).

Override counts across the 63 `ViewNode` implementations in `moui/` plus
`examples/`: `identity` 63, `layout` 63, `declaration` 57, `semantics` 40,
`paint` 28, `child_constraints` 11, `focusable` 10, every remaining method ≤4.
So the fat part of the trait is already free — nodes override what they
participate in — and what they must write anyway is the mandatory trio. Only 6
types rely on the `declaration()` default, and 3 of those are test fixtures
(the rest are `ThemedControl[Style]` and two `examples/terminal/addon` nodes).

`declaration()` is not an optional capability: its bodies hand-build
`DeclarationKey` records over the node's fields (`view_record_key`,
`view_exact_channel`), which is what the reconciler uses to decide which channel
is dirty. A decomposition whose selling point is "a node need not answer this
trait" would let nodes opt out of the caching contract — a correctness
regression, not a simplification. Invariant P17 (`docs/invariants.md`,
`docs/decisions/0034-viewnode-declaration-coverage-gate.md`) already polices the
real failure mode: a stored field missing from the declaration keys.

## Why deferred

Three MoonBit limits, each verified with `moon check --target native` on moon
0.1.20261016, kill one leg of the plan:

- **No aggregate derivation.** `impl[T : Bound] Agg for T` is rejected with
  `Error: [4053] Invalid type for "self": must be a type constructor`. This is a
  typing rule, not a coherence check, so relaxing orphan rules would not unlock
  it. Impl targets may be *generic type constructors* — `impl[T : B] C for
  Container[T]`, and even MoUI-owned traits for stdlib constructors (`Array[T]`,
  `Option[T]`) — which is exactly the form `ModifierViewNode` already uses.
- **Single-parent inheritance only, and it does not pay.** `trait Agg :
  LayoutNode` compiles and `impl Agg for X` need not re-define the parent's
  methods, but `X` must still carry its own `impl LayoutNode for X` (else
  `Error: [4018]`), and multiple parents (`trait Agg : A B`, `trait Agg : A, B`)
  are parse errors. A four-way split therefore means four impl blocks per node
  type across 63 types, plus a parent impl per level — strictly more boilerplate
  than one impl with defaults.
- **No capability probing at the erasure boundary.** `ViewAdapter` stores
  `node : &ViewNode`, so dispatch is a trait object. Trait objects upcast
  (`obj as &LayoutNode` through a parent chain) but cannot be narrowed
  (`&ViewNode as &PaintNode` → `Error: [4018]`). "Ask the node what it can do"
  is impossible on the erased object, which is what the plan's
  capability-shaped dispatch goal requires. Capabilities must stay encoded as
  data — the design already does this with the four `ViewDeclaration` channels
  and the `Option`-returning hooks (`place_overlays`, `text_input_state`).

Practical harm stays bounded: the P17 declaration-coverage gate catches the
realistic fat-trait failure (a node overriding one channel while forgetting a
dependent field), and unused defaults are cheap no-ops. `AnyModifier`'s vtable
is likewise not waiting on blanket impls — see the corrected note in
`moui/core/any_modifier.mbt`; adding a channel touches five core sites and none
of the 47 `to_any_modifier` conversions, which all spread `{ ..noop_modifier() }`.

## Re-evaluate when

- MoonBit supports an impl target that is a **bare type variable** (deriving an
  aggregate from bounded sub-traits) — a different feature from the generic
  constructor impls it already has.
- MoonBit supports **multiple parent traits**, so an aggregate can fan in.
- MoonBit supports **narrowing or testing a trait object** for an unrelated
  capability trait; without it, splitting buys nothing at the call sites that
  motivated the split.
- A new control family makes implementing the defaulted channels an actual tax
  at authoring time (current evidence: 13 defaults, 6 types relying on the
  `declaration` default, 3 of them fixtures).
- Declaration channels grow past four and channel-local evolution is genuinely
  blocked — note that `generate_view_declarations` (Option B of ADR 0034) is the
  cheaper MoonBit-native answer to the same pain, since MoonBit has no macros
  or derive and generation stays a drift-gated committed artifact.

## Acceptance
- [ ] Decomposition plan merged as an RFC/ADR with a compile-compatibility
  story for existing nodes.
- [ ] All 63 `ViewNode` implementations migrate without behaviour drift
  (layout/paint/semantics golden tests green).

## Decision log
| Date | Decision |
|------|----------|
| 2026-09-04 | Recorded as debt from the implementation audit (view-framework-remediation); blocked on MoonBit blanket impls, P17 gate accepted as interim mitigation. |
| 2026-10-24 | Re-scoped after compiling the language limits one by one: blanket impls are only one of three blockers, the fan-in split is unreachable while trait objects cannot be narrowed, and the chained alternative costs more impls than it saves. Fat trait stays; signpost comments in `moui/core/view_node.mbt` and `moui/core/any_modifier.mbt` corrected to record all three limits. |

## Progress
| Date | Note |
|------|------|
| 2026-09-04 | Debt note created; signpost comment already in `moui/core/view_node.mbt`. |
| 2026-10-24 | Measured override counts (63 impls: identity 63 / layout 63 / declaration 57 / semantics 40 / paint 28). Corrected the method count from 14 to 15 and the blocker attribution. P17 gate remains the mitigation; next lever is ADR 0034 Option B (`generate_view_declarations`) after its waiver baseline reaches zero. |
