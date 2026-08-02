# Plan: Declaration invalidation and committed Agent semantics

- **Status:** done
- **RFC:** [#5](https://github.com/wzzc-dev/MoUI/issues/5) (accepted 2026-07-27)
- **ADR:** [0016](../../decisions/0015-core-protocols.md)
- **Goal:** Replace string-based view revisions and render-coupled Agent
  semantics with immutable four-channel declarations, runtime-owned committed
  semantics, stable semantic identity, generation-checked typed actions, and a
  semantic-only default MCP surface.
- **Compatibility:** This is an intentional breaking migration. Do not retain
  aliases, adapters, deprecated entrypoints, wire compatibility, or sentinel
  representations for any removed contract.

## Scope and non-goals

This plan covers `moui/core`, `moui/runtime`, all declaration producers in
`moui/views`, `moui_richtext`, and `moui_webview`, platform accessibility
transport in `moui/backend/host` and affected backends, `moui_agent`,
`moui_agent_mcp`, and `examples/agent_counter`.

The following are explicit non-goals for this change:

- `wait_for`, screenshots, authorization policy, and cross-window global IDs;
- the separate `core.Theme` / views-owned `ControlThemeSet` ownership change;
- making `moui_webview` a core dependency or making a platform backend/host
  mandatory;
- replacing application confirmation UI or TEA `update` with semantic IDs.

## Locked contracts

### Declarations and state

- `ViewNode::declaration() -> ViewDeclaration` replaces `revision()` and
  `paint_revision()` completely. The trait defaults to
  `ViewDeclaration::uncacheable()` so omission remains correct; exact or
  constant declarations are explicit cache proofs for performance-sensitive
  nodes.
- `ViewDeclaration` has independent `layout`, `paint`, `semantics`, and
  `platform` channels. Every channel is explicitly `Constant`,
  `Exact(DeclarationKey)`, or `Uncacheable`.
- The only implicit invalidation is `layout => paint + semantics + platform`.
  No other channel implies another.
- `DeclarationKey` is an opaque canonical `Bytes` value. Encoding uses a type
  tag and length framing, exact integers, IEEE-754 `Double` bits, UTF-8 bytes,
  and unambiguous `Option`, `Array`, and record framing. Equality compares the
  complete bytes; a hash may only reject unequal values early. JSON,
  interpolation, rounded values, and display formatting are forbidden.
- `View::from_node` samples identity, declaration, semantics metadata, typed
  action handlers, and static children exactly once. `View::map` preserves
  those snapshots and changes only the typed message adapter.
- A `ViewNode` contains immutable declaration data. Mutable handles such as
  `Binding` and `ScrollState` enter a typed adapter or runtime-owned node state
  slot, never a lazily sampled declaration. Application model state remains
  exclusively owned by TEA `update`; runtime slots hold only transient UI state
  such as hover, focus, caret, and scroll position.

### Semantics and actions

- Add opaque `SemanticId`, `SemanticsNodeId`, and `SemanticsGeneration` types.
  `SemanticId?` represents absence. Valid IDs contain 1--255 UTF-8 bytes, no
  whitespace or control code points, are not normalized, and compare exactly
  with case sensitivity. Dotted naming is only a convention.
- `SemanticsNodeId` is allocated monotonically per runtime session and is never
  reused. `SemanticsGeneration` wraps `UInt64`; wire representations use a
  decimal string. `ElementId` is runtime-internal and is absent from Agent,
  Web, mobile, and accessibility wire payloads.
- Split action capabilities from invocation payloads:
  `SemanticsActionKind` describes availability and `SemanticsAction` carries
  typed data, including `SetText(String)` and
  `Scroll(SemanticsScrollDirection)`.
- Composition is explicit: `Transparent`, `Boundary`, `MergeDescendants`, or
  `Hidden`. Remove automatic first-child role, label, value, state, and action
  inheritance. A semantic modifier is a logical-boundary overlay;
  `semantic_id` attaches only to the effective boundary and never propagates to
  an ancestor, sibling, or wrapper by inheritance.
- `ViewAdapter` stores one typed semantic-action handler per advertised kind.
  Runtime derives capability declarations from handlers. Remove modifiers that
  advertise behavior without an implementation. Runtime handles focus
  generically; every other action returns runtime-state invalidation and typed
  messages directly, without fabricated pointer or keyboard input.

### Runtime ownership and transactions

- Runtime owns an opaque, flat, immutable `SemanticsSnapshot` with generation,
  root, focused node, DFS-stable nodes, and duplicate-ID issues. Public
  accessors return copies or read-only projections; internal mutable arrays do
  not escape.
- Every element tracks own and descendant dirty state for build, layout,
  paint, semantics, and platform work, plus a semantics cache. The semantics
  pass depends only on the element tree, layout tree, and runtime state; it
  never requests paint.
- A semantics commit is atomic and ordered as: rebuild, layout, dirty semantics
  recomputation, ID/action index update, delta creation, then generation
  publication. Consumers cannot observe an intermediate state.
- Runtime maintains `SemanticId -> Unique | Ambiguous` and
  `SemanticsNodeId -> internal element/action route` indices. Duplicate IDs
  remain visible as snapshot issues, but all actions through that ID are
  rejected without side effects.
- Generation advances only when public snapshot content changes, including
  hierarchy, bounds, focus, value, state, actions, or IDs. Dirty bookkeeping,
  repeated reads, and paint-only changes do not advance it.
- Runtime retains the latest 64 commit deltas. `read_semantics(since?)` returns
  `Full`, `Delta`, or `Unchanged`; an expired/unknown cursor returns `Full` and
  multiple consumers do not share mutable cursor state.
- `perform_semantics_action` requires a target, a typed action, and
  `Exact(generation)` or explicit `Latest`. It first commits pending semantics,
  then validates runtime state, generation, ID uniqueness, enabled state,
  action capability, and handler acceptance in that order.
- Every rejected action has zero focus mutation, zero runtime-state mutation,
  zero message delivery, and zero redraw scheduling. Errors are the closed enum
  `RuntimeClosed`, `StaleGeneration`, `TargetNotFound`, `TargetAmbiguous`,
  `TargetDisabled`, `ActionUnavailable`, `HandlerRejected`, and
  `ReentrantDispatch`.
- On success, runtime commits local state and invalidation, enqueues typed
  messages FIFO, drains synchronous TEA work, and commits semantics again. The
  receipt reports before/after generations and pending work. Equal generations
  are valid and do not claim completion of asynchronous effects.

### Host, Agent, and MCP boundaries

- `moui/backend/host` transports platform semantics only. AccessKit, Web, and
  mobile payloads use `SemanticsNodeId`, generation, and deltas. Remove root
  recapture, JSON-string equality, bridge-local semantics revisions, duplicate
  validation, and platform action routing by `ElementId`.
- A semantics-only Web commit must reach the accessibility adapter without
  requiring a redraw.
- `AgentHost` contains only `read_semantics` and `perform_action`.
  `AgentDiagnosticsHost` is a separate, opt-in interface for raw coordinate
  events, global commands, runtime state, and paint summaries; neither
  interface inherits from the other.
- A runtime Agent host binds permanently to one runtime lifetime. Once that
  runtime is destroyed, operations return `HostClosed`; remove activate,
  deactivate, inactive-state behavior, and synthetic empty snapshots.
- The default MCP registry exposes exactly `read_semantics` and
  `perform_action`. A separate diagnostics profile is explicit and disabled by
  default.
- One typed tool registry generates descriptors, input/output schemas,
  decoders, and dispatch. Actions use a tagged object. Tool responses include
  `structuredContent`, a text fallback, and `isError`, with stable
  `{ "ok": true, "value": ... }` and
  `{ "ok": false, "error": ... }` envelopes. Only malformed JSON-RPC or
  `tools/call` envelopes return JSON-RPC errors; argument validation and
  business rejection are normal tool results with `isError: true`.

## Delivery checklist

### 1. Governance and executable record

- [x] Record maintainer acceptance on RFC #5.
- [x] Add ADR 0016 and explicitly supersede only ADR 0005's `ElementId` /
  host-local semantics revision choice and ADR 0015's string revision choice.
- [x] Create this active plan before implementation changes.
- [x] Keep this checklist current as work lands; move it to `docs/plans/done/`
  only after every required validation succeeds or an explicitly documented
  external limitation is accepted by the maintainer.

### 2. Core declaration and semantic contracts

- [x] Implement canonical `DeclarationKey` builders and exact equality tests
  for primitive, optional, array, and record values.
- [x] Add `ViewDeclaration` and the four channel policies; encode and test the
  complete invalidation matrix and the sole layout implication.
- [x] Replace both revision methods on `ViewNode`; remove every public/private
  string revision helper, empty-string sentinel, and
  `Theme::revision_fingerprint` dependency.
- [x] Freeze identity, declaration, semantics metadata, handlers, and children
  in `View::from_node`; make `View::map` preserve the frozen values.
- [x] Add and validate `SemanticId`, `SemanticsNodeId`, and
  `SemanticsGeneration`, including decimal-string wire conversion.
- [x] Add capability/payload action types, typed scroll direction, explicit
  composition, logical-boundary overlays, and typed action handlers.
- [x] Delete action-only modifiers, inherited-first-child composition, action
  plus optional-string APIs, and any public `ElementId` semantic target.
- [x] Prove shared binding aliases, equal-length text changes,
  `Some(a) -> Some(b)`, fine-grained floating/color differences, complete
  theme fields, callback `Uncacheable`, one-time child materialization, and
  `View::map` non-resampling.

### 3. Producer migration

- [x] Migrate all core modifiers to exact channel declarations.
- [x] Migrate every built-in `moui/views` node and control style. Geometry,
  paint, semantics, and platform data must enter only the affected channels.
- [x] Migrate `moui_richtext`, including source/content/style distinctions that
  equal-length or visually close revisions previously missed.
- [x] Migrate `moui_webview` as an addon producer; preserve its platform-view
  ownership without adding a runtime or Agent dependency on it.
- [x] Require exact declaration keys from callback APIs when possible;
  otherwise mark the affected channel `Uncacheable` explicitly.
- [x] Remove all string concatenation, rounded-number, JSON, and theme
  fingerprint revision producers after the final migration.

### 4. Runtime invalidation and committed semantics

- [x] Replace clean/paint/layout-only reconciliation with independent own and
  descendant build/layout/paint/semantics/platform dirty propagation.
- [x] Add per-element semantics caches and a semantics pass independent of
  render-tree construction and paint.
- [x] Implement stable session-local node allocation and preserve a node ID for
  one logical element lifetime without reuse after removal.
- [x] Implement immutable flat snapshots, duplicate-ID issues, DFS ordering,
  focus, bounds, and read-only/copying accessors.
- [x] Implement the unique/ambiguous semantic-ID index and node route/action
  index, updating both inside the atomic commit.
- [x] Implement content-sensitive generation publication and the bounded
  64-entry delta journal, including full fallback after cursor expiry.
- [x] Implement independent `Full`, `Delta`, and `Unchanged` reads for multiple
  consumers.
- [x] Implement the generation-preconditioned direct action transaction,
  receipt, exact error enum, reentrancy guard, FIFO typed-message drain, and
  post-action semantics commit.
- [x] Delete full-tree action scans, semantics-on-render behavior, center-point
  pointer synthesis, and all semantic action pointer/keyboard fabrication.
- [x] Test every action kind: Activate, SetText, Scroll, Focus, Select,
  Expand, Collapse, and Dismiss.
- [x] Test stale, missing, ambiguous, disabled, unavailable, rejected, closed,
  and reentrant failures for strictly zero side effects and no observed fake
  input.

### 5. Platform host and accessibility migration

- [x] Make host accessibility payloads carry runtime-owned node IDs,
  generations, and deltas only.
- [x] Migrate AccessKit identity mapping and action routing to
  `SemanticsNodeId`.
- [x] Migrate Web accessibility to deltas and schedule semantics-only sync
  independently from redraw; delete JSON-string snapshot comparison.
- [x] Migrate mobile embedded sessions to runtime generations and node IDs;
  reject stale session/generation and removed-node actions.
- [x] Delete host-local `semantics_revision`, old root capture, second-stage
  capability/enabled validation, and `ElementId` wire fields.
- [x] Prove no host maintains a second revision authority and no host can
  publish an uncommitted runtime snapshot.

### 6. Agent host, MCP, and Agent Counter

- [x] Reduce `AgentHost` to semantic reads/actions and introduce the separate
  opt-in `AgentDiagnosticsHost`.
- [x] Bind `RuntimeAgentHost` to one runtime lifetime and map closed runtime
  state consistently to `HostClosed`; remove activation state and empty
  fallback snapshots.
- [x] Build the typed MCP registry and generate tool descriptors, schemas,
  decoding, and dispatch from that single source.
- [x] Expose exactly two default tools and gate every diagnostic tool behind an
  explicit diagnostics configuration.
- [x] Implement tagged action input, generation preconditions, typed
  structured success/error output, text fallback, `isError`, and stable wire
  error codes.
- [x] Set `counter.increment`, `counter.decrement`, and `counter.reset` on the
  Agent Counter buttons.
- [x] Rewrite the E2E flow to read generation, perform actions using the
  receipt's `after` generation, and verify model, semantics, and draw command
  changes from `Count: 0` to `Count: 1`.
- [x] Prove a semantic ID survives rebuild, a stale generation is rejected,
  and a duplicate ID dispatches no message.
- [x] Move coordinate input coverage to the explicit diagnostics suite; the
  product Agent/MCP E2E must contain no coordinate target.

### 7. Documentation, generated API, and budgets

- [x] Run `moon info` and commit all intended `pkg.generated.mbti` changes.
- [x] Update API surface classifications and budgets by the exact measured
  delta; ratchet reduced budgets downward.
- [x] Update `docs/INDEX.md`, architecture, TEA, semantics/Agent runtime,
  platform host, view catalog, and testing guidance.
- [x] Document the semantic-only default MCP surface and separately enabled
  diagnostics profile.
- [x] Keep the separate Theme RFC boundary and optional `moui_webview` /
  backend ownership explicit in all affected guidance.

### 8. Acceptance and validation

- [x] Declaration tests cover aliasing, equal-size data, option payloads,
  precise numeric/color/theme values, callback caching policy, every channel
  transition, one-time children, and mapped-view snapshots.
- [x] Semantics tests cover ID validation, all four composition modes,
  overlays, no first-child inheritance, duplicate issues, node lifetimes,
  generation/delta reset, multiple cursors, and semantics-only zero
  layout/paint.
- [x] Host tests cover Web no-redraw updates, AccessKit mapping, mobile stale
  session/generation, removed nodes, and absence of secondary revisions.
- [x] Agent/MCP tests cover the two-tool default surface, explicit diagnostics,
  registry/schema/router consistency, structured success/error, invalid IDs,
  actions, payloads, generations, host closure, and stable codes.
- [x] Performance tests prove ID actions do not traverse the semantics tree, a
  leaf change does not recompute the full tree, reads do not increment paint,
  and a one-node change yields a delta rather than a full snapshot.
- [x] Run focused native tests for `moui/core`, `moui/runtime`, `moui/views`,
  `moui_richtext`, `moui_webview`, `moui/backend/host`, affected platform
  backends, `moui_agent`, `moui_agent_mcp`, and `examples/agent_counter`.
- [x] Run corresponding wasm-gc checks/tests for every supported affected
  package and example.
- [x] Run `moon fmt` and `moon info`; inspect generated interface diffs.
- [x] Run `node scripts/validate-maintenance-baseline.mjs`.
- [x] Run `node scripts/validate-api-surface.mjs`.
- [x] Run `node scripts/validate-guidance-consistency.mjs`; record the accepted
  local-window workspace exception below.
- [x] Run `sh scripts/check.sh --profile theme`.
- [x] Run `sh scripts/check.sh --profile daily`; run the remainder from the
  same catalog after its expected local-window guidance stop.
- [x] Confirm `git status` contains no generated artifacts or unrelated files,
  then move this plan to `docs/plans/done/` and record final evidence.

## Validation evidence

Completed on 2026-07-27:

- `moon fmt`, `moon info`, workspace `moon check --target native`, and
  workspace `moon check --target wasm-gc` passed with the local window modules
  enabled only for dependency resolution.
- Focused native and wasm-gc tests passed for core, runtime, views, rich text,
  host, Web, Agent, MCP, Agent Counter, and every supported `moui_webview`
  subpackage. Affected macOS, Windows, Linux, Android, iOS, HarmonyOS, and
  embedded-session packages also passed their focused native checks/tests.
- The maintenance, API-surface, harness, source-file-policy, generated-facts,
  and generated-interface validators passed. The API report, repository facts,
  generated interfaces, and website docs are current for the local workspace.
- `sh scripts/check.sh --profile theme` passed.
- The exact daily wrapper ran and stopped only when guidance rejected the two
  local `window` members. Every other daily catalog step passed with those two
  published-mode checks skipped; the Web handoff, semantics DOM, renderer,
  smoke, validator-self-test, and package-test tail all passed.

Accepted local-development limitation:

- The maintainer explicitly requested that this work continue against local
  `./window/modules/window` and `./window/modules/windowing`, without
  `moon update` or a switch to the published package. Consequently,
  `validate-guidance-consistency.mjs` and `validate-window-dependency.mjs`
  intentionally reject the final dev-mode `moon.work`. This accepted exception
  is limited to workspace dependency policy; all implementation and runtime
  validation used the requested local modules.

## Acceptance invariants

Completion requires all of the following to remain true:

- The declaration-to-reconcile-to-layout/render/semantics/platform pipeline
  has one runtime invalidation authority and no string revision fallback.
- Semantics is committed independently of paint and observed atomically.
- Generation is content-based; deltas are bounded, cursor-independent, and
  recoverable through a full snapshot.
- Every semantic action is typed, generation-checked, index-routed, and either
  atomically accepted or rejected with no side effects.
- Product Agent/MCP APIs expose stable semantics, not coordinates, runtime
  internals, renderer diagnostics, or platform-local identity.
- TEA `update` remains the sole owner of application model mutation; runtime
  slots contain only node-scoped transient UI state.
