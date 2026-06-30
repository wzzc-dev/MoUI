# 2026-06-29: Fix Markdown Editor File Tree Scrolling

- **Agent**: Trae AI
- **Goal**: Make the directory tree in the Markdown Editor file sidebar scrollable when it contains many entries.
- **Outcome**: Success (tree_view wrapped in scroll_view with bounded height)

## Summary

The `files_inspector` in `view_inspectors.mbt` rendered the directory tree with `@views.tree_view(...)` directly, which has no built-in height limit or scrolling. When the tree had enough entries, it overflowed the sidebar and pushed the "Recent" section and other content below the visible area. The fix wrapped `tree_view` in a `scroll_view` with a bounded height, and adjusted the "Recent" section's scroll height to share the available vertical space.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `examples/markdown_editor/app/view_inspectors.mbt` | Wrapped `tree_view` in `scroll_view` with `height=tree_scroll_height` | Enable tree scrolling with bounded viewport |
| `examples/markdown_editor/app/view_inspectors.mbt` | Introduced `tree_scroll_height = max(0.0, height - 260.0)` | Allocate most space to tree, reserve ~80px for Recent |
| `examples/markdown_editor/app/view_inspectors.mbt` | Adjusted `recent_content` scroll height to `max(0.0, height - 180.0 - tree_scroll_height)` | Prevent overlap between tree and Recent scroll areas |

## Key Decisions

- Tree gets the larger share (`height - 260`), Recent gets ~80px fixed reserve
  (enough for 2-3 recent files).
- Keep two independent scroll areas (tree + Recent) rather than one combined —
  matches existing partition design.
- Reuse `markdown_editor_max_double` helper (already existed).
- No changes to `moui/views/data_tree.mbt` — `tree_view` is intentionally
  scroll-unaware; callers wrap it as needed.

## Discoveries

- `tree_view` signature has no `height?` parameter; its internal `column` grows
  unbounded with content.
- The existing height constant `180.0` was the implicit fixed overhead for
  the `files_inspector` header area (padding, labels, buttons, "Files"/"Recent"
  headers, spacing).
- Existing tests (`editor_app_file_sidebar_wbtest`) verified tree rendering and
  toggle but did not test overflow behavior.

## Validation

```sh
moon check
moon test -p markdown_editor
moon test -p markdown_editor -f editor_app_file_sidebar_wbtest
```
