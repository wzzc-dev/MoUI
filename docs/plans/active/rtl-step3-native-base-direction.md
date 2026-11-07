# Plan: RTL step 3 — native provider base-direction plumbing

- **Status**: active
- **Goal**: Plumb `TextLayoutInput.direction` into the native text providers
  so mixed-direction text (LTR base with embedded RTL runs and the reverse)
  resolves against the declared base direction instead of shaper auto-
  detection alone, keeping the mirrored caret contract of RTL steps 1–2
  consistent with native glyph rendering.
- **Environment prerequisite**: the SkParagraph-enabled Skia artifact
  (`MOUI_SKIA_ENABLE_SKPARAGRAPH=1`, wired by the proof-matrix config) and a
  fontconfig/HarfBuzz build for the fontconfig provider. The binding-surface
  survey below is host-independent.

## Starting point (verified 2026-11-07)

- Step 1: `TextLayoutInput.direction` exists; the core fallback mirrors
  stabilized carets for `RightToLeft`.
- Step 2: `views/text` forwards `Environment.layout_direction` into every
  measurement and its caret/selection/hit-test mappings are direction-
  agnostic against the measured positions.
- Native providers keep shaper auto-detection: cosmic_text shapes runs with
  its own bidi resolution; SkParagraph (behind
  `MOUI_SKIA_ENABLE_SKPARAGRAPH`) already carries bidi/visual-order smoke
  markers in the proof matrix — but neither reads `input.direction` yet, so
  an LTR base with an embedded RTL run (or the reverse) resolves its base
  from the first strong character instead of the app's declaration.

## Slices

1. **Binding survey + surface**: for each provider, find the base-direction
   knob on the native side — SkParagraph's `ParagraphStyle.text_direction`
   (via the `skia_paragraph` wrapper), cosmic's per-buffer base direction,
   DirectWrite's `DWRITE_READING_DIRECTION` (coordinate with
   `text-provider-native-completion.md`), CoreText's paragraph direction.
   Expose each through the provider's `measure`/`paragraph_layout` seam.
2. **SkParagraph slice**: forward `direction` into the paragraph style,
   assert with the existing bidi smoke markers extended by a
   base-direction-override case (LTR base, RTL-dominant run → visual order
   must follow the base).
3. **cosmic slice**: set the buffer base direction in
   `build_cosmic_text_input_buffer`; the provider's caret extraction already
   consumes runs, so mirrored/visual carets must be reconciled with the
   fallback's `caret_positions[i] == width - ltr[i]` contract per provider.
4. **Contract test**: a shared direction matrix fixture (LTR base + RTL run,
   RTL base + LTR run, pure runs both ways) run against every provider with
   the same assertions, so provider parity is mechanical.

## Acceptance

- [ ] All native providers read `TextLayoutInput.direction` at the seam.
- [ ] The direction matrix fixture passes per provider (or a provider
      honestly reports the gap in `renderer-capability-report.md`).
- [ ] The bidi smoke markers include a base-direction-override observation
      with SkParagraph provenance.
- [ ] `docs/text-system.md`'s run-internal direction section drops the
      "base-direction plumbing" caveat.

## Validation

```sh
moon test moui_text_providers --target native
moon test moui_skia_renderer --target native
sh scripts/check.sh --profile platform
```
