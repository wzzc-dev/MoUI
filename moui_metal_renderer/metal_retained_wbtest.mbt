///|
/// The cross-frame `BeginRetainedLayer` cache. Four device-free probes over the
/// bookkeeping (hit, update, miss on a move, eviction across a gap, reset on a new
/// context) and one device probe over the pixels, because the claim that matters
/// is that a hit composites what the *previous* frame painted: the only way to
/// tell that apart from re-rendering the current frame is to make the two frames
/// disagree.
fn metal_retained_green() -> @core.Color {
  @core.Color::rgba(r=0.0, g=1.0, b=0.0)
}

///|
priv struct MetalRetainedFrame {
  rebuilt : Int32
  cached : Int32
  updated : Int32
  evicted : Int32
  items : Int32
  vertices : Int32
}

///|
fn metal_retained_boundary(
  revision : Int32,
  frame~ : @core.Rect,
  child~ : @core.DrawCommand,
) -> Array[@core.DrawCommand] {
  [
    @core.BeginRetainedLayer(
      @core.RetainedLayerSpec::new(
        key="metal-retained-boundary",
        frame~,
        content_revision=revision,
      ),
    ),
    child,
    @core.EndRetainedLayer("metal-retained-boundary"),
  ]
}

///|
/// Build one frame against a cache that survives across calls. `context` is 0 for
/// the bookkeeping probes, which need no device; the pixel probe below passes a
/// real one.
fn metal_retained_build(
  cache : MetalRetainedCache,
  context : UInt64,
  size : @core.Size,
  commands~ : Array[@core.DrawCommand],
) -> MetalFrameGeometry {
  cache.begin_frame(context)
  build_metal_geometry(
    @render_common.lower_draw_commands(commands),
    @core.SurfaceMetrics::new(
      logical_size=size,
      physical_size=size,
      scale_factor=1.0,
    ),
    MetalFrameContext::{
      cache: @native_text.NativeTextCache::new_with_engine(
        native_noop_text_engine(),
      ),
      atlas: new_metal_glyph_atlas(),
      images: new_metal_image_cache(),
      image_source: @render.HostImageSource::unavailable(),
      context,
      async_images: false,
      retained: cache,
      image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
    },
  )
}

///|
fn metal_retained_frame(geometry : MetalFrameGeometry) -> MetalRetainedFrame {
  MetalRetainedFrame::{
    rebuilt: geometry.retained_layers_rebuilt,
    cached: geometry.retained_layers_cached,
    updated: geometry.retained_layers_updated,
    evicted: geometry.retained_layers_evicted,
    items: geometry.item_count,
    vertices: geometry.vertex_count,
  }
}

///|
test "a boundary seen in the frame that painted it composites from the cache" {
  let size = @core.Size::new(width=16.0, height=16.0)
  let cache = new_metal_retained_cache()
  let commands = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red()),
  )
  let first = metal_retained_frame(
    metal_retained_build(cache, 0UL, size, commands~),
  )
  assert_eq(first.rebuilt, 1)
  assert_eq(first.cached, 0)
  assert_eq(first.items, 2)
  let second = metal_retained_frame(
    metal_retained_build(cache, 0UL, size, commands~),
  )
  assert_eq(second.cached, 1)
  assert_eq(second.rebuilt, 0)
  assert_eq(second.updated, 0)
  // The hit is the child stream *not* being built: one composite instead of a
  // composite plus the group's own fill, and the group's six vertices gone.
  assert_eq(second.items, 1)
  assert_true(
    second.vertices < first.vertices,
    msg="a cache hit must skip the group's own vertices",
  )
}

///|
test "a revision bump rebuilds and names the content as the reason" {
  let size = @core.Size::new(width=16.0, height=16.0)
  let cache = new_metal_retained_cache()
  let child = metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red())
  let frame = metal_rect(0.0, 0.0, 8.0, height=8.0)
  let rebuilt = metal_retained_frame(
    metal_retained_build(
      cache,
      0UL,
      size,
      commands=metal_retained_boundary(3, frame~, child~),
    ),
  )
  assert_eq(rebuilt.rebuilt, 1)
  let changed = metal_retained_frame(
    metal_retained_build(
      cache,
      0UL,
      size,
      commands=metal_retained_boundary(4, frame~, child~),
    ),
  )
  assert_eq(changed.cached, 0)
  assert_eq(changed.rebuilt, 1)
  assert_eq(changed.updated, 1)
  let settled = metal_retained_frame(
    metal_retained_build(
      cache,
      0UL,
      size,
      commands=metal_retained_boundary(4, frame~, child~),
    ),
  )
  assert_eq(settled.cached, 1)
  assert_eq(settled.updated, 0)
}

///|
test "a boundary that moved misses rather than reusing a neighbour" {
  let size = @core.Size::new(width=16.0, height=16.0)
  let cache = new_metal_retained_cache()
  let child = metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red())
  ignore(
    metal_retained_build(
      cache,
      0UL,
      size,
      commands=metal_retained_boundary(
        3,
        frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
        child~,
      ),
    ),
  )
  let moved = metal_retained_frame(
    metal_retained_build(
      cache,
      0UL,
      size,
      commands=metal_retained_boundary(
        3,
        frame=metal_rect(8.0, 0.0, 8.0, height=8.0),
        child~,
      ),
    ),
  )
  assert_eq(moved.cached, 0)
  assert_eq(moved.rebuilt, 1)
  // A move is not a content change: the framework said the group is the same, so
  // the miss is layout, and the row must not read as an update.
  assert_eq(moved.updated, 0)
}

///|
/// The gap, and what each frame is allowed to believe. A hit re-stamps the entry
/// without painting, which is sound because the hitting boundary owns the slot and
/// only a slot owner can paint that target — but it also means an entry survives
/// the frame *after* the boundary disappears, and is dropped by the prune of the
/// frame that wants it back. Either way the return is a rebuild: the hit test
/// itself requires the previous frame, so a texture that anything else could have
/// claimed in the gap is never composited.
test "a boundary that returns after a gap rebuilds rather than reusing a stale texture" {
  let size = @core.Size::new(width=16.0, height=16.0)
  let cache = new_metal_retained_cache()
  let commands = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red()),
  )
  ignore(metal_retained_build(cache, 0UL, size, commands~))
  let carried = metal_retained_frame(
    metal_retained_build(cache, 0UL, size, commands~),
  )
  assert_eq(carried.cached, 1)
  let gap = metal_retained_frame(
    metal_retained_build(cache, 0UL, size, commands=[]),
  )
  assert_eq(gap.evicted, 0)
  assert_eq(gap.cached, 0)
  let back = metal_retained_frame(
    metal_retained_build(cache, 0UL, size, commands~),
  )
  assert_eq(back.evicted, 1)
  assert_eq(back.cached, 0)
  assert_eq(back.rebuilt, 1)
}

///|
test "a different context handle empties the cache" {
  let size = @core.Size::new(width=16.0, height=16.0)
  let cache = new_metal_retained_cache()
  let commands = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red()),
  )
  ignore(metal_retained_build(cache, 0UL, size, commands~))
  ignore(metal_retained_build(cache, 0UL, size, commands~))
  let other = metal_retained_frame(
    metal_retained_build(cache, 7UL, size, commands~),
  )
  assert_eq(other.cached, 0)
  assert_eq(other.rebuilt, 1)
}

///|
/// One context, several frames, and the pixels of each. The cache is only
/// observable across frames on one device, which is what `metal_proof` cannot do:
/// it creates the context, draws once and releases it.
fn metal_retained_run(
  width~ : Int32,
  height~ : Int32,
  frames~ : Array[Array[@core.DrawCommand]],
) -> (Array[MetalRetainedFrame], Array[Bytes]) {
  let context = metal_context_create()
  if context == 0UL {
    abort("metal retained run needs a Metal device")
  }
  let size = @core.Size::new(width=width.to_double(), height=height.to_double())
  let cache = new_metal_retained_cache()
  let atlas = new_metal_glyph_atlas()
  let images = new_metal_image_cache()
  let outcomes : Array[MetalRetainedFrame] = []
  let painted : Array[Bytes] = []
  for commands in frames {
    cache.begin_frame(context)
    let geometry = build_metal_geometry(
      @render_common.lower_draw_commands(commands),
      @core.SurfaceMetrics::new(
        logical_size=size,
        physical_size=size,
        scale_factor=1.0,
      ),
      MetalFrameContext::{
        cache: @native_text.NativeTextCache::new_with_engine(
          native_noop_text_engine(),
        ),
        atlas,
        images,
        image_source: @render.HostImageSource::unavailable(),
        context,
        async_images: false,
        retained: cache,
        image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
      },
    )
    outcomes.push(metal_retained_frame(geometry))
    let vertices = geometry.vertex_bytes()
    let items = geometry.item_bytes()
    let shapes = geometry.shape_bytes()
    let layers = geometry.layer_bytes()
    let output = Bytes::make(width * height * 4, 0)
    let drawn = metal_draw_proof(
        context,
        width,
        height,
        0.0,
        0.0,
        0.0,
        1.0,
        vertices,
        vertices.length(),
        items,
        items.length(),
        shapes,
        shapes.length(),
        layers,
        layers.length(),
        output,
        output.length(),
      ) ==
      1
    if !drawn {
      metal_context_release(context)
      abort("metal retained run could not draw a frame")
    }
    painted.push(output)
  }
  metal_context_release(context)
  (outcomes, painted)
}

///|
/// The pixel half, and the reason the counters above are not enough. The third
/// frame keeps the boundary's key and revision but asks for a green child: a route
/// that re-rendered the stream would paint green, and only reading the texture the
/// second frame painted keeps it red. The fourth frame bumps the revision, which is
/// the framework's statement that the content changed, and the green arrives.
test "a cached boundary composites the pixels the previous frame painted" {
  let red = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red()),
  )
  let green = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(
      metal_rect(0.0, 0.0, 8.0, height=8.0),
      metal_retained_green(),
    ),
  )
  let bumped = metal_retained_boundary(
    4,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(
      metal_rect(0.0, 0.0, 8.0, height=8.0),
      metal_retained_green(),
    ),
  )
  let (outcomes, painted) = metal_retained_run(width=16, height=16, frames=[
    red, red, green, bumped,
  ])
  assert_eq(outcomes.length(), 4)
  assert_true(metal_is_red(metal_proof_pixel(painted[0], 1, 1, 16)))
  assert_eq(outcomes[1].cached, 1)
  assert_true(metal_is_red(metal_proof_pixel(painted[1], 1, 1, 16)))
  assert_eq(outcomes[2].cached, 1)
  assert_true(
    metal_is_red(metal_proof_pixel(painted[2], 1, 1, 16)),
    msg="a hit composites the cached frame, not the current one",
  )
  assert_true(
    metal_is_black(metal_proof_pixel(painted[2], 12, 12, 16)),
    msg="a hit must not draw the group's child into the main pass",
  )
  assert_eq(outcomes[3].updated, 1)
  assert_eq(outcomes[3].cached, 0)
  assert_true(
    metal_is_green(metal_proof_pixel(painted[3], 1, 1, 16)),
    msg="a revision bump must repaint the group",
  )
}

///|
/// The other side of the same claim: a boundary whose device rect changes is not
/// composited from the old texture, so the pixels move with it. A cache that keyed
/// on the slot alone would keep painting at the old place.
test "a boundary whose rect moved repaints rather than compositing an old frame" {
  let small = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 4.0, height=4.0),
    child=metal_fill(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_red()),
  )
  let grown = metal_retained_boundary(
    3,
    frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
    child=metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_red()),
  )
  let (outcomes, painted) = metal_retained_run(width=16, height=16, frames=[
    small, small, grown,
  ])
  assert_eq(outcomes[1].cached, 1)
  assert_eq(outcomes[2].cached, 0)
  assert_eq(outcomes[2].rebuilt, 1)
  assert_true(metal_is_black(metal_proof_pixel(painted[1], 6, 6, 16)))
  assert_true(metal_is_red(metal_proof_pixel(painted[2], 6, 6, 16)))
}
