# 2026-06-28: Markdown Scroll Cache And Caret Latency

- **Agent**: Codex GPT-5
- **Goal**: Fix Markdown Editor large-document scrolling that became slower
  over time, then address the remaining caret delay when clicking after
  scrolling to the bottom.
- **Outcome**: Success for package-level cache/caret hot-path regressions;
  final native Skia interaction smoothness still needs matching-host manual
  smoke evidence.

## Summary

The session moved cached-layer behavior from scroll-history retention toward a
frame-scoped, warmup-based model and tightened the Markdown Editor viewport so
passing blocks do not enter expensive cached-layer paths. A later follow-up
identified the remaining bottom-click delay as caret work: eager fallback
measurement and hit-testing still allowed large source-prefix work or poor
bottom whitespace placement after scrolling.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui/runtime/render_tree.mbt`, `runtime_render_pipeline.mbt`, `runtime_state.mbt`, `element_tree.mbt` | Reworked cached-layer tracking to use previous/current frame visible sets plus warmup admission state. | Keep `cached_layer_count` tied to the current frame instead of accumulated scroll history, and avoid caching transient layers during fast scroll. |
| `moui/render/skia/renderer_cached_layer.mbt` | Kept cached layers reusable when only the destination origin changes; bounded admission records with a 512-record safety guard. | Let scrolling reuse stable same-size cached pixels while preventing renderer-local admission metadata from growing without bound. |
| `examples/markdown_editor/app/view_editor_surface.mbt` | Reduced rich text visible overscan to `min(320.0, viewport_height * 0.5)`. | Keep the Markdown hot path focused on the visible window plus a small stable buffer. |
| `examples/markdown_editor/app/editor_navigation.mbt`, `editor_target_sync.mbt` | Routed target sync through the active `MarkdownDocumentSession` block and local cheap probes. | Avoid full-document target discovery after ordinary bottom clicks while preserving existing link/image/footnote/html behavior. |
| `moui_richtext/rich_text_editor.mbt` | Replaced eager `unwrap_or(...)` caret fallbacks with lazy `match`/helper paths in overlay, composition underline, focused input state, and Markdown session input state. | MoonBit eagerly evaluates `Option::unwrap_or`, so the old code measured huge plain-text prefixes even when the windowed caret rect was available. |
| `moui_richtext/rich_text_editor.mbt` | Optimized source-offset hit-testing to avoid per-preceding-block measurement, while preserving x-based placement for clicks below the last visible block. | Keep bottom clicks cheap without regressing existing click coordinates or paste-selection tests. |
| `moui/runtime/cached_layer_tracking_wbtest.mbt`, `moui/render/skia/skia_renderer_frame_cache_wbtest.mbt`, `examples/markdown_editor/app/*_wbtest.mbt` | Added or updated regressions for frame-scoped cached layers, warmup, origin-only Skia cache hits, long-scroll bounds, bottom click input state, and clipboard selection behavior. | Lock in the performance contracts and catch the bottom-click/caret regressions that appeared after the scrolling fixes. |

## Key Decisions

- Treat runtime cached-layer admission as a runtime responsibility, not a
  renderer-only skip decision, so runtime and renderer cache state stay aligned.
- Warm cached layers for 3 consecutive visible frames before emitting
  `BeginCachedLayer`; fast-scrolled, one-off blocks stay in direct draw.
- Keep the Skia admission-record limit as a bounded safety guard rather than the
  main scrolling-performance mechanism.
- Preserve `controlled_markdown_session_editor` and
  `MarkdownDocumentSession::rich_text_window` as the primary Markdown large-file
  path; do not add public API for the app-specific active-block target-sync
  helpers.

## Discoveries

- MoonBit `Option::unwrap_or` evaluates the fallback eagerly. In caret code,
  that made `plain_rich_text_caret_rect(display_text, caret, ...)` run on every
  focused paint even when `rich_text_document_caret_rect_at_source` succeeded.
- At the bottom of a large document, a full plain-text caret fallback can
  measure a prefix near the whole source length, explaining visible caret
  latency after click.
- The initial hit-test optimization avoided repeated preceding-block work, but
  needed one final last-block x-based hit-test for clicks in bottom whitespace
  to preserve prior selection behavior.
- App tests that click in editor whitespace can expose caret-placement changes
  even when the interactive user symptom is latency.

## Validation

```sh
moon test moui_richtext --target native
moon test examples/markdown_editor/app --target native
moon test moui/runtime --target native
moon test moui/render/skia --target native
moon fmt --check moui_richtext/rich_text_editor.mbt \
  examples/markdown_editor/app/editor_navigation.mbt \
  examples/markdown_editor/app/editor_target_sync.mbt \
  examples/markdown_editor/app/editor_app_end_click_runtime_wbtest.mbt \
  examples/markdown_editor/app/markdown_core_imports.mbt \
  examples/markdown_editor/app/editor_commands_inline_targets_wbtest.mbt \
  examples/markdown_editor/app/editor_app_clipboard_runtime_wbtest.mbt
git diff --check
```

Warnings observed were existing dependency/app warnings, not failures:
`bobzhang/mbtexcel` main-package dependency warnings and unused Markdown Editor
app fields/menu variants.

## Follow-Up

- [ ] Run Markdown Editor native Skia manual scroll/click smoke before claiming
      final real-world interaction smoothness.
- [ ] Profile remaining bottom-click latency if native smoke still shows a
      visible delay; likely next suspects are text-system measurement cache
      locality and host text-input polling frequency.
- [ ] Consider adding a small focused test for bottom-whitespace click placement
      if more hit-test changes are made.
