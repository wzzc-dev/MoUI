# 0050: Damage classification precedes partial-surface presentation

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W0.5/W2.1-W2.3),
  ADR 0007, ADR 0009, ADR 0048

## Context

MoUI has three damage concepts but only one was explicit:

1. an invalidation reason, such as a program message, environment change, or
   overlay exit;
2. the visual work a rebuild produced, such as paint-only declaration changes
   or a tree/layout change;
3. the pixel region a renderer must clear and repaint for one presented frame.

The runtime currently collapses all three. `request_root_rebuild` sets
`full_damage_reason` for every program message, and `compute_damage_region`
returns `FullSurface` before reconciliation can prove that nothing changed.
Consequently a no-op message damages the entire surface, while a paint-only
selection change also loses precise dirty bounds.

The opposite shortcut is unsafe. Reconciliation marks declaration-changed
elements paint-dirty. A clean sibling moved by another element's layout change
does not enter that set, so dirty-id bounds alone can leave its exposed strip
uncleared. Overlay placement, animation, and environment changes have the same
problem. The damage producer must fail closed until every moved region is
tracked.

Renderers also differ in what they can consume. `DamageRegion` is a transport
type; it is not evidence that a host can present a sub-rectangle correctly.
ADR 0007/0009 established Skia's clear-and-clip contract, including conservative
fallbacks. Those fallbacks must remain distinct from deciding whether a host is
allowed to receive partial damage at all.

## Decision

### Invalidation classification

The runtime classifies visual work before computing a frame's damage:

| Class | Examples | Damage |
|---|---|---|
| No visual work | program projection returns equal declarations; successful rebuild with no paint/layout/structure work | `Empty` |
| Paint-only change | declaration channel change with no layout or structure change; focus or selection paint change | rects from previous and current damage bounds of paint-dirty ids |
| Layout or structure change | insertion, deletion, reorder, layout declaration change, placement movement | `FullSurface` until move tracking is implemented |
| Environment/global change | theme, text system, locale, scale, viewport resize | `FullSurface` |
| Activation/lifecycle change | activation rebuild, overlay enter/exit or placement change | `FullSurface` |
| Unknown work | paint pass without usable dirty bounds, missing previous/current node, accumulated incompatible damage | `FullSurface` |

`Empty` means exactly "no pixels changed since the previously built frame". It
does not mean "the damage computation failed". Unknown work must use
`FullSurface` with a reason.

An explicit full-surface invalidation wins over all local classification. A
layout/structural classification upgrades a projection rebuild to full even
when a dirty leaf exists. Paint-only rects include both the previous and current
bounds of each dirty element and respect repaint boundaries.

The animation clock is not a damage classification input. An active animation
must keep its affected region dirty through the existing animation contract;
until its motion is tracked precisely, its frame remains full-surface.

Damage accumulates across every paint pass between presented frames. Any full
surface in that union dominates rects, and rects are coalesced/clipped by the
existing `DamageRegion` budget.

### Surface capability

A renderer session exposes one of:

- `FullSurfaceOnly` — the default. It may redraw the whole surface, or skip
  presentation for `Empty`, but it must not treat rects as a partial present.
- `SubRect` — the host can clear, clip, redraw, and present the supplied damage
  region without disturbing other pixels.

Capability is negotiated explicitly by the composition root/session. It is not
inferred from a renderer name, backend, or the fact that a previous frame used
partial damage.

`SubRect` is enabled only when all of the following hold:

1. the runtime supplies non-empty, correct damage for the frame;
2. the renderer's clear, ordinary draw commands, clips, cached layers, scope
   commands, and presentation path all honour that same region;
3. a pixel-comparison self-check proves the partial frame equal to a
   full-surface reference;
4. matching-host evidence records raster, present, and frame-pacing cost.

Unsupported hosts remain `FullSurfaceOnly` byte-for-byte. `Empty` cannot mean
"fall back to full" inside a `SubRect` session; if the host must present for
another reason (surface acquisition or compose), it uses a full-surface frame
explicitly.

This ADR does not add a root-facade or application-level capability API.
W2.2 introduces the smallest render-protocol enum and session accessor needed
to negotiate the capability, and W2.3 supplies the pixel gate.

### HarmonyOS/EGL device re-evaluation (2026-11-05)

W2.3b was evaluated on a matching `HAD-W32` (HarmonyOS `7.0.0.107`, 2090×1324
surface, Maleoon 916, OpenGL ES 3.2). The current-tree Showcase HAP produced
277 measured long-drag frames across two runs. Every frame requested
full-surface damage: runtime reasons were "dirty region covers most of the
surface", "activation rebuild", and one "dirty bounds unavailable". EGL present
cost only 1.2-2.4 ms, and inter-frame p50/p95 was 16/20 ms and 20/26 ms.

The runtime therefore supplied no eligible rect damage, and the full-surface
frame budget was not measurably missed. EGL partial presentation was not
enabled, no `EGL_KHR_partial_update` / damage-swap implementation was added, and
no device pixel-equality claim was made. This is an evidence-backed
non-adoption, not a waiver.

Reopen only when all three conditions hold:

1. the runtime produces correct rect damage during real scroll;
2. a matching device still misses the full-surface frame/present budget; and
3. the device EGL surface exposes the required preserved-buffer and
   damage-swap extensions.

The next runtime-side investigation is app-owned transient scroll state, not a
presenter change. Local device artifacts are under
`artifacts/harmonyos/w23b-baseline/` and are not committed.

### Post-N5 host-side result (2026-11-05)

N5 removed the app-owned scroll feedback loop. The normal Showcase wheel and
drag paths now keep transient offsets in the element state, dispatch no program
message, and perform no activation rebuild. This eliminates one cause from the
device capture above, but it does not produce rect damage:

- wheel frames remain full-surface with `layout changed`, because a scroll
  container changes its layout-phase child transform;
- drag frames can remain full-surface with
  `damage accumulated across paint passes` when more than one paint contributes
  before presentation.

No `SubRect` capability was enabled and no partial-present code was added. A
future rect path must first derive moved-content bounds from the transform and
prove that the viewport clip covers every exposed pixel; a host still also needs
the matching-device frame-budget and EGL extension gates above.

## Options Considered

### Option A: keep forcing full damage for every rebuild

- Pros: trivially avoids stale pixels; no classification audit.
- Cons: no-op messages and paint-only changes always pay full-surface clear,
  raster, upload, and present cost; the dirty-id damage path remains unusable
  for the normal message path.

### Option B: use dirty-id bounds for every rebuild

- Pros: minimal implementation and maximal immediate precision.
- Cons: unsound for clean siblings moved by layout, deletion/reorder,
  overlay placement, and animation. It can leave exposed strips unpainted.

### Option C: classify invalidation, then require explicit surface capability

- Pros: sound conservative fallbacks, useful precision for paint-only changes,
  and a clear gate before any platform enables partial presentation.
- Cons: two contracts must stay synchronized; each renderer needs evidence
  before gaining `SubRect`.

The project chooses Option C.

## Rationale

Damage precision is useful only when it is both conservative and testable.
Separating why a frame was invalidated from what pixels changed lets a no-op
message become `Empty` without pretending that layout movement is local.
Paint-only changes already have previous/current render trees for exact bounds,
so they can be precise without new placement machinery.

Surface capability is a separate trust boundary. A correct runtime region does
not make an unaware renderer safe. Defaulting to `FullSurfaceOnly` preserves
existing platform behavior while allowing one renderer at a time to prove the
whole clear/draw/present contract.

## Consequences

- A successful no-op projection rebuild produces `DamageRegion::Empty`.
- Paint-only focus/selection changes can reach the renderer as rects.
- Structural and layout changes remain full-surface until move tracking exists;
  this is deliberate over-coverage, not an accidental fallback.
- Environment, resize, activation, overlay lifecycle, and unknown work are
  explicit full-surface causes rather than the generic
  `"program model changed"` reason.
- Existing full-surface renderers remain correct. They may ignore the new
  precision until capability and pixel gates pass.
- The W2.2 implementation is limited to an explicit CPU-raster `SubRect`
  opt-in. The Skia GPU route and every production composition root still
  negotiate `FullSurfaceOnly`; HarmonyOS/EGL remains there after the
  2026-11-05 device evaluation. Enabling another host requires its own
  pixel-coverage, host-capability, and matching-device cost evidence.
- W2.4 must revisit the layout/structure row when scroll uses content
  coordinates; placement-level move tracking is the prerequisite for narrowing
  it.

## Agent Notes

- **Session context**: consolidating three MoUI architecture reviews into an
  execution plan and landing the damage-classification slice.
- **Key prompt**: combine the three analyses into the next development plan.
- **Validation**: runtime white-box tests cover no-op, paint-only selection,
  focus, structure/deletion, reorder, scroll, overlay, and environment
  invalidation. Skia white-box tests compare an explicit CPU-raster `SubRect`
  frame with the full-surface reference, cover disjoint damage-union and
  HiDPI coordinates, and pin scope fallback and empty-damage skip behavior.
  The runtime, renderer, renderer-contract, and repository `pr` suites gate
  the change. W2.3b later captured a matching HarmonyOS device, observed only
  full-surface frames, and closed as non-adoption without claiming device
  pixel equality.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `docs/decisions/0007-renderer-and-skia.md`
- `docs/decisions/0048-render-cache-key-contract.md`
- `moui/core/damage.mbt`
- `moui/runtime/runtime_render_pipeline.mbt`
- `moui/runtime/runtime_state.mbt`
