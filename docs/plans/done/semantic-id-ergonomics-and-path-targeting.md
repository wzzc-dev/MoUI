# Plan: Semantic id ergonomics and hierarchy path targeting

- **Status**: done
- **Goal**: Remove the boilerplate that separates a declared semantic identity
  from its address string, and let an agent address a committed node by
  walking the emitted semantics hierarchy instead of only by declared
  `SemanticId` or runtime `SemanticsNodeId`.
- **Non-goals**: inferring a semantic address from a message constructor,
  auto-deriving addresses from tree position, replacing `SemanticId` as the
  durable business handle, adding index-only paths, changing the committed
  snapshot shape, or authoring applications as JSON documents.

## Scope

- `moui/core`: `SemanticId` constructor pair, `View::semantic_id` signature,
  `SemanticsTarget` / `SemanticsPathSegment` value types.
- `moui/runtime`: hierarchy path resolution against the committed tree.
- `moui_agent_mcp`: wire schema, decoder, and error serialization for the path
  target.
- `examples/showcase`, `examples/agent_counter`, `moui/core` tests: call-site
  migration.
- `docs/agent-semantics.md` (+ zh-Hans mirror), `docs/api-surface.md`.

## Locked contracts

### Semantic identity

- `SemanticId::parse` keeps returning `Option` for values that originate outside
  the program.
- A new panicking constructor covers values declared as literals in UI code, so
  an invalid literal fails at the first view construction instead of being
  silently dropped by the caller. `SemanticIdModifier` keeps holding an already
  validated `SemanticId`.
- `View::semantic_id` takes the string form directly; MoonBit has no argument
  overloading, so there is exactly one signature and no alias.
- Every declared semantic identity keeps its exact, non-normalized value. A
  `Msg` variant rename must not rename an agent address.

### Hierarchy targeting

- `SemanticsTarget` gains `ByPath(Array[SemanticsPathSegment])`. `BySemanticId`
  and `ByNodeId` are unchanged.
- A segment selects one node among the matching children by `index`. Role,
  label, value, and `semantic_id` are optional filters. A segment with no
  filter is rejected by the wire decoder, so an agent cannot address "whatever
  happens to be there".
- Resolution walks the committed semantics tree from its root. A missing root,
  an unmatched step, or an out-of-range index resolves to `target_not_found`;
  no step fails silently.
- Path resolution shares the disabled / capability / handler chain of the
  other targets and honors the same generation precondition.
- The emitted snapshot is unchanged. Path addressing is a way to *find* a node
  inside the tree the agent already receives, not a different projection.

## Delivery sequence

1. Add `SemanticId::new` and switch `View::semantic_id` to the string form.
2. Regenerate `moui/core/pkg.generated.mbti`; migrate the 16 call sites and
   delete the local showcase helper.
3. Add `SemanticsPathSegment` / `ByPath` to core with a `has_filters` predicate.
4. Resolve `ByPath` in runtime against the committed tree.
5. Add the path target to the MCP wire codec and error serialization.
6. Cover both surfaces with focused tests.
7. Update guidance, run the pre-push static trio, and refresh `moon info`.

## Acceptance

- [x] `examples/agent_counter` declares `.semantic_id("counter.increment")`.
- [x] `SemanticId::parse` still rejects invalid values through `Option`.
- [x] A segment without any filter is rejected as `invalid_arguments`.
- [x] A labeled path resolves the same node the matching `SemanticId` resolves.
- [x] An unmatched or out-of-range path returns `target_not_found`.
- [x] `BySemanticId` and `ByNodeId` behavior and error codes are unchanged.
- [x] `moon test` passes for `moui/core`, `moui/runtime`, `moui_agent_mcp`,
      `examples/agent_counter`, `examples/showcase`.
- [x] `node scripts/validate-api-surface.mjs` and the guidance validators pass.
