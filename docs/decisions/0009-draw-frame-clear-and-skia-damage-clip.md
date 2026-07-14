# 0009: DrawFrame Clear Ownership and Skia Damage Clipping

- **Date**: 2026-07-14
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex, GPT-5)
- **Related**: ADR 0007, `moui/core/damage.mbt`, `moui/runtime/runtime_state.mbt`,
  `moui/render/skia/renderer.mbt`

## Context

ADR 0007 introduced partial damage clearing and skipped `DrawCachedLayer`
commands outside the damage region. It did not clip the rest of the command
stream. Runtime frames also carried both `DrawFrame.clear_color` and a leading
`DrawCommand::Clear`.

On a button hover, runtime correctly produced a small damage rect. Skia cleared
that rect, then the unbounded leading `Clear` or a full-surface background
overwrote pixels outside it. Cached rich-text layers outside the damage rect
were skipped, so Markdown Editor and Code Editor text disappeared until a later
full repaint or editor-local update.

The clear also happened before logical-to-physical canvas scaling, so HiDPI
damage rects addressed the wrong physical area.

## Decision

1. `DrawFrame.clear_color` is the authoritative frame initialization color.
   Runtime-generated `DrawFrame.commands` contains view content and cached-layer
   commands, without a leading `Clear`.
2. Legacy command-only renderer adapters materialize
   `DrawCommand::Clear(frame.clear_color)` when lowering a frame. This applies
   to `HostWindowRenderer` fallback rendering, browser WebGPU host calls, and
   Linux client-side decoration composition.
3. Skia resolves rect damage to one conservative union rect, applies logical
   canvas scaling, clips the canvas to that rect, clears it, and executes the
   complete command stream inside the same clip.
4. Cached layers outside the effective damage rect may still be skipped because
   no other command can now alter their retained pixels.
5. Scope commands keep the ADR 0007 conservative `FullSurface` fallback.
   Explicit compatibility `Clear` commands remain supported and are constrained
   by the damage clip.

## Options Considered

### Skia-only Clear special case

- Pros: Small patch.
- Cons: Full-surface backgrounds would still erase retained cached layers, and
  the duplicate frame-clear contract would remain ambiguous.

### Disable partial damage

- Pros: Restores correctness immediately.
- Cons: Discards the accepted ADR 0007 optimization and its future value.

### Authoritative clear color plus full command clip (chosen)

- Pros: Defines one frame contract, preserves partial damage, handles every
  command rather than a whitelist, and fixes HiDPI coordinates.
- Cons: Legacy adapters must explicitly lower the clear, and multiple damage
  rects are conservatively unioned for Skia.

## Rationale

Damage rendering is correct only when clearing, ordinary draw commands, and
cached-layer replay all observe the same region. Moving only `Clear` is
insufficient because an app background can cover the same pixels. Clipping the
complete command stream establishes the invariant directly.

Keeping `clear_color` separate from content commands also matches the existing
`DrawFrame` data model and avoids making renderer behavior depend on command
ordering. Command-only renderers keep compatibility at a narrow adapter
boundary.

## Consequences

- Hover and other small paint updates preserve cached rich-text pixels.
- Runtime frame command counts decrease by one; legacy `draw_commands()` still
  begins with `Clear`.
- Skia may redraw the bounding union between disjoint damage rects. Runtime
  already falls back to full damage when that union covers most of the surface.
- New tests cover the frame-clear contract, legacy adapter lowering, browser
  WebGPU lowering, cached sibling pixels after hover, explicit compatibility
  clears, and scale-factor 2 damage coordinates.

## Agent Notes

- **Session context**: Fix intermittent blank Markdown Editor and Code Editor
  text during button hover.
- **Agent model**: Codex (GPT-5)
- **Key prompt or instruction**: "做最合理的长期修复"
- **Validation**: Focused runtime, host, WebGPU, Skia, Markdown Editor, and Code
  Editor checks plus repository validation and native Skia smoke.

## References

- `docs/decisions/0007-skia-layer-cache-indexing-and-damage-region.md`
- `docs/architecture.md`
- `docs/testing.md`
