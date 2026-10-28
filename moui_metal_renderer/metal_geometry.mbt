///|
/// CPU-side geometry for one Metal frame: the walk that turns the shared
/// lowering's ops (`lower_draw_commands`, ADR 0019) into the frame's buffers.
/// This file never re-interprets `@core.DrawCommand`; it consumes the neutral
/// plan.
///
/// The match in `build_metal_range` carries no catch-all, so a new `PlanOp`
/// variant is a compile error here rather than a frame that quietly stops
/// drawing it — the same guarantee `moui_wgpu_renderer/native_visual_plan.mbt`
/// relies on. What *is* left counted is degradation: an approximation a host can
/// see in `MetalFrameReport` (blend modes, filters, rebuilt retained layers,
/// fallback-painted shader effects) rather than a silently wrong pixel.
///
/// Two siblings hold the rest of what this walk needs: `metal_geometry_wire.mbt`
/// (the byte layout and the code values MSL interprets) and
/// `metal_geometry_scopes.mbt` (the clip/filter/layer stack and pass slots).
/// Layers and filters are the reason this is one flat buffer set rather than a
/// tree: each open scope claims a pass slot, every item built inside it is
/// tagged with that slot in `owner`, and the host renders slot by slot — so the
/// item stream stays a linear array the encoder can filter without recursion.
priv struct MetalFrameGeometry {
  size : @core.Size
  scale_factor : Double
  vertices : Array[Byte]
  items : Array[Byte]
  shapes : Array[Byte]
  layer_records : Array[MetalLayerRecord]
  mut vertex_count : Int32
  mut item_count : Int32
  mut shape_count : Int32
  mut layer_count : Int32
  mut owner : Int32
  mut approximated_clips : Int32
  mut clipped_away_ops : Int32
  mut text_dropped_glyphs : Int32
  mut text_runs_dropped : Int32
  mut image_ops_unresolved : Int32
  mut image_ops_pending : Int32
  mut image_textures_released : Int32
  mut layers_composited : Int32
  mut blend_modes_unsupported : Int32
  mut blend_modes_approximated : Int32
  mut filter_approximations : Int32
  mut retained_layers_rebuilt : Int32
  mut retained_layers_cached : Int32
  mut retained_layers_updated : Int32
  mut retained_layers_evicted : Int32
  mut shader_effects_fallback_painted : Int32
  // A glyph the coverage atlas could not hold. Not a report field — the signal
  // that makes rebuilding the frame into a cleared atlas worth it.
  mut atlas_overflowed : Bool
}

///|
/// What a frame can reach outside the command stream: the shared neutral-text
/// cache and coverage atlas for glyphs, and the host image source plus decoded
/// texture cache for images. `context` is the FFI context handle, or 0 for the
/// CPU-only frame report, which resolves no images and counts none as refused.
/// `retained` is the cross-frame repaint-boundary cache. The report and a proof
/// frame each get a fresh one, which is why they always rebuild and always say
/// so: a cache hit is a claim about the frame before this one.
priv struct MetalFrameContext {
  cache : @native_text.NativeTextCache
  atlas : MetalGlyphAtlas
  images : MetalImageCache
  image_source : @render.HostImageSource
  context : UInt64
  async_images : Bool
  retained : MetalRetainedCache
  // Resident decoded-texture budget this frame enforces. A field rather than a
  // constant at the call site so tests exercise the automatic path -- release
  // before building -- instead of hand-calling the helper.
  image_budget_bytes : Int32
}

///|
fn MetalFrameGeometry::new(
  size : @core.Size,
  scale_factor : Double,
) -> MetalFrameGeometry {
  MetalFrameGeometry::{
    size,
    scale_factor,
    vertices: [],
    items: [],
    shapes: [],
    layer_records: [],
    vertex_count: 0,
    item_count: 0,
    shape_count: 0,
    layer_count: 0,
    owner: -1,
    approximated_clips: 0,
    clipped_away_ops: 0,
    text_dropped_glyphs: 0,
    text_runs_dropped: 0,
    image_ops_unresolved: 0,
    image_textures_released: 0,
    image_ops_pending: 0,
    layers_composited: 0,
    blend_modes_unsupported: 0,
    blend_modes_approximated: 0,
    filter_approximations: 0,
    retained_layers_rebuilt: 0,
    retained_layers_cached: 0,
    retained_layers_updated: 0,
    retained_layers_evicted: 0,
    shader_effects_fallback_painted: 0,
    atlas_overflowed: false,
  }
}

///|
fn MetalFrameGeometry::vertex_bytes(self : MetalFrameGeometry) -> Bytes {
  Bytes::from_array(self.vertices)
}

///|
fn MetalFrameGeometry::item_bytes(self : MetalFrameGeometry) -> Bytes {
  Bytes::from_array(self.items)
}

///|
fn MetalFrameGeometry::shape_bytes(self : MetalFrameGeometry) -> Bytes {
  Bytes::from_array(self.shapes)
}

///|
/// The offscreen pass table: 7 int32 (device frame, child item range, blend
/// code) followed by 4 float32 (the surface-to-target NDC transform) per record.
/// Slots are ordered parent-after-child, so the host walks them in reverse to
/// render every nested pass before the pass that samples it, and the main pass
/// last.
fn MetalFrameGeometry::layer_bytes(self : MetalFrameGeometry) -> Bytes {
  let out : Array[Byte] = []
  for record in self.layer_records {
    push_metal_i32le(out, record.device_x)
    push_metal_i32le(out, record.device_y)
    push_metal_i32le(out, record.device_width)
    push_metal_i32le(out, record.device_height)
    push_metal_i32le(out, record.child_first)
    push_metal_i32le(out, record.child_count)
    push_metal_i32le(out, record.blend_mode)
    push_metal_f32le(out, record.pass_scale_x)
    push_metal_f32le(out, record.pass_scale_y)
    push_metal_f32le(out, record.pass_offset_x)
    push_metal_f32le(out, record.pass_offset_y)
  }
  Bytes::from_array(out)
}

///|
priv struct MetalPaintState {
  transform : @core.Transform2D
  opacity : Double
  clip : @core.Rect
}

///|
fn new_metal_paint_state(size : @core.Size) -> MetalPaintState {
  MetalPaintState::{
    transform: @core.Transform2D::identity(),
    opacity: 1.0,
    clip: @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
  }
}

///|
/// The discarded-pass tag: items built for a layer this route will not draw are
/// owned by it, so no pass ever visits them.
let metal_owner_discarded : Int32 = -2

///|
fn build_metal_geometry(
  plan : @render_common.DrawPlan,
  metrics : @core.SurfaceMetrics,
  frame : MetalFrameContext,
) -> MetalFrameGeometry {
  let first = build_metal_frame(plan, metrics, frame)
  if !first.atlas_overflowed {
    return first
  }
  // The coverage page set filled partway through the frame, so some glyphs of a
  // longer document were never placed. Clear it and build the frame again: the
  // second pass gets every page and lays out the glyphs the first pass needed
  // least of. Bounded at one retry — if a single frame cannot fit an empty page
  // set, rebuilding again would only repeat the same shortfall,
  // and the surviving `text_dropped_glyphs` is what a host sees.
  // `moui_wgpu_renderer/native_visual_plan.mbt` applies the same policy to the
  // same op, which is the reason it is a retry rather than an eviction scheme.
  clear_metal_glyph_atlas(frame.atlas)
  frame.atlas.resets = frame.atlas.resets + 1
  build_metal_frame(plan, metrics, frame)
}

///|
fn build_metal_frame(
  plan : @render_common.DrawPlan,
  metrics : @core.SurfaceMetrics,
  frame : MetalFrameContext,
) -> MetalFrameGeometry {
  let size = metrics.logical_size
  let geometry = MetalFrameGeometry::new(size, metrics.scale_factor)
  // Reclaim before building: the textures this frame is about to ask for are the
  // ones it will use, so the cold entries from earlier frames are what leave.
  geometry.image_textures_released = metal_image_enforce_budget(
    frame.images,
    frame.context,
    max_bytes=frame.image_budget_bytes,
  )
  ignore(
    build_metal_range(
      geometry,
      frame,
      plan.ops,
      start_index=0,
      stop_at_layer=false,
      stop_at_filter=false,
      initial_state=new_metal_paint_state(size),
    ),
  )
  // Pruned at the start of this frame by `MetalRetainedCache::begin_frame`, so
  // the number travels with the frame that caused it rather than with the cache.
  geometry.retained_layers_evicted = frame.retained.evicted
  geometry
}

///|
/// Walk `ops` from `start_index`, drawing into whichever pass is currently open,
/// and stop at the first unmatched `PopLayer` / `PopFilter` when asked. The
/// nesting contract is the one `moui_wgpu_renderer` implements: a layer claims a
/// pass slot, its child stream is built with the parent transform, the layer
/// clip and opacity 1.0 (so overlapping children group instead of double-blend),
/// and the layer's own opacity is applied once when the slot is composited.
/// Returns the index of the terminator, or `ops.length()` for a full walk.
///
/// The match carries no catch-all, so a new `PlanOp` variant is a compile error
/// here rather than a frame that quietly stops drawing it — the same guarantee
/// `moui_wgpu_renderer/native_visual_plan.mbt` relies on.
fn build_metal_range(
  geometry : MetalFrameGeometry,
  frame : MetalFrameContext,
  ops : Array[@render_common.PlanOp],
  start_index~ : Int32,
  stop_at_layer~ : Bool,
  stop_at_filter~ : Bool,
  stop_at_rounded_clip~ : Bool = false,
  initial_state~ : MetalPaintState,
) -> Int32 {
  let mut state = initial_state
  let transform_stack : Array[@core.Transform2D] = []
  let opacity_stack : Array[Double] = []
  let clip_stack : Array[@core.Rect] = []
  let mut index = start_index
  while index < ops.length() {
    let op = ops[index]
    match op {
      @render_common.Clear(_) => ()
      @render_common.FillRect(rect, color) =>
        append_metal_box(
          geometry,
          rect,
          0.0,
          @core.Brush::solid(color),
          metal_mode_fill,
          0.0,
          state,
        )
      @render_common.StrokeRect(rect, color, width) =>
        append_metal_box(
          geometry,
          rect,
          0.0,
          @core.Brush::solid(color),
          metal_mode_stroke,
          width,
          state,
        )
      @render_common.FillRoundedRect(rounded, color) =>
        append_metal_box(
          geometry,
          rounded.rect,
          rounded.radius,
          @core.Brush::solid(color),
          metal_mode_fill,
          0.0,
          state,
        )
      @render_common.StrokeRoundedRect(rounded, color, width) =>
        append_metal_box(
          geometry,
          rounded.rect,
          rounded.radius,
          @core.Brush::solid(color),
          metal_mode_stroke,
          width,
          state,
        )
      @render_common.FillRoundedRectBrush(rounded, brush) =>
        append_metal_box(
          geometry,
          rounded.rect,
          rounded.radius,
          brush,
          metal_mode_fill,
          0.0,
          state,
        )
      @render_common.StrokeRoundedRectBrush(rounded, brush, width) =>
        append_metal_box(
          geometry,
          rounded.rect,
          rounded.radius,
          brush,
          metal_mode_stroke,
          width,
          state,
        )
      @render_common.DrawShadow(shadow) =>
        append_metal_shadow(geometry, shadow, state)
      @render_common.DrawPath(spec) => append_metal_path(geometry, spec, state)
      @render_common.DrawText(run) =>
        append_metal_text_run(geometry, frame, run, state)
      @render_common.DrawImage(run) =>
        append_metal_image(geometry, frame, run, state)
      @render_common.PushClip(rect) => {
        clip_stack.push(state.clip)
        state = metal_state_with_clip(state, rect)
      }
      @render_common.PopClip => state = metal_state_pop_clip(state, clip_stack)
      @render_common.PushRoundedClip(rounded) =>
        // A rounded clip whose arc the composite can still describe becomes an
        // offscreen pass rounded by the same SDF a `LayerMask::RoundedMask`
        // uses, so the corners get clipped instead of squared off. Where the
        // transform or a parent clip breaks that description the scope stays a
        // bounding-rect scissor and the approximation stays counted.
        match metal_exact_rounded_clip(rounded, state) {
          Some(exact) =>
            index = append_metal_layer(
              geometry,
              frame,
              ops,
              index,
              mask=@core.LayerMask::RoundedMask(exact),
              blend_mode=@core.BlendMode::SourceOver,
              opacity=1.0,
              filter=None,
              rounded_clip_scope=true,
              state,
            )
          None => {
            clip_stack.push(state.clip)
            geometry.approximated_clips = geometry.approximated_clips + 1
            state = metal_state_with_clip(state, rounded.rect)
          }
        }
      @render_common.PopRoundedClip =>
        if stop_at_rounded_clip {
          return index
        } else {
          state = metal_state_pop_clip(state, clip_stack)
        }
      @render_common.PushTransform(transform) => {
        transform_stack.push(state.transform)
        state = MetalPaintState::{
          transform: multiply_metal_transform(state.transform, transform),
          opacity: state.opacity,
          clip: state.clip,
        }
      }
      @render_common.PopTransform =>
        match transform_stack.pop() {
          Some(previous) =>
            state = MetalPaintState::{
              transform: previous,
              opacity: state.opacity,
              clip: state.clip,
            }
          None =>
            state = MetalPaintState::{
              transform: @core.Transform2D::identity(),
              opacity: state.opacity,
              clip: state.clip,
            }
        }
      @render_common.PushOpacity(value) => {
        opacity_stack.push(state.opacity)
        state = MetalPaintState::{
          transform: state.transform,
          opacity: state.opacity * clamp_metal_unit(value),
          clip: state.clip,
        }
      }
      @render_common.PopOpacity =>
        match opacity_stack.pop() {
          Some(previous) =>
            state = MetalPaintState::{
              transform: state.transform,
              opacity: previous,
              clip: state.clip,
            }
          None =>
            state = MetalPaintState::{
              transform: state.transform,
              opacity: 1.0,
              clip: state.clip,
            }
        }
      @render_common.PushLayer(layer) =>
        index = append_metal_layer(
          geometry,
          frame,
          ops,
          index,
          mask=layer.mask,
          blend_mode=layer.blend_mode,
          opacity=layer.opacity,
          filter=None,
          state,
        )
      @render_common.PushFilter(filter) =>
        index = append_metal_layer(
          geometry,
          frame,
          ops,
          index,
          mask=@core.LayerMask::NoMask,
          blend_mode=@core.BlendMode::SourceOver,
          opacity=1.0,
          filter=Some(filter),
          state,
        )
      @render_common.PopLayer => if stop_at_layer { return index }
      @render_common.PopFilter => if stop_at_filter { return index }
      @render_common.BeginRetainedLayer(spec) =>
        // A repaint boundary is a group the framework would rather keep across
        // frames, and `metal_retained.mbt` is what keeps it: the same boundary at
        // the same slot and rect in the frame after the one that painted it
        // composites that texture instead of rebuilding the group. Where there is
        // no such entry -- the first frame, a moved or resized boundary, a revision
        // bump, a different context -- this is the old behaviour and the count
        // shows it: `retained_layers_rebuilt`, with `retained_layers_updated`
        // separating a content change from a layout change and
        // `retained_layers_evicted` the boundaries whose texture was claimed by
        // something else in the gap.
        index = append_metal_layer(
          geometry,
          frame,
          ops,
          index,
          mask=@core.LayerMask::RectMask(spec.frame),
          blend_mode=@core.BlendMode::SourceOver,
          opacity=1.0,
          filter=None,
          retained=Some(spec),
          state,
        )
      @render_common.EndRetainedLayer(_) => if stop_at_layer { return index }
      @render_common.DrawShaderEffect(spec) => {
        // The four builtins `builtin_shader_names()` declares are evaluated per
        // fragment; a name outside that list has no formulation here, so it
        // paints the brush the spec carries as its fallback and shows up in
        // `shader_effects_fallback_painted`, which is how a host tells a fallback
        // frame from an effect frame. The fallback brush also carries the two
        // colours the builtins paint with, so it is never discarded.
        let effect_kind = metal_shader_effect_kind(spec.name)
        if effect_kind == metal_effect_none {
          geometry.shader_effects_fallback_painted = geometry.shader_effects_fallback_painted +
            1
        }
        append_metal_box(
          geometry,
          spec.frame,
          0.0,
          spec.fallback,
          metal_mode_fill,
          0.0,
          state,
          effect_kind~,
          effect_amount=metal_shader_effect_amount(effect_kind, spec.uniforms),
        )
      }
    }
    index = index + 1
  }
  index
}

///|
fn append_metal_box(
  geometry : MetalFrameGeometry,
  rect : @core.Rect,
  radius : Double,
  brush : @core.Brush,
  mode : Double,
  stroke_width : Double,
  state : MetalPaintState,
  blur~ : Double = 0.0,
  effect_kind~ : Double = metal_effect_none,
  effect_amount~ : Double = 0.0,
) -> Unit {
  if rect.size.width <= 0.0 || rect.size.height <= 0.0 || state.opacity <= 0.0 {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    return
  }
  let bounds = metal_transformed_bounds(rect, state.transform)
  if state.clip.intersection(bounds).unwrap_or(empty_metal_rect()).is_empty() {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    return
  }
  let brush_payload = metal_box_brush(
    metal_brush_payload(brush, state.opacity),
    rect.origin,
  )
  let start = geometry.vertex_count
  let corners = [
    (rect.origin.x, rect.origin.y, 0.0, 0.0),
    (rect.origin.x + rect.size.width, rect.origin.y, rect.size.width, 0.0),
    (
      rect.origin.x + rect.size.width,
      rect.origin.y + rect.size.height,
      rect.size.width,
      rect.size.height,
    ),
    (rect.origin.x, rect.origin.y, 0.0, 0.0),
    (
      rect.origin.x + rect.size.width,
      rect.origin.y + rect.size.height,
      rect.size.width,
      rect.size.height,
    ),
    (rect.origin.x, rect.origin.y + rect.size.height, 0.0, rect.size.height),
  ]
  for corner in corners {
    let (corner_x, corner_y, local_x, local_y) = corner
    let point = transform_metal_point(state.transform, corner_x, corner_y)
    push_metal_brush_vertex(
      geometry,
      point.x,
      point.y,
      local_x,
      local_y,
      brush_payload,
    )
  }
  push_metal_draw(
    geometry,
    start,
    state.clip,
    metal_pipeline_visual,
    metal_box_shape(
      rect.size.width,
      rect.size.height,
      radius,
      mode,
      stroke_width~,
      blur_radius=blur,
      effect_kind~,
      effect_amount~,
    ),
  )
}

///|
fn append_metal_shadow(
  geometry : MetalFrameGeometry,
  shadow : @core.ShadowSpec,
  state : MetalPaintState,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  // Three sigmas, because that is where the profile this quad now paints has
  // fallen to 0.13% -- the old two-sigma growth was a margin for a ramp that
  // stopped at one sigma, and clipping a Gaussian at 2 sigma leaves a visible
  // edge to the box.
  let grow = blur * 3.0 + spread
  let rect = @core.Rect::new(
    x=shadow.rect.rect.origin.x + shadow.offset.x - grow,
    y=shadow.rect.rect.origin.y + shadow.offset.y - grow,
    width=shadow.rect.rect.size.width + grow * 2.0,
    height=shadow.rect.rect.size.height + grow * 2.0,
  )
  append_metal_box(
    geometry,
    rect,
    shadow.rect.radius + grow,
    @core.Brush::solid(shadow.color),
    metal_mode_shadow,
    grow,
    state,
    blur~,
  )
}

///|
fn append_metal_path(
  geometry : MetalFrameGeometry,
  spec : @core.PathSpec,
  state : MetalPaintState,
) -> Unit {
  let mesh_vertices = @render_common.tessellate_path(spec).vertices()
  if mesh_vertices.is_empty() || state.opacity <= 0.0 {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    return
  }
  let start = geometry.vertex_count
  for vertex in mesh_vertices {
    // The shared mesh already carries the brush each sub-mesh was filled with,
    // so a path with both a gradient fill and a solid stroke keeps both.
    let components = vertex.components()
    let point = transform_metal_point(
      state.transform,
      components[0],
      components[1],
    )
    push_metal_vertex(
      geometry,
      point.x,
      point.y,
      components[0],
      components[1],
      0.0,
      0.0,
      components[3],
      components[4],
      components[5],
      components[6],
      components[7],
      components[8],
      components[9],
      components[10] * state.opacity,
      components[11],
      components[12],
      components[13],
      components[14] * state.opacity,
      components[2],
    )
  }
  push_metal_draw(
    geometry,
    start,
    state.clip,
    metal_pipeline_visual,
    metal_box_shape(0.0, 0.0, 0.0, metal_mode_path),
  )
}

///|
fn append_metal_text_run(
  geometry : MetalFrameGeometry,
  frame : MetalFrameContext,
  run : @core.TextRun,
  state : MetalPaintState,
) -> Unit {
  let scale_factor = geometry.scale_factor
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  if state.opacity <= 0.0 {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    return
  }
  match frame.cache.layout_run(run, scale_factor) {
    None => geometry.text_runs_dropped = geometry.text_runs_dropped + 1
    Some(layout) => {
      let start_extra = metal_text_align_extra(
        run.align,
        run.frame.size.width,
        layout.size().width,
      )
      let vertical_extra = metal_text_vertical_extra(run.frame, layout)
      let start = geometry.vertex_count
      // One item per atlas page this run touches. Shelf packing only ever moves
      // forward, so a run meets each page in one contiguous stretch and the vertex
      // ranges need no reordering.
      let mut group_start = start
      let mut group_page : Int32 = -1
      let brush_payload = metal_brush_payload(
        @core.Brush::solid(run.color),
        state.opacity,
      )
      for glyph in layout.glyphs() {
        match ensure_metal_glyph(frame.atlas, frame.cache, glyph.key()) {
          Ready(placement) =>
            if placement.width > 0 && placement.height > 0 {
              if group_page >= 0 && placement.page != group_page {
                push_metal_text_group(geometry, group_start, state, group_page)
                group_start = geometry.vertex_count
              }
              group_page = placement.page
              let origin = transform_metal_point(
                state.transform,
                run.frame.origin.x +
                start_extra +
                glyph.x() +
                placement.bearing_x / scale,
                run.frame.origin.y +
                vertical_extra +
                layout.baseline() +
                glyph.y() +
                placement.bearing_y / scale,
              )
              let width = placement.width.to_double() / scale
              let height = placement.height.to_double() / scale
              let atlas = METAL_ATLAS_SIZE.to_double()
              let u0 = placement.x.to_double() / atlas
              let v0 = placement.y.to_double() / atlas
              let u1 = (placement.x + placement.width).to_double() / atlas
              let v1 = (placement.y + placement.height).to_double() / atlas
              let colour = if placement.coverage_only {
                brush_payload
              } else {
                // A colour glyph carries its own pixels; tinting it with the
                // run colour would repaint the artwork.
                MetalBrushPayload::{
                  kind: 0.0,
                  start: brush_payload.start,
                  end: brush_payload.end,
                  color0: @core.Color::rgba(r=1.0, g=1.0, b=1.0).multiply_alpha(
                    state.opacity,
                  ),
                  color1: brush_payload.color1,
                }
              }
              let corners = [
                (0.0, 0.0, u0, v0),
                (width, 0.0, u1, v0),
                (width, height, u1, v1),
                (0.0, 0.0, u0, v0),
                (width, height, u1, v1),
                (0.0, height, u0, v1),
              ]
              for corner in corners {
                let (offset_x, offset_y, u, v) = corner
                let point = transform_metal_point(
                  state.transform,
                  origin.x + offset_x,
                  origin.y + offset_y,
                )
                push_metal_brush_vertex_uv(
                  geometry,
                  point.x,
                  point.y,
                  offset_x,
                  offset_y,
                  u,
                  v,
                  colour,
                )
              }
            }
          Missing =>
            geometry.text_dropped_glyphs = geometry.text_dropped_glyphs + 1
          Full => {
            // The page set ran out, not the engine. That is recoverable — the
            // frame is worth rebuilding into a cleared atlas — so it raises a
            // signal as well as a count.
            geometry.text_dropped_glyphs = geometry.text_dropped_glyphs + 1
            geometry.atlas_overflowed = true
          }
        }
      }
      if group_page >= 0 {
        push_metal_text_group(geometry, group_start, state, group_page)
      } else {
        truncate_metal_vertices(geometry, start)
      }
    }
  }
}

///|
/// Close one page's worth of a glyph run. `texture_key` is the page index, which
/// is the only thing that says which coverage texture this item samples — the
/// vertex layout, the item layout and the shader all stay as they were.
fn push_metal_text_group(
  geometry : MetalFrameGeometry,
  start : Int32,
  state : MetalPaintState,
  page : Int32,
) -> Unit {
  push_metal_draw(
    geometry,
    start,
    state.clip,
    metal_pipeline_text,
    metal_box_shape(0.0, 0.0, 0.0, metal_mode_fill),
    texture_key=page,
  )
}

///|
/// An image run becomes one textured quad. `fit` and `src_rect` resolve through
/// the shared placement helper, so the route cannot invent its own crop rules.
fn append_metal_image(
  geometry : MetalFrameGeometry,
  frame : MetalFrameContext,
  run : @core.ImageRun,
  state : MetalPaintState,
) -> Unit {
  if state.opacity <= 0.0 || run.opacity <= 0.0 {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    return
  }
  let resolved = if frame.async_images {
    ensure_metal_image_async(
      frame.images,
      context=frame.context,
      frame.image_source,
      source=run.source,
    )
  } else {
    ensure_metal_image_sync(
      frame.images,
      context=frame.context,
      frame.image_source,
      source=run.source,
    )
  }
  match resolved {
    None =>
      if frame.async_images {
        geometry.image_ops_pending = geometry.image_ops_pending + 1
      } else {
        geometry.image_ops_unresolved = geometry.image_ops_unresolved + 1
      }
    Some((key, image_size)) =>
      match metal_image_uv(run, image_size) {
        None =>
          geometry.image_ops_unresolved = geometry.image_ops_unresolved + 1
        Some((u0, v0, u1, v1)) => {
          let box = metal_image_frame(run, image_size)
          if state.clip
            .intersection(metal_transformed_bounds(box, state.transform))
            .unwrap_or(empty_metal_rect())
            .is_empty() {
            geometry.clipped_away_ops = geometry.clipped_away_ops + 1
            return
          }
          let opacity = clamp_metal_unit(run.opacity) * state.opacity
          let colour = @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=opacity)
          let start = geometry.vertex_count
          let corners = [
            (box.origin.x, box.origin.y, 0.0, 0.0, u0, v0),
            (
              box.origin.x + box.size.width,
              box.origin.y,
              box.size.width,
              0.0,
              u1,
              v0,
            ),
            (
              box.origin.x + box.size.width,
              box.origin.y + box.size.height,
              box.size.width,
              box.size.height,
              u1,
              v1,
            ),
            (box.origin.x, box.origin.y, 0.0, 0.0, u0, v0),
            (
              box.origin.x + box.size.width,
              box.origin.y + box.size.height,
              box.size.width,
              box.size.height,
              u1,
              v1,
            ),
            (
              box.origin.x,
              box.origin.y + box.size.height,
              0.0,
              box.size.height,
              u0,
              v1,
            ),
          ]
          for corner in corners {
            let (corner_x, corner_y, local_x, local_y, u, v) = corner
            let point = transform_metal_point(
              state.transform,
              corner_x,
              corner_y,
            )
            push_metal_uv_vertex(
              geometry,
              point.x,
              point.y,
              local_x,
              local_y,
              u,
              v,
              colour,
            )
          }
          push_metal_draw(
            geometry,
            start,
            state.clip,
            metal_pipeline_image,
            metal_box_shape(box.size.width, box.size.height, 0.0, 0.0),
            texture_key=key,
          )
        }
      }
  }
}

///|
fn metal_text_align_extra(
  align : @core.TextAlign,
  frame_width : Double,
  text_width : Double,
) -> Double {
  let extra = (frame_width - text_width).max(0.0)
  match align {
    @core.TextStart => 0.0
    TextCenter => extra / 2.0
    TextEnd => extra
  }
}

///|
fn metal_text_vertical_extra(
  frame : @core.Rect,
  layout : @native_text.NativeTextLayout,
) -> Double {
  let extra = frame.size.height - layout.size().height
  if extra > 0.0 {
    extra / 2.0
  } else {
    0.0
  }
}
