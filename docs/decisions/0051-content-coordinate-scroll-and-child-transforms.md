# 0051: Scroll layout stays content-local behind a child transform

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W2.4), ADR 0048,
  ADR 0050

## Context

A scroll offset used to be baked into every descendant frame by
`ScrollContainer::layout`. A wheel step therefore changed the placement input
of the whole scroll subtree even though its content, wrapping, and intrinsic
sizes did not change. Place and render caches key on those frames, so the
scroll path recorded hundreds to thousands of misses per tick and repainted
the same content at a new origin.

The offset cannot simply move into paint. Pointer hit-testing, focus/caret
reveal, semantics/accessibility frames, overlay anchors, native platform-view
placements, and damage all currently read placed frames as screen coordinates.
A paint-only fix would leave those boundaries in content coordinates and make
the rendered surface disagree with input and accessibility.

## Decision

`ViewLayoutResult` gains `child_transform : Transform2D`, defaulting to the
identity. The transform maps the coordinate space of this node's child frames
into its own coordinate space. Layout continues to return content-local child
frames; a viewport moves its content by declaring a transform, not by
rewriting every descendant frame.

The runtime carries the transform as scene-graph state:

- `PlacedNode` and `RenderNode` store the local `child_transform` and
  `clips_children`; frames and paint bounds remain local.
- Paint wraps regular children in one `PushTransform`/`PopTransform` pair.
  Hoisted overlay children escape the transform and the ancestor clip.
- Pointer and drag/drop traversal carries the accumulated transform and clip.
  Hit tests use transformed frames; event contexts still receive screen-space
  frames and child frames.
- `ViewPaintContext` and `DrawCommand` geometry stay node-local. The runtime
  wraps regular children in the accumulated transform while emitting draw
  commands; hoisted overlays carry their own screen placement.
- The legacy `AppRuntime::draw_commands()` accessor is a compatibility
  projection, not a second layout model: it folds layout translations into
  command geometry and emits screen-space commands. `DrawFrame.commands` keeps
  node-local geometry plus explicit transform scopes for renderers.
- Semantics builds screen-space frames from the accumulated transform.
  Accessibility consumes the same committed semantics frames.
- Stable-key anchors, overlay placement, `scroll_to_key`, and caret/selection
  reveal resolve through the same accumulated transform.
- `ViewPlatformContext` supplies a node-local frame and transformed child
  frames. `platform_views` returns placements in that local space; the
  platform tree caches those rectangles and transforms them only when it
  collects `DrawFrame.platform_views`.
- Damage indexing transforms local paint bounds into screen space. A frame
  containing a transform remains full-surface until move tracking can describe
  the moved pixels and retained-layer damage in screen space.

The root transform is identity. For a node whose accumulated transform is
`parent`, its children use `parent * node.child_transform`. An overlay child
uses identity because its frame and subtree are already hoisted into root
coordinates.

Scroll content uses a static content-local frame at the viewport origin. The
transform is `(-offset.x, -offset.y)` in left-to-right layout. In
right-to-left layout the x translation is
`offset.x - max(0, child_width - viewport_width)` so `offset.x` remains a
leading-edge distance. The existing rubber-band overshoot stays a paint-only
additional translation.

## Consequences

- Changing a scroll offset re-runs only the scroll container's own layout and
  paint. Descendant place/render cache keys see the same content-local frames
  and can hit.
- `LayoutResult`, event contexts, semantics, anchors, collected native
  platform-view placements, and damage use screen-space geometry. Paint
  contexts, draw commands, and the `ViewPlatformContext` passed to
  `platform_views` are node-local; the runtime emits or applies the matching
  transform. Consumers must not mix the two spaces.
- The one exception is the legacy command-only accessor, which projects
  placement translations into its returned command geometry for compatibility
  with existing tests and preview adapters. New renderer work must consume
  `DrawFrame` and must not flatten its transform scopes.
- Native platform-view definitions cache node-local placement rectangles. The
  platform tree applies the current accumulated transform during collection,
  so scrolling can move a native view without rerunning its `platform_views`.
  The runtime, not a host callback, owns that projection.
- Consumers that start below the root must carry or recover the accumulated
  transform. Starting from a bare `PlacedNode` and treating its frame as a
  screen rect is no longer valid.
- Retained-layer damage stays conservative under a transform until the
  renderer can evaluate layer bounds in the same transformed space. This is
  intentional: a visually correct cache hit is not permission to under-cover
  damage.
- Transform-aware semantics caches include the accumulated transform. A scroll
  step may therefore recompute semantics frames even when layout and render
  caches hit; correctness of accessibility bounds takes priority until a
  transformed-replay cache exists.
- A retained draw-command cache cannot inline a hoisted overlay subtree: replay
  would place the overlay under the cache owner's transform even though the
  overlay must escape it. Such a repaint boundary keeps its boundary role but
  falls back to uncached composition.

## Rejected alternatives

### Keep absolute frames and only change the cache key

The cache could hit, but the cached subtree would still contain previous-frame
screen coordinates. Updating them requires an O(subtree) rebase, and any missed
consumer would observe stale geometry.

### Apply the offset only in paint

This is the smallest patch, but pointer input, semantics, anchors, native
platform views, and damage would all disagree with the painted image.

### Introduce a mutable scene-graph object

The transform is layout output and remains immutable data. No hidden mutable
component state or second lifecycle model is introduced.

## References

- `docs/plans/done/architecture-priority-execution.md` (W2.4)
- `moui/core/view_protocol.mbt`
- `moui/runtime/layout.mbt`
- `moui/runtime/render_tree.mbt`
- `moui/views/controls/scroll_view_layout.mbt`
