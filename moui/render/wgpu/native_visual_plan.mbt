///|
fn build_native_draw_plan(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  commands : Array[@render_common.PlanOp],
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
  commands : Array[@render_common.PlanOp],
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
          @render_common.PlanOp::Clear(_) => ()
          @render_common.PlanOp::FillRect(rect, color) =>
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
          @render_common.PlanOp::StrokeRect(rect, color, width) =>
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
          @render_common.PlanOp::FillRoundedRect(rounded, color) =>
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
          @render_common.PlanOp::StrokeRoundedRect(rounded, color, width) =>
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
          @render_common.PlanOp::FillRoundedRectBrush(rounded, brush) =>
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
          @render_common.PlanOp::StrokeRoundedRectBrush(rounded, brush, width) =>
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
          @render_common.PlanOp::DrawShadow(shadow) =>
            append_shadow_item(
              visual_vertices, items, shadow, state, size, scale_factor,
            )
          @render_common.PlanOp::DrawText(run) =>
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
          @render_common.PlanOp::DrawImage(run) =>
            append_image_item(
              image_vertices, items, run, state, size, scale_factor,
            )
          @render_common.PlanOp::PushClip(rect) => {
            state_stack.push(state)
            state = push_clip_state(state, rect)
          }
          @render_common.PlanOp::PopClip =>
            state = pop_native_paint_state(state_stack, state)
          @render_common.PlanOp::PushRoundedClip(rounded) => {
            state_stack.push(state)
            state = push_rounded_clip_state(state, rounded)
          }
          @render_common.PlanOp::PopRoundedClip =>
            state = pop_native_paint_state(state_stack, state)
          @render_common.PlanOp::PushTransform(transform) => {
            state_stack.push(state)
            state = {
              ..state,
              transform: multiply_transform(state.transform, transform),
            }
          }
          @render_common.PlanOp::PopTransform =>
            state = pop_native_paint_state(state_stack, state)
          @render_common.PlanOp::PushOpacity(opacity) => {
            state_stack.push(state)
            state = { ..state, opacity: state.opacity * clamp_opacity(opacity) }
          }
          @render_common.PlanOp::PopOpacity =>
            state = pop_native_paint_state(state_stack, state)
          @render_common.PlanOp::PushLayer(layer) => {
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
            index = child.next_index - 1
          }
          @render_common.PlanOp::PopLayer =>
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
          @render_common.PlanOp::BeginCachedLayer(spec) => {
            let mask = native_layer_mask_for_state(
              state,
              @core.LayerMask::RectMask(spec.frame),
            )
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
                opacity: state.opacity,
                blend_mode: @core.BlendMode::SourceOver,
                mask,
                filter: None,
                scissor: native_layer_scissor(state, size, scale_factor, mask),
              }),
            )
            index = child.next_index - 1
          }
          @render_common.PlanOp::EndCachedLayer(_) =>
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
          @render_common.PlanOp::DrawCachedLayer(_) => ()
          @render_common.PlanOp::PushFilter(filter) => {
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
            index = child.next_index - 1
          }
          @render_common.PlanOp::PopFilter =>
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
          @render_common.PlanOp::DrawShaderEffect(spec) =>
            items.push(
              NativeDrawItem::NativeShaderEffect({
                name: spec.name,
                frame: spec.frame,
                uniforms: spec.uniforms,
                fallback: spec.fallback,
                opacity: state.opacity,
                transform: state.transform,
                scissor: native_scissor_for_state(state, size, scale_factor),
              }),
            )
          @render_common.PlanOp::DrawPath(path) =>
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
