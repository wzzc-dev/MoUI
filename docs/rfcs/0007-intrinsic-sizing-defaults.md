# RFC 0007: Intrinsic Sizing Defaults for Leaf Controls

Status: Accepted (2026-11-09) — proposal 1 landed for `text()`; proposals 2
(buttons/inputs) and the example pixel-size cleanup remain deferred.

Author: plan `docs/plans/done/hot-path-invalidation-boilerplate-convergence.md` (J1)

## Context

MoUI leaf controls default to fixed pixel boxes and require explicit
`width~`/`height~` at every call site:

- `text()` defaults to a 160×32 fixed box (`moui/views/text/text.mbt:14-25`);
  without `wrap`, overflow clips to the box.
- Every other constructor carries pixel defaults or expects explicit sizing
  (`button` width=100/height=40, `checkbox_control` with 9 optional
  parameters, and so on).
- The examples pay for this everywhere: `data_table/app` threads pixel sizes
  through nearly every control (`text(width=260, height=34)`,
  `button(width=96, height=36)`, `container(width=980, height=700)`), and the
  8–11 optional constructor parameters per control exist largely to carry
  those pixel knobs plus their declaration-key counterparts.

This inverts the expectation users bring from Flutter/Compose/web, where text
sizes to content and containers wrap it. It also couples API surface growth to
declaration-key growth: every new visual knob is one more constructor
parameter **and** one more hand-maintained declaration-key entry (now
generated from `checks/viewnode-declarations.json` per ADR 0034 Option B, but
still one more entry to author).

## Problem

1. **Authoring cost.** Pixel sizing must be re-derived at every call site and
   re-tuned when text scale, locale, or content changes.
2. **Accessibility.** Fixed pixel boxes do not track `text_scale`; scaled text
   clips inside boxes sized at scale 1.0.
3. **API area.** Constructor parameter lists grow with every layout knob and
   drag the declaration schema with them.

## Proposal

Make content-derived intrinsic sizing the default for leaf text-shaped
controls, and keep explicit sizes as opt-in overrides:

1. **`text()` sizes to content by default.** Without `width~`, the measured
   width is the laid-out text width under the ambient font (already computed
   by the text system); with `wrap=true`, the node accepts any width up to the
   incoming constraint and grows downward (current wrap behavior), reporting
   its measured height. Explicit `width~`/`height~` keep today's exact
   semantics (a fixed box).
2. **Buttons and single-line inputs keep their current defaults for one
   release**, then move to content-derived width with the existing padding
   tokens; their height already derives from the theme's control size tokens,
   so the change is width-only.
3. **Containers never infer from children** — MoUI's two-pass
   measure/place model keeps container sizing explicit (this proposal changes
   leaf controls only, not flex distribution or `expanded`).
4. **Declaration keys grow an intrinsic branch.** Content-sized nodes key
   their layout channel on (text, font inputs, wrap) exactly as today's
   `Text.layout` key already does; no new invalidation mechanism is needed.
   The constraint-keyed measure memo already distinguishes "sized by parent"
   from "sized by content" because content-sized measurement runs under the
   incoming constraints.

## Consequences

- Apps stop threading pixel sizes; `width~/height~` remain for intentional
  fixed boxes (canvas-like grids, spreadsheet cells — Excel keeps explicit
  sizing).
- Scaled text stops clipping in untyped boxes.
- Constructor parameter lists can shrink instead of grow; the declaration
  schema follows the parameters.
- Migration is opt-in per control behind the existing defaults, so existing
  apps that pass explicit sizes see no change; apps relying on the implicit
  160×32 text box must add it explicitly (one-time, mechanical, caught by the
  golden/render regression suites).

## Non-goals

- No change to flex/`expanded` semantics, `child_frames_tight` refit (ADR
  0035), or container sizing.
- No auto-sizing for platform-view hosts (their native sizing contracts are
  platform-owned).

## Decision request

Accept: `text()` becomes content-sized by default in the next minor, buttons
follow one minor later, and the example apps drop threaded pixel sizes where
the box was not intentional. Decline: keep explicit sizing as the universal
contract and instead document the fixed-box model.

## Decision (2026-11-09)

Accepted for proposal 1 only. `text()` now defaults `width~`/`height~` to
`0.0`, which under the existing minimum-box semantics
(`view_max_double(requested, measured)`) is exactly content sizing — no new
invalidation mechanism and no declaration-schema change were needed, because
`Text.layout` already keys on `min_size`. In `wrap=true` mode an unset width
takes the whole incoming constraint instead of collapsing to the 1px floor.

Explicit `width~`/`height~` keep their exact prior semantics, so callers that
pass sizes are unaffected. Proposals 2 (buttons/inputs) and 3 (containers) are
unchanged; the example pixel-size cleanup is still deferred.
