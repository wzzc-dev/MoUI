# Markdown Editor Layout Patterns

## Typora-Style Flush Layout

- Sidebar/outline flush with window edges: use `spacer(weight=1.0)` on both sides
  of the editor inside a `row`, NOT `padding_edges` on the chrome container.
- `padding_layout` clamps child width to `min(available.max.width, child_size.width)`,
  so it blocks `expanded()` from filling the window — use `expanded()` directly
  on the workspace instead of wrapping in `padding_edges` for horizontal stretch.
- Remove `row([single_child])` wrappers that have no spacer — they prevent the
  child from filling the container width. A `column(Stretch)` parent can stretch
  children directly.
- When all inspectors are hidden, the editor must still go through the
  `row([spacer(1), editor, spacer(1)])` path (not an early return) to stay centered.
- Sidebar/outline `corner_radius=0.0` when flush with window edges (prevents
  window background "triangle" artifacts).
- `CrossAlign::Stretch` in the row makes sidebar/editor/outline fill column height;
  `CrossAlign::Start` leaves gaps at the bottom.

## Scroll in Side Panels

- `tree_view` has no built-in height limit or scrolling — always wrap in
  `scroll_view` with a bounded `height` when used in a side panel.
- When splitting scroll area between tree and "Recent" list, allocate the larger
  space to the tree (e.g., `height - 260`) and reserve ~80px for "Recent".
- Use `markdown_editor_max_double(0.0, height - N)` for safe non-negative heights.