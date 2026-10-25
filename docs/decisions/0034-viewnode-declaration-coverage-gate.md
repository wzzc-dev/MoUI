# 0034: ViewNode declaration-key coverage gate

- **Date**: 2026-09-04
- **Status**: Accepted
- **Deciders**: Agent-assisted (ZCode, gpt-5.5)
- **Related**: [Plan: view-framework-remediation](../plans/done/view-framework-remediation.md),
  [ADR 0015](0015-core-protocols.md), [ADR 0017](0017-theme-and-host-contract.md)

## Context

`ViewNode::declaration()` is the per-channel (layout/paint/semantics/platform)
cacheability contract. Every `moui/views` control hand-builds
`DeclarationKey` records listing the fields that affect each channel
(`view_record_key("Button.layout", [...])`). The reconciler compares these keys
to decide which channel is dirty; a field that is stored in the node struct but
never appears in the relevant channel key cannot invalidate that channel —
changing it silently produces no layout/paint/semantics work. Today nothing
checks that every struct field is either referenced by `declaration()` or
deliberately excluded, so correctness rests entirely on per-control
discipline plus incident-driven tests.

## Decision

Add a static PR-profile gate,
`tools/moui/validate_viewnode_declaration_coverage` (thin `.mjs` shim over
`scripts/lib/moonbit-tool-runner.mjs`, per the Script Tooling Policy):

- Walk non-test `.mbt` files in framework packages; for each
  `impl ... ViewNode for X` that defines `declaration`, pair it with
  `struct X` and require every field identifier to occur in the
  `declaration()` body, or carry a `// declaration-exempt: <reason>` marker on
  the field line.
- Fail the PR profile when a violation is outside the checked-in baseline;
  ratchet the baseline down to zero for `moui/views` as violations are fixed,
  then tighten to a hard gate.
- Record the rule as invariant P17 (`docs/invariants.md`), detected by this
  validator.

A future deterministic generator (`tools/moui/generate_view_declarations`,
`--check` drift mode like `generate_grapheme_property_data`) may emit
`declaration()` bodies from field annotations; that generator is out of scope
here and will be proposed only after the gate is clean.

## Options Considered

### Option A: Static coverage gate only (chosen)

- Pros: Catches the dominant failure mode (missing field) mechanically; fits
  the existing MoonBit-tool + ratchet pattern; zero framework API change;
  exemptions stay explicit and reviewable in-source.
- Cons: String-level heuristic, not a parser — field references hidden behind
  helper indirection can produce false positives/negatives; manual keys
  remain hand-written.

### Option B: Full derive code generator now

- Pros: Removes hand-written keys entirely — the Compose-style end state.
- Cons: Rewrites `declaration()` across ~200-file `moui/views` in one step;
  MoonBit has no macros, so generation stays a drift-gated committed artifact;
  too large a blast radius before the gate can prove existing violations.

### Option C: Documentation + reviewer discipline only

- Pros: No tooling cost.
- Cons: This is the status quo that produced the finding; silent staleness is
  exactly the class of bug that scales badly with AI-assisted contribution.

## Rationale

The gate converts the dominant, mechanically detectable failure (a stored
field absent from every channel key) into a PR-time error while preserving the
conservative `Uncacheable` default and per-control expressiveness. Option B is
the correct end state but must land *after* the gate enumerates current
violations; Option A is the prerequisite that makes it safe.

## Consequences

- New controls that add fields must either key them in `declaration()` or add
  an exempt marker; review visibility improves.
- The gate may flag pre-existing legitimate misses in `moui/views`; those get
  fixed (ratchet down) rather than exempted by default.
- Heuristic false positives are bounded: a field used indirectly must be named
  somewhere in the declaration body, which is the same convention the current
  controls already follow.

## Amendment (2026-10-25): views-side duplicate encoders removed

`moui/views/common/declaration_helpers.mbt` lost six `pub fn` encoders in
`d73524c12`: `declaration_option_double`, `declaration_color`,
`declaration_font`, `declaration_brush`, `declaration_border`, and
`declaration_shadow`. Zero call sites is not the reason they went. They were the
silently-stale kind this gate exists to catch: `declaration_font` keyed only
`size` and `weight` (dropping `families` and `style`) and `declaration_brush`
dropped gradient start/end points and radial center/radius, while the private
same-named encoders in `moui/core/view_modifier_labels.mbt` key the whole value.
Because `moui/core` cannot import `moui/views`, the views-side copies could never
win — a control reaching for one produced a declaration key that
under-distinguishes a real theme change, and P17 cannot see that failure because
the field *is* named somewhere in the body.

Replacement mapping, all live and all under `moui/views/common/`:

| removed | use |
|---|---|
| `declaration_option_double` | `view_double_option_key` (`view_control_helpers.mbt:11`) |
| `declaration_color` | `view_color_key` (`declaration_helpers.mbt:105`) |
| `declaration_font` | `view_font_key` (`view_control_helpers.mbt:61`) |
| `declaration_brush` | `view_brush_key` (`view_control_helpers.mbt:136`) |
| `declaration_border` | `view_border_key` (`view_control_helpers.mbt:163`) |
| `declaration_shadow` | `view_shadow_key` (`view_control_helpers.mbt:178`) |

Compatibility: a breaking removal from the published `moui/views` surface, shipped
in the `0.2.x` line. `docs/compatibility-policy.md` allows a `0.x` minor to break
provided the same release carries an upgrade note and a migration example — this
section plus the example in `docs/view-catalog.md` ("Authoring new controls") is
that note. No deprecated alias was left behind, following the ADR 0015 precedent
("breaking change ... no migration shim"): an alias would keep the
under-distinguishing encoder alive, which is the bug being removed.

Option B stays deferred, now with a measured reason rather than a hunch. Reading
every `declaration()` override on 2026-10-24 found a helper gap, not a generation
gap: `view_declaration_auto` (`declaration_helpers.mbt:30`) does not yet cover a
few key shapes some nodes hand-build, and `moui/views/canvas/canvas.mbt` repeats
the identical seven-line block three times (`Canvas:29`, `AnimatedCanvas:81`,
`MeasuredCanvas:161`). Neither blocks a control, so a generator is not the next
step; widening `view_declaration_auto` is, and only when a third control copies a
hand-built block.

## Agent Notes

- **Session context**: source-level audit of MoUI implementation details
  (runtime reconciliation, layout, render protocol, backend, views).
- **Agent model**: gpt-5.5 (ZCode)
- **Key prompt or instruction**: "分析 MoUI 的各种实现细节是否合理？不合理的
  话其他框架是如何做的" followed by "制定计划消除不合理的点".
- **Validation**: validator wbtests; focused `moon test moui/views`; gate
  listed by `node scripts/check.mjs --profile pr --list`.

## References

- `moui/core/view_node.mbt` (`ViewNode.declaration` contract text)
- `moui/runtime/element_reconcile.mbt` (channel dirty classification)
- `docs/invariants.md` (P2/P3 neighbors; new P17 row)
