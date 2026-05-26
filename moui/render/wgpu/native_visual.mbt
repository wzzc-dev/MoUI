///|
priv enum NativeDrawItem {
  NativeVisual(Int, Int, NativeScissor?)
  NativeText(Int, Int, NativeScissor?)
  NativeImage(Int, Int, NativeScissor?, NativeImageRun)
  NativeLayer(NativeLayerRun)
  NativeShaderEffect(NativeShaderEffectRun)
}

///|
priv struct NativeDrawPlan {
  visual_vertices : Array[VisualVertex]
  text_vertices : Array[TextVertex]
  image_vertices : Array[ImageVertex]
  items : Array[NativeDrawItem]
  atlas_dirty : Bool
}

///|
priv struct NativeScissor {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
priv struct NativePaintState {
  opacity : Double
  transform : @core.Transform2D
  clip : @core.Rect?
  clip_radius : Double
  clip_empty : Bool
}

///|
priv struct NativeImageRun {
  source : String
  frame : @core.Rect
  opacity : Double
  fit : @core.ImageFit
  transform : @core.Transform2D
}

///|
priv struct NativeLayerRun {
  plan : NativeDrawPlan
  opacity : Double
  blend_mode : @core.BlendMode
  mask : NativeLayerMask?
  filter : @core.FilterEffect?
  scissor : NativeScissor?
}

///|
priv struct NativeLayerMask {
  rect : @core.Rect
  radius : Double
  rounded : Bool
}

///|
priv struct NativeShaderEffectRun {
  name : String
  frame : @core.Rect
  uniforms : Array[Double]
  fallback : @core.Brush
  opacity : Double
  scissor : NativeScissor?
}

///|
priv struct VisualVertex {
  x : Double
  y : Double
  local_x : Double
  local_y : Double
  width : Double
  height : Double
  radius : Double
  mode : Double
  stroke_width : Double
  blur_radius : Double
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  r0 : Double
  g0 : Double
  b0 : Double
  a0 : Double
  r1 : Double
  g1 : Double
  b1 : Double
  a1 : Double
}

///|
priv struct AdvancedVertex {
  x : Double
  y : Double
  u : Double
  v : Double
  opacity : Double
  blend_mode : Double
  shader_kind : Double
  effect_amount : Double
  local_x : Double
  local_y : Double
  filter_kind : Double
  filter_amount : Double
  r0 : Double
  g0 : Double
  b0 : Double
  a0 : Double
  r1 : Double
  g1 : Double
  b1 : Double
  a1 : Double
  matrix : Array[Double]
  rect_width : Double
  rect_height : Double
  mask_radius : Double
  mask_kind : Double
}

///|
fn build_native_draw_plan(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  commands : Array[@core.DrawCommand],
  size : @core.Size,
  scale_factor : Double,
) -> NativeDrawPlan {
  build_native_draw_plan_range(
    cache,
    atlas,
    commands,
    start_index=0,
    stop_at_layer=false,
    stop_at_filter=false,
    initial_state=native_paint_state_default(),
    size,
    scale_factor,
  ).plan
}

///|
priv struct NativeDrawPlanRangeResult {
  plan : NativeDrawPlan
  next_index : Int
}

///|
fn build_native_draw_plan_range(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  commands : Array[@core.DrawCommand],
  start_index~ : Int,
  stop_at_layer~ : Bool,
  stop_at_filter~ : Bool,
  initial_state~ : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> NativeDrawPlanRangeResult {
  let was_dirty = atlas.dirty
  for attempt in 0..<2 {
    let visual_vertices : Array[VisualVertex] = []
    let text_vertices : Array[TextVertex] = []
    let image_vertices : Array[ImageVertex] = []
    let items : Array[NativeDrawItem] = []
    let mut state = initial_state
    let state_stack : Array[NativePaintState] = []
    let mut full = false
    let mut index = start_index
    while index < commands.length() {
      let command = commands[index]
      if !full {
        match command {
          @core.DrawCommand::Clear(_) => ()
          @core.DrawCommand::FillRect(rect, color) =>
            append_visual_item(
              visual_vertices,
              items,
              rect,
              radius=0.0,
              brush=@core.Brush::solid(color),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::StrokeRect(rect, color, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rect,
              radius=0.0,
              brush=@core.Brush::solid(color),
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::FillRoundedRect(rounded, color) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush=@core.Brush::solid(color),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush=@core.Brush::solid(color),
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush~,
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush~,
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              state~,
              size~,
              scale_factor~,
            )
          @core.DrawCommand::DrawShadow(shadow) =>
            append_shadow_item(
              visual_vertices, items, shadow, state, size, scale_factor,
            )
          @core.DrawCommand::DrawText(run) =>
            if native_paint_state_visible(state) &&
              native_scissor_visible(
                native_scissor_for_state(state, size, scale_factor),
              ) {
              let start = text_vertices.length()
              let result = build_native_text_run(
                cache, atlas, run, state, size, scale_factor,
              )
              for vertex in result.vertices {
                text_vertices.push(vertex)
              }
              let count = text_vertices.length() - start
              if count > 0 {
                items.push(
                  NativeDrawItem::NativeText(
                    start,
                    count,
                    native_scissor_for_state(state, size, scale_factor),
                  ),
                )
              }
              full = result.atlas_full
            }
          @core.DrawCommand::DrawImage(run) =>
            append_image_item(
              image_vertices, items, run, state, size, scale_factor,
            )
          @core.DrawCommand::PushClip(rect) => {
            state_stack.push(state)
            state = push_clip_state(state, rect)
          }
          @core.DrawCommand::PopClip =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushRoundedClip(rounded) => {
            state_stack.push(state)
            state = push_rounded_clip_state(state, rounded)
          }
          @core.DrawCommand::PopRoundedClip =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushTransform(transform) => {
            state_stack.push(state)
            state = {
              ..state,
              transform: multiply_transform(state.transform, transform),
            }
          }
          @core.DrawCommand::PopTransform =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushOpacity(opacity) => {
            state_stack.push(state)
            state = { ..state, opacity: state.opacity * clamp_opacity(opacity) }
          }
          @core.DrawCommand::PopOpacity =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushLayer(layer) => {
            let mask = native_layer_mask_for_state(state, layer.mask)
            let child = build_native_draw_plan_range(
              cache,
              atlas,
              commands,
              start_index=index + 1,
              stop_at_layer=true,
              stop_at_filter=false,
              initial_state=native_scoped_child_paint_state(state),
              size,
              scale_factor,
            )
            items.push(
              NativeDrawItem::NativeLayer({
                plan: child.plan,
                opacity: state.opacity * layer.opacity,
                blend_mode: layer.blend_mode,
                mask,
                filter: None,
                scissor: native_layer_scissor(state, size, scale_factor, mask),
              }),
            )
            index = child.next_index
          }
          @core.DrawCommand::PopLayer =>
            if stop_at_layer {
              return {
                plan: {
                  visual_vertices,
                  text_vertices,
                  image_vertices,
                  items,
                  atlas_dirty: was_dirty || atlas.dirty,
                },
                next_index: index + 1,
              }
            }
          @core.DrawCommand::PushFilter(filter) => {
            let child = build_native_draw_plan_range(
              cache,
              atlas,
              commands,
              start_index=index + 1,
              stop_at_layer=false,
              stop_at_filter=true,
              initial_state=native_scoped_child_paint_state(state),
              size,
              scale_factor,
            )
            items.push(
              NativeDrawItem::NativeLayer({
                plan: child.plan,
                opacity: state.opacity,
                blend_mode: @core.BlendMode::SourceOver,
                mask: None,
                filter: Some(filter),
                scissor: native_scissor_for_state(state, size, scale_factor),
              }),
            )
            index = child.next_index
          }
          @core.DrawCommand::PopFilter =>
            if stop_at_filter {
              return {
                plan: {
                  visual_vertices,
                  text_vertices,
                  image_vertices,
                  items,
                  atlas_dirty: was_dirty || atlas.dirty,
                },
                next_index: index + 1,
              }
            }
          @core.DrawCommand::DrawShaderEffect(spec) =>
            items.push(
              NativeDrawItem::NativeShaderEffect({
                name: spec.name,
                frame: spec.frame,
                uniforms: spec.uniforms,
                fallback: spec.fallback,
                opacity: state.opacity,
                scissor: native_scissor_for_state(state, size, scale_factor),
              }),
            )
          @core.DrawCommand::DrawPath(path) =>
            append_path_item(
              visual_vertices, items, path, state, size, scale_factor,
            )
        }
      }
      index += 1
    }
    if !full {
      return {
        plan: {
          visual_vertices,
          text_vertices,
          image_vertices,
          items,
          atlas_dirty: was_dirty || atlas.dirty,
        },
        next_index: index,
      }
    }
    atlas.clear()
    if attempt == 1 {
      return {
        plan: {
          visual_vertices: [],
          text_vertices: [],
          image_vertices: [],
          items: [],
          atlas_dirty: true,
        },
        next_index: commands.length(),
      }
    }
  }
  {
    plan: {
      visual_vertices: [],
      text_vertices: [],
      image_vertices: [],
      items: [],
      atlas_dirty: atlas.dirty,
    },
    next_index: commands.length(),
  }
}

///|
fn native_paint_state_default() -> NativePaintState {
  {
    opacity: 1.0,
    transform: @core.Transform2D::identity(),
    clip: None,
    clip_radius: 0.0,
    clip_empty: false,
  }
}

///|
fn native_scoped_child_paint_state(
  state : NativePaintState,
) -> NativePaintState {
  { ..state, opacity: 1.0 }
}

///|
fn pop_native_paint_state(
  stack : Array[NativePaintState],
  fallback : NativePaintState,
) -> NativePaintState {
  match stack.pop() {
    Some(state) => state
    None => fallback
  }
}

///|
fn clamp_opacity(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn native_paint_state_visible(state : NativePaintState) -> Bool {
  !state.clip_empty
}

///|
fn push_clip_state(
  state : NativePaintState,
  rect : @core.Rect,
) -> NativePaintState {
  if state.clip_empty || rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    { ..state, clip: None, clip_empty: true }
  } else {
    match intersect_clip(state.clip, transform_rect(rect, state.transform)) {
      Some(clip) => { ..state, clip: Some(clip), clip_empty: false }
      None => { ..state, clip: None, clip_empty: true }
    }
  }
}

///|
fn push_rounded_clip_state(
  state : NativePaintState,
  rounded : @core.RoundedRect,
) -> NativePaintState {
  if state.clip_empty ||
    rounded.rect.size.width <= 0.0 ||
    rounded.rect.size.height <= 0.0 {
    { ..state, clip: None, clip_radius: 0.0, clip_empty: true }
  } else {
    match
      intersect_clip(state.clip, transform_rect(rounded.rect, state.transform)) {
      Some(clip) => {
        let new_radius = if state.clip_radius > 0.0 {
          state.clip_radius.min(rounded.radius)
        } else {
          rounded.radius
        }
        {
          ..state,
          clip: Some(clip),
          clip_radius: new_radius,
          clip_empty: false,
        }
      }
      None => { ..state, clip: None, clip_radius: 0.0, clip_empty: true }
    }
  }
}

///|
fn multiply_transform(
  a : @core.Transform2D,
  b : @core.Transform2D,
) -> @core.Transform2D {
  {
    a: a.a * b.a + a.c * b.b,
    b: a.b * b.a + a.d * b.b,
    c: a.a * b.c + a.c * b.d,
    d: a.b * b.c + a.d * b.d,
    tx: a.a * b.tx + a.c * b.ty + a.tx,
    ty: a.b * b.tx + a.d * b.ty + a.ty,
  }
}

///|
fn transform_point(
  transform : @core.Transform2D,
  x : Double,
  y : Double,
) -> @core.Point {
  @core.Point::new(
    x=transform.a * x + transform.c * y + transform.tx,
    y=transform.b * x + transform.d * y + transform.ty,
  )
}

///|
fn transform_rect(
  rect : @core.Rect,
  transform : @core.Transform2D,
) -> @core.Rect {
  let p0 = transform_point(transform, rect.origin.x, rect.origin.y)
  let p1 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y,
  )
  let p2 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
  let p3 = transform_point(
    transform,
    rect.origin.x,
    rect.origin.y + rect.size.height,
  )
  let min_x = p0.x.min(p1.x).min(p2.x).min(p3.x)
  let max_x = p0.x.max(p1.x).max(p2.x).max(p3.x)
  let min_y = p0.y.min(p1.y).min(p2.y).min(p3.y)
  let max_y = p0.y.max(p1.y).max(p2.y).max(p3.y)
  @core.Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn intersect_clip(current : @core.Rect?, next : @core.Rect) -> @core.Rect? {
  match current {
    Some(current) => rect_intersection(current, next)
    None => Some(next)
  }
}

///|
fn rect_intersection(a : @core.Rect, b : @core.Rect) -> @core.Rect? {
  let x0 = a.origin.x.max(b.origin.x)
  let y0 = a.origin.y.max(b.origin.y)
  let x1 = (a.origin.x + a.size.width).min(b.origin.x + b.size.width)
  let y1 = (a.origin.y + a.size.height).min(b.origin.y + b.size.height)
  if x1 <= x0 || y1 <= y0 {
    None
  } else {
    Some(@core.Rect::new(x=x0, y=y0, width=x1 - x0, height=y1 - y0))
  }
}

///|
fn native_scissor_for_state(
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor? {
  match state.clip {
    Some(clip) => Some(native_scissor_for_rect(clip, size, scale_factor))
    None => None
  }
}

///|
fn native_layer_scissor(
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  mask : NativeLayerMask?,
) -> NativeScissor? {
  let scissor = native_scissor_for_state(state, size, scale_factor)
  match mask {
    None => scissor
    Some(mask) =>
      native_scissor_for_optional_rect(
        intersect_clip(state.clip, mask.rect),
        size,
        scale_factor,
      )
  }
}

///|
fn native_layer_mask_for_state(
  state : NativePaintState,
  mask : @core.LayerMask,
) -> NativeLayerMask? {
  match mask {
    @core.LayerMask::NoMask => None
    @core.LayerMask::RectMask(rect) =>
      Some({
        rect: transform_rect(rect, state.transform),
        radius: 0.0,
        rounded: false,
      })
    @core.LayerMask::RoundedMask(rounded) =>
      Some({
        rect: transform_rect(rounded.rect, state.transform),
        radius: rounded.radius.max(0.0),
        rounded: true,
      })
  }
}

///|
fn native_scissor_for_optional_rect(
  rect : @core.Rect?,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor? {
  match rect {
    Some(rect) => Some(native_scissor_for_rect(rect, size, scale_factor))
    None => Some({ x: 0, y: 0, width: 0, height: 0 })
  }
}

///|
fn native_scissor_for_rect(
  rect : @core.Rect,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor {
  let scale = native_scissor_scale(scale_factor)
  let x0 = rect.origin.x.max(0.0).min(size.width.max(0.0))
  let y0 = rect.origin.y.max(0.0).min(size.height.max(0.0))
  let x1 = (rect.origin.x + rect.size.width).max(0.0).min(size.width.max(0.0))
  let y1 = (rect.origin.y + rect.size.height).max(0.0).min(size.height.max(0.0))
  {
    x: (x0 * scale).floor().to_int(),
    y: (y0 * scale).floor().to_int(),
    width: ((x1 - x0) * scale).ceil().max(0.0).to_int(),
    height: ((y1 - y0) * scale).ceil().max(0.0).to_int(),
  }
}

///|
fn native_scissor_visible(scissor : NativeScissor?) -> Bool {
  match scissor {
    Some(scissor) => scissor.width > 0 && scissor.height > 0
    None => true
  }
}

///|
fn native_scissor_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn append_visual_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  rect : @core.Rect,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  state~ : NativePaintState,
  size~ : @core.Size,
  scale_factor~ : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  if rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    return
  }
  if mode == visual_mode_stroke && stroke_width <= 0.0 {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
    return
  }
  let start = vertices.length()
  append_visual_quad(
    vertices,
    rect,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  items.push(
    NativeDrawItem::NativeVisual(start, vertices.length() - start, scissor),
  )
}

///|
fn append_shadow_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  shadow : @core.ShadowSpec,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  let grow = blur * 2.0 + spread
  let rect = @core.Rect::new(
    x=shadow.rect.rect.origin.x + shadow.offset.x - grow,
    y=shadow.rect.rect.origin.y + shadow.offset.y - grow,
    width=shadow.rect.rect.size.width + grow * 2.0,
    height=shadow.rect.rect.size.height + grow * 2.0,
  )
  append_visual_item(
    vertices,
    items,
    rect,
    radius=shadow.rect.radius + grow,
    brush=@core.Brush::solid(shadow.color),
    mode=visual_mode_shadow,
    stroke_width=0.0,
    blur_radius=blur,
    state~,
    size~,
    scale_factor~,
  )
}

///|
fn append_image_item(
  vertices : Array[ImageVertex],
  items : Array[NativeDrawItem],
  run : @core.ImageRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  if run.frame.size.width <= 0.0 || run.frame.size.height <= 0.0 {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
    return
  }
  let start = vertices.length()
  items.push(
    NativeDrawItem::NativeImage(start, vertices.length() - start, scissor, {
      source: run.source,
      frame: run.frame,
      opacity: clamp_opacity(run.opacity) * state.opacity,
      fit: run.fit,
      transform: state.transform,
    }),
  )
}

///|
fn append_path_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  path : @core.PathSpec,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
    return
  }
  let mesh = @render.tessellate_path(path)
  let start = vertices.length()
  for vertex in mesh.vertices {
    push_path_visual_vertex(vertices, vertex, state, size)
  }
  let count = vertices.length() - start
  if count > 0 {
    items.push(NativeDrawItem::NativeVisual(start, count, scissor))
  }
}

///|
fn append_visual_quad(
  vertices : Array[VisualVertex],
  rect : @core.Rect,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  state~ : NativePaintState,
  size~ : @core.Size,
) -> Unit {
  let x0 = rect.origin.x
  let y0 = rect.origin.y
  let x1 = rect.origin.x + rect.size.width
  let y1 = rect.origin.y + rect.size.height
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    state~,
    size~,
  )
}

///|
fn push_visual_vertex(
  vertices : Array[VisualVertex],
  rect : @core.Rect,
  x : Double,
  y : Double,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  state~ : NativePaintState,
  size~ : @core.Size,
) -> Unit {
  let gradient = visual_gradient(brush)
  let transformed = transform_point(state.transform, x, y)
  vertices.push({
    x: visual_pixel_x_to_ndc(transformed.x, size.width),
    y: visual_pixel_y_to_ndc(transformed.y, size.height),
    local_x: x - rect.origin.x,
    local_y: y - rect.origin.y,
    width: rect.size.width,
    height: rect.size.height,
    radius: radius.min(rect.size.width.min(rect.size.height) / 2.0).max(0.0),
    mode,
    stroke_width,
    blur_radius,
    start_x: gradient.start.x - rect.origin.x,
    start_y: gradient.start.y - rect.origin.y,
    end_x: gradient.end.x - rect.origin.x,
    end_y: gradient.end.y - rect.origin.y,
    r0: gradient.start_color.r,
    g0: gradient.start_color.g,
    b0: gradient.start_color.b,
    a0: gradient.start_color.a * state.opacity,
    r1: gradient.end_color.r,
    g1: gradient.end_color.g,
    b1: gradient.end_color.b,
    a1: gradient.end_color.a * state.opacity,
  })
}

///|
fn push_path_visual_vertex(
  vertices : Array[VisualVertex],
  vertex : @render.PathVertex,
  state : NativePaintState,
  size : @core.Size,
) -> Unit {
  let transformed = transform_point(state.transform, vertex.x, vertex.y)
  vertices.push({
    x: visual_pixel_x_to_ndc(transformed.x, size.width),
    y: visual_pixel_y_to_ndc(transformed.y, size.height),
    local_x: 0.0,
    local_y: 0.0,
    width: 0.0,
    height: 0.0,
    radius: 0.0,
    mode: visual_mode_path,
    stroke_width: 0.0,
    blur_radius: 0.0,
    start_x: 0.0,
    start_y: 0.0,
    end_x: 0.0,
    end_y: 0.0,
    r0: vertex.r,
    g0: vertex.g,
    b0: vertex.b,
    a0: vertex.a * state.opacity,
    r1: vertex.r,
    g1: vertex.g,
    b1: vertex.b,
    a1: vertex.a * state.opacity,
  })
}

///|
fn visual_gradient(brush : @core.Brush) -> @core.LinearGradientSpec {
  match brush {
    @core.Brush::Solid(color) =>
      @core.LinearGradientSpec::new(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=1.0, y=0.0),
        start_color=color,
        end_color=color,
      )
    @core.Brush::LinearGradient(gradient) => gradient
  }
}

///|
fn visual_vertices_to_bytes(vertices : Array[VisualVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.local_x)
    push_visual_f32le(out, vertex.local_y)
    push_visual_f32le(out, vertex.width)
    push_visual_f32le(out, vertex.height)
    push_visual_f32le(out, vertex.radius)
    push_visual_f32le(out, vertex.mode)
    push_visual_f32le(out, vertex.stroke_width)
    push_visual_f32le(out, vertex.blur_radius)
    push_visual_f32le(out, vertex.start_x)
    push_visual_f32le(out, vertex.start_y)
    push_visual_f32le(out, vertex.end_x)
    push_visual_f32le(out, vertex.end_y)
    push_visual_f32le(out, vertex.r0)
    push_visual_f32le(out, vertex.g0)
    push_visual_f32le(out, vertex.b0)
    push_visual_f32le(out, vertex.a0)
    push_visual_f32le(out, vertex.r1)
    push_visual_f32le(out, vertex.g1)
    push_visual_f32le(out, vertex.b1)
    push_visual_f32le(out, vertex.a1)
  }
  Bytes::from_array(out)
}

///|
fn advanced_vertices_to_bytes(vertices : Array[AdvancedVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.u)
    push_visual_f32le(out, vertex.v)
    push_visual_f32le(out, vertex.opacity)
    push_visual_f32le(out, vertex.blend_mode)
    push_visual_f32le(out, vertex.shader_kind)
    push_visual_f32le(out, vertex.effect_amount)
    push_visual_f32le(out, vertex.local_x)
    push_visual_f32le(out, vertex.local_y)
    push_visual_f32le(out, vertex.filter_kind)
    push_visual_f32le(out, vertex.filter_amount)
    push_visual_f32le(out, vertex.r0)
    push_visual_f32le(out, vertex.g0)
    push_visual_f32le(out, vertex.b0)
    push_visual_f32le(out, vertex.a0)
    push_visual_f32le(out, vertex.r1)
    push_visual_f32le(out, vertex.g1)
    push_visual_f32le(out, vertex.b1)
    push_visual_f32le(out, vertex.a1)
    push_advanced_matrix_f32le(out, vertex.matrix)
    push_visual_f32le(out, vertex.rect_width)
    push_visual_f32le(out, vertex.rect_height)
    push_visual_f32le(out, vertex.mask_radius)
    push_visual_f32le(out, vertex.mask_kind)
  }
  Bytes::from_array(out)
}

///|
fn push_advanced_matrix_f32le(
  out : Array[Byte],
  values : Array[Double],
) -> Unit {
  let identity = native_identity_color_matrix()
  for index in 0..<20 {
    match values.get(index) {
      Some(value) => push_visual_f32le(out, value)
      None => push_visual_f32le(out, identity[index])
    }
  }
}

///|
fn push_visual_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn visual_pixel_x_to_ndc(x : Double, width : Double) -> Double {
  if width <= 0.0 {
    -1.0
  } else {
    x / width * 2.0 - 1.0
  }
}

///|
fn visual_pixel_y_to_ndc(y : Double, height : Double) -> Double {
  if height <= 0.0 {
    1.0
  } else {
    1.0 - y / height * 2.0
  }
}

///|
fn advanced_layer_vertices(
  size : @core.Size,
  layer : NativeLayerRun,
) -> Array[AdvancedVertex] {
  let frame = match layer.mask {
    Some(mask) => mask.rect
    None => @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)
  }
  let mask_radius = match layer.mask {
    Some(mask) => if mask.rounded { mask.radius } else { 0.0 }
    None => 0.0
  }
  let mask_kind = match layer.mask {
    Some(mask) => if mask.rounded { 1.0 } else { 0.0 }
    None => 0.0
  }
  advanced_rect_vertices(
    size,
    frame,
    opacity=layer.opacity,
    blend_mode=layer.blend_mode,
    shader_kind=0.0,
    effect_amount=0.0,
    filter=layer.filter,
    color0=@core.Color::white(),
    color1=@core.Color::white(),
    uv_rect=Some(frame),
    mask_radius~,
    mask_kind~,
  )
}

///|
fn advanced_rect_vertices(
  size : @core.Size,
  rect : @core.Rect,
  opacity~ : Double,
  blend_mode~ : @core.BlendMode,
  shader_kind~ : Double,
  effect_amount~ : Double,
  filter~ : @core.FilterEffect?,
  color0~ : @core.Color,
  color1~ : @core.Color,
  uv_rect? : @core.Rect? = None,
  mask_radius? : Double = 0.0,
  mask_kind? : Double = 0.0,
) -> Array[AdvancedVertex] {
  let vertices : Array[AdvancedVertex] = []
  let x0 = rect.origin.x
  let y0 = rect.origin.y
  let x1 = rect.origin.x + rect.size.width
  let y1 = rect.origin.y + rect.size.height
  let uv0 = advanced_uv_for_point(size, uv_rect, x0, y0, 0.0, 0.0)
  let uv1 = advanced_uv_for_point(size, uv_rect, x0, y1, 0.0, 1.0)
  let uv2 = advanced_uv_for_point(size, uv_rect, x1, y1, 1.0, 1.0)
  let uv3 = advanced_uv_for_point(size, uv_rect, x1, y0, 1.0, 0.0)
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y0,
    uv0.x,
    uv0.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y1,
    uv1.x,
    uv1.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y1,
    uv2.x,
    uv2.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y0,
    uv0.x,
    uv0.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y1,
    uv2.x,
    uv2.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y0,
    uv3.x,
    uv3.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
  )
  vertices
}

///|
fn advanced_uv_for_point(
  size : @core.Size,
  uv_rect : @core.Rect?,
  x : Double,
  y : Double,
  fallback_u : Double,
  fallback_v : Double,
) -> @core.Point {
  match uv_rect {
    Some(_) =>
      @core.Point::new(
        x=x / size.width.max(0.0001),
        y=y / size.height.max(0.0001),
      )
    None => @core.Point::new(x=fallback_u, y=fallback_v)
  }
}

///|
fn push_advanced_vertex(
  vertices : Array[AdvancedVertex],
  size : @core.Size,
  rect : @core.Rect,
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  opacity~ : Double,
  blend_mode~ : @core.BlendMode,
  shader_kind~ : Double,
  effect_amount~ : Double,
  filter~ : @core.FilterEffect?,
  color0~ : @core.Color,
  color1~ : @core.Color,
  mask_radius~ : Double,
  mask_kind~ : Double,
) -> Unit {
  let filter_payload = native_filter_payload(filter)
  vertices.push({
    x: visual_pixel_x_to_ndc(x, size.width),
    y: visual_pixel_y_to_ndc(y, size.height),
    u,
    v,
    opacity: clamp_opacity(opacity),
    blend_mode: native_blend_mode_code(blend_mode),
    shader_kind,
    effect_amount,
    local_x: (x - rect.origin.x) / rect.size.width.max(0.0001),
    local_y: (y - rect.origin.y) / rect.size.height.max(0.0001),
    filter_kind: filter_payload.kind,
    filter_amount: filter_payload.amount,
    r0: color0.r,
    g0: color0.g,
    b0: color0.b,
    a0: color0.a,
    r1: color1.r,
    g1: color1.g,
    b1: color1.b,
    a1: color1.a,
    matrix: filter_payload.matrix,
    rect_width: rect.size.width.max(0.0),
    rect_height: rect.size.height.max(0.0),
    mask_radius: mask_radius.max(0.0),
    mask_kind,
  })
}

///|
priv struct NativeFilterPayload {
  kind : Double
  amount : Double
  matrix : Array[Double]
}

///|
fn native_filter_payload(filter : @core.FilterEffect?) -> NativeFilterPayload {
  match filter {
    Some(@core.FilterEffect::Blur(radius)) =>
      {
        kind: 1.0,
        amount: radius.max(0.0),
        matrix: native_identity_color_matrix(),
      }
    Some(@core.FilterEffect::Saturate(amount)) =>
      { kind: 2.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::Brightness(amount)) =>
      { kind: 3.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::Contrast(amount)) =>
      { kind: 4.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::ColorMatrix(values)) =>
      { kind: 5.0, amount: 1.0, matrix: native_color_matrix(values) }
    None => { kind: 0.0, amount: 0.0, matrix: native_identity_color_matrix() }
  }
}

///|
fn native_identity_color_matrix() -> Array[Double] {
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0,
  ]
}

///|
fn native_color_matrix(values : Array[Double]) -> Array[Double] {
  let matrix = native_identity_color_matrix()
  let count = values.length().min(20)
  for index in 0..<count {
    matrix[index] = values[index]
  }
  matrix
}

///|
fn native_blend_mode_code(mode : @core.BlendMode) -> Double {
  match mode {
    @core.BlendMode::SourceOver => 0.0
    @core.BlendMode::Multiply => 1.0
    @core.BlendMode::Screen => 2.0
    @core.BlendMode::Overlay => 3.0
    @core.BlendMode::Darken => 4.0
    @core.BlendMode::Lighten => 5.0
  }
}

///|
fn native_shader_kind(name : String) -> Double {
  match name {
    "checker" => 1.0
    "solid" => 2.0
    "linear-gradient-debug" => 3.0
    "vignette" => 4.0
    _ => 5.0
  }
}

///|
fn native_shader_effect_amount(effect : NativeShaderEffectRun) -> Double {
  match effect.uniforms.get(0) {
    Some(value) => value
    None => 8.0
  }
}

///|
fn native_shader_effect_colors(
  effect : NativeShaderEffectRun,
) -> (@core.Color, @core.Color) {
  match effect.fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
  }
}

///|
let visual_mode_fill : Double = 0.0

///|
let visual_mode_stroke : Double = 1.0

///|
let visual_mode_shadow : Double = 2.0

///|
let visual_mode_path : Double = 3.0

///|
let visual_vertex_stride : UInt64 = 88UL

///|
let advanced_vertex_stride : UInt64 = 176UL

///|
fn visual_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) local: vec2<f32>,
    #|  @location(1) size_radius_mode_stroke: vec4<f32>,
    #|  @location(2) blur_start: vec4<f32>,
    #|  @location(3) end: vec2<f32>,
    #|  @location(4) color0: vec4<f32>,
    #|  @location(5) color1: vec4<f32>,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) local: vec2<f32>,
    #|  @location(2) size_radius_mode_stroke: vec4<f32>,
    #|  @location(3) blur_start: vec4<f32>,
    #|  @location(4) end: vec2<f32>,
    #|  @location(5) color0: vec4<f32>,
    #|  @location(6) color1: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.local = local;
    #|  out.size_radius_mode_stroke = size_radius_mode_stroke;
    #|  out.blur_start = blur_start;
    #|  out.end = end;
    #|  out.color0 = color0;
    #|  out.color1 = color1;
    #|  return out;
    #|}
    #|
    #|fn rounded_box_sdf(p: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    #|  let r = min(radius, min(half_size.x, half_size.y));
    #|  let q = abs(p) - (half_size - vec2<f32>(r, r));
    #|  return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    #|}
    #|
    #|fn gradient_color(local: vec2<f32>, start: vec2<f32>, end: vec2<f32>, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let axis = end - start;
    #|  let denom = max(dot(axis, axis), 0.0001);
    #|  let t = clamp(dot(local - start, axis) / denom, 0.0, 1.0);
    #|  return mix(c0, c1, t);
    #|}
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let width = in.size_radius_mode_stroke.x;
    #|  let height = in.size_radius_mode_stroke.y;
    #|  let radius = in.size_radius_mode_stroke.z;
    #|  let mode = in.size_radius_mode_stroke.w;
    #|  let stroke_width = in.blur_start.x;
    #|  let blur_radius = in.blur_start.y;
    #|  let start = in.blur_start.zw;
    #|  let end = in.end;
    #|  if mode > 2.5 {
    #|    return in.color0;
    #|  }
    #|  let center = vec2<f32>(width * 0.5, height * 0.5);
    #|  let half_size = center;
    #|  let dist = rounded_box_sdf(in.local - center, half_size, radius);
    #|  var alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    #|  if mode > 1.5 {
    #|    let spread = max(blur_radius, 1.0);
    #|    alpha = 1.0 - smoothstep(-spread, spread, dist);
    #|    alpha = alpha * alpha * in.color0.a;
    #|    return vec4<f32>(in.color0.rgb, alpha);
    #|  }
    #|  if mode > 0.5 {
    #|    let inner_radius = max(radius - stroke_width, 0.0);
    #|    let inner_half = max(half_size - vec2<f32>(stroke_width, stroke_width), vec2<f32>(0.0, 0.0));
    #|    let inner_dist = rounded_box_sdf(in.local - center, inner_half, inner_radius);
    #|    let inner_alpha = 1.0 - smoothstep(-0.5, 0.5, inner_dist);
    #|    alpha = max(alpha - inner_alpha, 0.0);
    #|  }
    #|  let color = gradient_color(in.local, start, end, in.color0, in.color1);
    #|  return vec4<f32>(color.rgb, color.a * alpha);
    #|}
    #|
  shader
}

///|
fn advanced_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) meta0: vec4<f32>,
    #|  @location(2) meta1: vec4<f32>,
    #|  @location(3) color0: vec4<f32>,
    #|  @location(4) color1: vec4<f32>,
    #|  @location(5) matrix0: vec4<f32>,
    #|  @location(6) matrix1: vec4<f32>,
    #|  @location(7) matrix2: vec4<f32>,
    #|  @location(8) matrix3: vec4<f32>,
    #|  @location(9) matrix4: vec4<f32>,
    #|  @location(10) rect_mask: vec4<f32>,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) meta0: vec4<f32>,
    #|  @location(3) meta1: vec4<f32>,
    #|  @location(4) color0: vec4<f32>,
    #|  @location(5) color1: vec4<f32>,
    #|  @location(6) matrix0: vec4<f32>,
    #|  @location(7) matrix1: vec4<f32>,
    #|  @location(8) matrix2: vec4<f32>,
    #|  @location(9) matrix3: vec4<f32>,
    #|  @location(10) matrix4: vec4<f32>,
    #|  @location(11) rect_mask: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.meta0 = meta0;
    #|  out.meta1 = meta1;
    #|  out.color0 = color0;
    #|  out.color1 = color1;
    #|  out.matrix0 = matrix0;
    #|  out.matrix1 = matrix1;
    #|  out.matrix2 = matrix2;
    #|  out.matrix3 = matrix3;
    #|  out.matrix4 = matrix4;
    #|  out.rect_mask = rect_mask;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var layer_sampler : sampler;
    #|@group(0) @binding(1) var layer_texture : texture_2d<f32>;
    #|@group(0) @binding(2) var backdrop_texture : texture_2d<f32>;
    #|
    #|fn checker(local: vec2<f32>, amount: f32, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let scale = max(amount, 8.0);
    #|  let cell = floor(local * scale);
    #|  let alt = (i32(cell.x) + i32(cell.y)) & 1;
    #|  if alt == 0 {
    #|    return c0;
    #|  }
    #|  return c1;
    #|}
    #|
    #|fn vignette(local: vec2<f32>, amount: f32, c0: vec4<f32>) -> vec4<f32> {
    #|  let centered = local * 2.0 - vec2<f32>(1.0, 1.0);
    #|  let fade = 1.0 - smoothstep(0.25, max(amount, 0.8), length(centered));
    #|  return vec4<f32>(c0.rgb * fade, c0.a);
    #|}
    #|
    #|fn blur_sample(uv: vec2<f32>, amount: f32) -> vec4<f32> {
    #|  let dims = vec2<f32>(textureDimensions(layer_texture));
    #|  let step = vec2<f32>(1.0, 1.0) / max(dims, vec2<f32>(1.0, 1.0));
    #|  let radius = max(amount, 1.0);
    #|  var color = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0, -1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 0.0, -1.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0, -1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0,  0.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv) * 0.25;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0,  0.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>(-1.0,  1.0)) * 0.0625;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 0.0,  1.0)) * 0.125;
    #|  color += textureSample(layer_texture, layer_sampler, uv + step * radius * vec2<f32>( 1.0,  1.0)) * 0.0625;
    #|  return color;
    #|}
    #|
    #|fn rounded_box_sdf_advanced(p: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    #|  let r = min(radius, min(half_size.x, half_size.y));
    #|  let q = abs(p) - (half_size - vec2<f32>(r, r));
    #|  return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    #|}
    #|
    #|fn apply_filter(color: vec4<f32>, kind: i32, amount: f32, m0: vec4<f32>, m1: vec4<f32>, m2: vec4<f32>, m3: vec4<f32>, m4: vec4<f32>) -> vec4<f32> {
    #|  if kind == 2 {
    #|    let luma = dot(color.rgb, vec3<f32>(0.2126, 0.7152, 0.0722));
    #|    return vec4<f32>(mix(vec3<f32>(luma, luma, luma), color.rgb, amount), color.a);
    #|  }
    #|  if kind == 3 {
    #|    return vec4<f32>(color.rgb * amount, color.a);
    #|  }
    #|  if kind == 4 {
    #|    return vec4<f32>((color.rgb - vec3<f32>(0.5, 0.5, 0.5)) * amount + vec3<f32>(0.5, 0.5, 0.5), color.a);
    #|  }
    #|  if kind == 5 {
    #|    let v = vec4<f32>(color.rgb, color.a);
    #|    return vec4<f32>(
    #|      dot(v, m0) + m4.x,
    #|      dot(v, m1) + m4.y,
    #|      dot(v, m2) + m4.z,
    #|      dot(v, m3) + m4.w,
    #|    );
    #|  }
    #|  return color;
    #|}
    #|
    #|fn overlay_channel(base: f32, source: f32) -> f32 {
    #|  if base <= 0.5 {
    #|    return 2.0 * base * source;
    #|  }
    #|  return 1.0 - 2.0 * (1.0 - base) * (1.0 - source);
    #|}
    #|
    #|fn overlay_rgb(base: vec3<f32>, source: vec3<f32>) -> vec3<f32> {
    #|  return vec3<f32>(
    #|    overlay_channel(base.r, source.r),
    #|    overlay_channel(base.g, source.g),
    #|    overlay_channel(base.b, source.b),
    #|  );
    #|}
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let opacity = in.meta0.x;
    #|  let shader_kind = i32(in.meta0.z + 0.5);
    #|  let effect_amount = in.meta0.w;
    #|  let filter_kind = i32(in.meta1.z + 0.5);
    #|  let filter_amount = in.meta1.w;
    #|  var sample = textureSample(layer_texture, layer_sampler, in.uv);
    #|  if shader_kind == 1 {
    #|    sample = checker(in.meta1.xy, effect_amount, in.color0, in.color1);
    #|  } else if shader_kind == 2 {
    #|    sample = in.color0;
    #|  } else if shader_kind == 3 {
    #|    sample = mix(in.color0, in.color1, clamp(in.meta1.x, 0.0, 1.0));
    #|  } else if shader_kind == 4 {
    #|    sample = vignette(in.meta1.xy, effect_amount, in.color0);
    #|  } else if shader_kind == 5 {
    #|    sample = in.color0;
    #|  }
    #|  if filter_kind == 1 {
    #|    sample = blur_sample(in.uv, filter_amount);
    #|  }
    #|  sample = apply_filter(sample, filter_kind, filter_amount, in.matrix0, in.matrix1, in.matrix2, in.matrix3, in.matrix4);
    #|  var mask_alpha = 1.0;
    #|  if in.rect_mask.w > 0.5 {
    #|    let mask_size = in.rect_mask.xy;
    #|    let local = in.meta1.xy * mask_size;
    #|    let dist = rounded_box_sdf_advanced(local - mask_size * 0.5, mask_size * 0.5, in.rect_mask.z);
    #|    mask_alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    #|  }
    #|  let blend_mode = i32(in.meta0.y + 0.5);
    #|  let source_alpha = clamp(sample.a * opacity * mask_alpha, 0.0, 1.0);
    #|  var source_rgb = sample.rgb;
    #|  if shader_kind == 0 && sample.a > 0.0001 {
    #|    source_rgb = clamp(sample.rgb / sample.a, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));
    #|  }
    #|  if blend_mode == 1 {
    #|    return vec4<f32>(source_rgb * source_alpha + vec3<f32>(1.0 - source_alpha), source_alpha);
    #|  }
    #|  if blend_mode == 2 {
    #|    return vec4<f32>(source_rgb * source_alpha, source_alpha);
    #|  }
    #|  if blend_mode == 3 {
    #|    let backdrop = textureSample(backdrop_texture, layer_sampler, in.uv);
    #|    let blended = overlay_rgb(backdrop.rgb, source_rgb);
    #|    let out_rgb = mix(backdrop.rgb, blended, source_alpha);
    #|    let out_alpha = source_alpha + backdrop.a * (1.0 - source_alpha);
    #|    return vec4<f32>(out_rgb, out_alpha);
    #|  }
    #|  if blend_mode == 4 {
    #|    return vec4<f32>(source_rgb * source_alpha + vec3<f32>(1.0 - source_alpha), source_alpha);
    #|  }
    #|  if blend_mode == 5 {
    #|    return vec4<f32>(source_rgb * source_alpha, source_alpha);
    #|  }
    #|  return vec4<f32>(source_rgb, source_alpha);
    #|}
    #|
  shader
}
