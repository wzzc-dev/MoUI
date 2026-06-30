# 2026-06-29: Markdown Editor Typora-Style Flush Layout

- **Agent**: Trae AI
- **Goal**: Make the Markdown Editor's sidebar and outline panels flush with window edges (Typora style) while keeping the editor horizontally centered.
- **Outcome**: Success (layout changes implemented, 8 test failures fixed, dead code cleaned up)

## Summary

Three rounds of changes transformed the Markdown Editor layout. First, the sidebar/outline were made flush with window edges by replacing `padding_edges`-based centering with `spacer(weight=1.0)` in a `row`. The initial implementation caused 8 test failures (click/selection offsets changed). A second round removed an outer `row` wrapper that prevented `editor_source_layout` from filling the window width, and replaced `padding_layout` with `expanded()` + `spacer` to avoid `padding_layout`'s width-clamping behavior. A third round deleted the now-unused `markdown_editor_centered_workspace` function.

## Changes Made

### Round 1: Flush Layout

| Package/File | What Changed | Why |
|---|---|---|
| `examples/markdown_editor/app/view_chrome.mbt` | Zeroed chrome `left`/`right` padding (`24.0`/`12.0` → `0.0`) | Eliminate window-edge-to-workspace gap |
| `examples/markdown_editor/app/view_chrome.mbt` | Replaced `markdown_editor_centered_workspace(padded).expanded()` with `padded.expanded()` | Let workspace fill window width |
| `examples/markdown_editor/app/view_editor_surface.mbt` | Added `spacer(weight=1.0)` on both sides of editor in row | Center editor, let sidebar/outline flush with edges |
| `examples/markdown_editor/app/view_inspectors.mbt` | Set `corner_radius=0.0` for sidebar and outline | Prevent background "triangle" artifacts at window edges |

### Round 2: Fix 8 Test Failures

| Package/File | What Changed | Why |
|---|---|---|
| `examples/markdown_editor/app/view_chrome.mbt` | Removed outer `row([editor_source_layout(...)])` wrapper | Outer row blocked `editor_source_layout` from filling window width |
| `examples/markdown_editor/app/view_editor_surface.mbt` | Removed early return when all inspectors hidden | Editor must always go through `row([spacer(1), editor, spacer(1)])` path |
| `examples/markdown_editor/app/editor_test_helpers_wbtest.mbt` | Rewrote `editor_content_x` with new layout math | Account for spacer-based centering instead of chrome padding |

### Round 3: Cleanup

| Package/File | What Changed | Why |
|---|---|---|
| `examples/markdown_editor/app/view_chrome.mbt` | Deleted `markdown_editor_centered_workspace` function | No longer called anywhere |

## Key Decisions

- Use `expanded()` directly on workspace rather than `padding_layout` — the latter
  clamps child width to `min(available.max.width, child_size.width)`, blocking
  horizontal stretch.
- Always route editor through `row([spacer(1), editor, spacer(1), ...])` even when
  all inspectors are hidden, so the editor stays centered in all states.
- Use `CrossAlign::Stretch` in the row layout so sidebar/editor/outline fill the
  full column height.
- Keep `spacing=0.0` in the row — flush edges should have no gap between panels
  and window edge.

## Discoveries

- `padding_layout` (`moui/views/layout_views.mbt:59-62`) clamps child width to
  `min(available.max.width, child_size.width)`, which prevents `expanded()` from
  filling the container.
- A `row` with only one child and no spacer prevents that child from filling the
  row's width, even when the parent column uses `Stretch`.
- `editor_content_x` must model `left_width + max(0, (available - editor_width) / 2)`
  when inspectors are present, and `(window_width - editor_width) / 2` when absent.

## Validation

```sh
moon check --target wasm-gc
moon test --target wasm-gc -p markdown_editor
moon test --target wasm-gc
```

8 previously failing tests all pass:
- `editor_snapshot_wbtest`: click/selection/drag tests
- `editor_app_task_runtime_wbtest`: task checkbox toggle test
- `editor_app_clipboard_runtime_wbtest`: paste command tests
- `editor_app_backspace_delete_runtime_wbtest`: backspace remove heading marker test

## Follow-Up

- [ ] Visual smoke on native Skia to verify flush edges and centered editor in all inspector-toggle states.