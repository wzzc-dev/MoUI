///|
/// Scope machinery for a Metal frame: what a clip, a filter and a layer each
/// change about the state, and how a layer becomes a pass.
///
/// A `PushLayer`/`PushFilter` claims a pass slot; every item built while that
/// slot is open is tagged with it in the item stream's `owner` word, and the
/// host renders slot by slot (deepest first) into a per-slot offscreen target
/// before compositing it back. The clip stack lives here as well, because a
/// layer's rect is its mask clipped to the parent clip — the one piece of state
/// that cannot be derived from the item stream alone.

///|
/// The rect a layer covers: its mask clipped to the parent clip, or the parent
/// clip when the layer carries no mask.
fn metal_layer_clip(
  state : MetalPaintState,
  mask : @core.LayerMask,
) -> @core.Rect {
  let mask_rect = match mask {
    NoMask => state.clip
    RectMask(rect) => rect
    RoundedMask(rounded) => rounded.rect
  }
  state.clip.intersection(mask_rect).unwrap_or(empty_metal_rect())
}

///|
fn metal_layer_mask_kind(mask : @core.LayerMask) -> (Double, Double) {
  match mask {
    NoMask | RectMask(_) => (metal_mask_none, 0.0)
    RoundedMask(rounded) => (metal_mask_rounded, rounded.radius.max(0.0))
  }
}

///|
/// One offscreen pass record: the device rect the pass owns, the child item
/// range inside the item stream, the blend code, and the surface-to-target NDC
/// transform. The corners come from the target's own pixel bounds, not from the
/// logical clip, so content texels and destination texels line up exactly. A
/// cached boundary pushes this with `child_count = 0`, which is how the host
/// knows to leave the target it already holds alone.
fn metal_layer_record(
  geometry : MetalFrameGeometry,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  child_first : Int32,
  blend : Int32,
) -> MetalLayerRecord {
  let scale = if geometry.scale_factor > 0.0 {
    geometry.scale_factor
  } else {
    1.0
  }
  MetalLayerRecord::{
    device_x: x,
    device_y: y,
    device_width: width,
    device_height: height,
    child_first,
    child_count: 0,
    blend_mode: blend,
    pass_scale_x: geometry.size.width * scale / width.to_double(),
    pass_scale_y: geometry.size.height * scale / height.to_double(),
    pass_offset_x: (geometry.size.width * scale - 2.0 * x.to_double()) /
    width.to_double() -
    1.0,
    pass_offset_y: 1.0 -
    (geometry.size.height * scale - 2.0 * y.to_double()) / height.to_double(),
  }
}

///|
/// Advance past the child stream of a `BeginRetainedLayer` scope without drawing
/// it, which is what a cache hit means. Only the four group kinds nest — layer,
/// filter, rounded clip, retained — so only they change the depth: a clip,
/// transform or opacity pair inside the group is balanced before the group's own
/// terminator, and an unbalanced one is refused by the shared planner that built
/// this stream.
fn skip_metal_retained_scope(
  ops : Array[@render_common.PlanOp],
  index : Int32,
) -> Int32 {
  let mut depth = 1
  let mut cursor = index + 1
  while cursor < ops.length() && depth > 0 {
    let mut opened = false
    let mut closed = false
    match ops[cursor] {
      @render_common.BeginRetainedLayer(_)
      | PushLayer(_)
      | PushFilter(_)
      | PushRoundedClip(_) => opened = true
      @render_common.EndRetainedLayer(_)
      | PopLayer
      | PopFilter
      | PopRoundedClip => closed = true
      _ => ()
    }
    if opened {
      depth = depth + 1
    } else if closed {
      depth = depth - 1
    }
    cursor = cursor + 1
  }
  cursor
}

///|
/// Open one offscreen pass, build the layer's child stream into it, then emit
/// the single composite draw the enclosing pass performs.
///
/// `retained` carries the identity of a `BeginRetainedLayer` group. Only that op
/// supplies it, and only it can be served from the cross-frame cache: a hit
/// pushes the pass record with no children, skips the child stream, and composites
/// the texture the previous frame painted into this slot.
fn append_metal_layer(
  geometry : MetalFrameGeometry,
  frame : MetalFrameContext,
  ops : Array[@render_common.PlanOp],
  index : Int32,
  mask~ : @core.LayerMask,
  blend_mode~ : @core.BlendMode,
  opacity~ : Double,
  filter~ : @core.FilterEffect?,
  rounded_clip_scope~ : Bool = false,
  retained~ : @core.RetainedLayerSpec? = None,
  state : MetalPaintState,
) -> Int32 {
  let scale = if geometry.scale_factor > 0.0 {
    geometry.scale_factor
  } else {
    1.0
  }
  let clip = metal_layer_clip(state, mask)
  let (x, y, width, height) = metal_scissor(clip, geometry.size, scale)
  let opacity = clamp_metal_unit(opacity) * state.opacity
  let blend = metal_blend_code(blend_mode)
  // A blend mode Metal cannot express, an empty frame or a fully transparent
  // group paints nothing: the child stream is still consumed (so the matching
  // pop terminates the walk), but it is owned by the discarded pass and never
  // drawn. Guessing a look is the alternative this route refuses.
  let discarded = width <= 0 ||
    height <= 0 ||
    opacity <= 0.0 ||
    blend < 0 ||
    geometry.owner == metal_owner_discarded
  // A blur is two one-dimensional convolutions, and the second stage needs a
  // target of its own, so the horizontal pass claims its slot *before* the group
  // does: the host renders slots in descending order, and the chain has to be the
  // group, then the horizontal result, then the enclosing composite that reads it.
  let is_blur = match filter {
    Some(@core.FilterEffect::Blur(_)) => true
    _ => false
  }
  let has_blur_pass = is_blur && !discarded
  let blur_slot = if has_blur_pass {
    let claimed = geometry.layer_count
    geometry.layer_records.push(
      metal_layer_record(
        geometry,
        x,
        y,
        width,
        height,
        geometry.item_count,
        metal_blend_source_over,
      ),
    )
    geometry.layer_count = geometry.layer_count + 1
    claimed
  } else {
    -1
  }
  let previous_owner = geometry.owner
  geometry.owner = if discarded {
    metal_owner_discarded
  } else {
    geometry.layer_count
  }
  let child_first = geometry.item_count
  let slot = geometry.owner
  // A `PushFilter` scope is closed by `PopFilter` and a `PushLayer` scope by
  // `PopLayer`; the walk that opens one has to stop at its own pop, or a filter
  // group nested in a layer group would swallow the layer's pop.
  // A rounded clip is the third scope kind and stops at neither of those: its
  // children keep their own layer and filter pairs, and only its own
  // `PopRoundedClip` closes it.
  let is_filter = filter is Some(_)
  let is_layer = filter is None && !rounded_clip_scope
  let child_state = MetalPaintState::{
    transform: state.transform,
    opacity: 1.0,
    clip,
  }
  let cache_hit = match retained {
    Some(spec) =>
      !discarded &&
      metal_retained_hit(
        frame.retained,
        spec.key,
        spec.content_revision,
        slot,
        x,
        y,
        width,
        height,
      )
    None => false
  }
  let mut empty_group = false
  let next = match retained {
    Some(spec) if cache_hit => {
      // The group is not rebuilt: this frame composites the texture the previous
      // one painted into this slot, so the pass record carries no children and
      // the child stream is consumed without being drawn.
      geometry.retained_layers_cached = geometry.retained_layers_cached + 1
      geometry.layer_records.push(
        metal_layer_record(geometry, x, y, width, height, child_first, blend),
      )
      geometry.layer_count = geometry.layer_count + 1
      // Re-stamp the entry. It did not paint this frame, but it owns the slot, and
      // a slot owner is the only thing that can paint that target — so the texture
      // is still the group's, and the next frame may read it too. Without this, a
      // boundary that hits would age out on its second hit and the cache would only
      // ever save one frame in two.
      ignore(
        metal_retained_store(
          frame.retained,
          spec.key,
          spec.content_revision,
          slot,
          x,
          y,
          width,
          height,
        ),
      )
      skip_metal_retained_scope(ops, index)
    }
    _ => {
      match retained {
        Some(_) =>
          geometry.retained_layers_rebuilt = geometry.retained_layers_rebuilt +
            1
        None => ()
      }
      if discarded {
        build_metal_range(
          geometry,
          frame,
          ops,
          start_index=index + 1,
          stop_at_layer=is_layer,
          stop_at_filter=is_filter,
          stop_at_rounded_clip=rounded_clip_scope,
          initial_state=child_state,
        )
      } else {
        let record = metal_layer_record(
          geometry, x, y, width, height, child_first, blend,
        )
        geometry.layer_records.push(record)
        geometry.layer_count = geometry.layer_count + 1
        let child_next = build_metal_range(
          geometry,
          frame,
          ops,
          start_index=index + 1,
          stop_at_layer=is_layer,
          stop_at_filter=is_filter,
          stop_at_rounded_clip=rounded_clip_scope,
          initial_state=child_state,
        )
        let produced = geometry.item_count - child_first
        if produced == 0 {
          // The group holds nothing to blend or filter. Releasing the slot is not a
          // refusal: an empty group paints nothing on any route, so there is no
          // approximation to report either.
          empty_group = true
          ignore(geometry.layer_records.pop())
          geometry.layer_count = geometry.layer_count - 1
          if has_blur_pass {
            ignore(geometry.layer_records.pop())
            geometry.layer_count = geometry.layer_count - 1
          }
        } else {
          geometry.layer_records[slot] = MetalLayerRecord::{
            ..record,
            child_count: produced,
          }
          match retained {
            Some(spec) =>
              if metal_retained_store(
                  frame.retained,
                  spec.key,
                  spec.content_revision,
                  slot,
                  x,
                  y,
                  width,
                  height,
                ) {
                geometry.retained_layers_updated = geometry.retained_layers_updated +
                  1
              }
            None => ()
          }
          if has_blur_pass {
            // One counted approximation per blurred group, exactly as when the
            // blur was a single tap: two passes are this route's blur, not a
            // blur and a half.
            geometry.filter_approximations = geometry.filter_approximations + 1
            let owner_before = geometry.owner
            geometry.owner = blur_slot
            // The range is the stage item itself, taken here: the slot was
            // claimed before the group's children existed, so the placeholder
            // `child_first` would otherwise span the whole group and redraw it
            // into the intermediate.
            let stage_first = geometry.item_count
            // The mask and the group's opacity belong to the final composite;
            // applying either here would round or dim the intermediate twice.
            push_metal_composite(
              geometry,
              slot,
              @core.LayerMask::NoMask,
              1.0,
              filter,
              x,
              y,
              width,
              height,
              scale,
              blur_stage=1,
            )
            geometry.owner = owner_before
            let blur_record = geometry.layer_records[blur_slot]
            geometry.layer_records[blur_slot] = MetalLayerRecord::{
              ..blur_record,
              child_first: stage_first,
              child_count: geometry.item_count - stage_first,
            }
          }
        }
        child_next
      }
    }
  }
  geometry.owner = previous_owner
  if blend < 0 {
    geometry.blend_modes_unsupported = geometry.blend_modes_unsupported + 1
  } else if discarded {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
  } else if !empty_group {
    // The five blend modes Metal can reach are fixed-function factors that are
    // exact where the destination is opaque. This stage has no backdrop read, so
    // where the destination is a freshly cleared layer target -- or a translucent
    // window clear -- an empty texel blends toward black instead of falling back
    // to source-over the way a backdrop-sampling renderer does. Counted, not
    // hidden: `capabilities.mbt` reports `BlendMode` as partial for this reason.
    if blend != metal_blend_source_over {
      geometry.blend_modes_approximated = geometry.blend_modes_approximated + 1
    }
    push_metal_composite(
      geometry,
      if has_blur_pass {
        blur_slot
      } else {
        slot
      },
      mask,
      opacity,
      filter,
      x,
      y,
      width,
      height,
      scale,
      blur_stage=if has_blur_pass { 2 } else { 0 },
    )
  }
  next
}

///|
/// One full-bleed quad over the layer's device rectangle, sampling the pass it
/// just rendered. `blur_stage` renumbers a blur payload as one axis of the
/// separable pair -- 1 is the horizontal pass into the intermediate target, 2 is
/// the vertical read of it -- and 0 means this draw is not a blur stage. The
/// corners come from the target's own pixel bounds, not from
/// the logical clip, so content texels and destination texels line up exactly.
fn push_metal_composite(
  geometry : MetalFrameGeometry,
  slot : Int32,
  mask : @core.LayerMask,
  opacity : Double,
  filter : @core.FilterEffect?,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  scale : Double,
  blur_stage~ : Int32 = 0,
) -> Unit {
  let (mask_kind, mask_radius) = metal_layer_mask_kind(mask)
  let filter_payload = match filter {
    None => metal_unknown_filter_payload()
    Some(effect) => metal_filter_payload(effect)
  }
  let blurred = filter_payload.kind == metal_filter_blur
  let filter_kind = if blurred && blur_stage == 1 {
    metal_filter_blur_x
  } else if blurred && blur_stage == 2 {
    metal_filter_blur_y
  } else {
    filter_payload.kind
  }
  let left = x.to_double() / scale
  let top = y.to_double() / scale
  let right = (x + width).to_double() / scale
  let bottom = (y + height).to_double() / scale
  let start = geometry.vertex_count
  let corners = [
    (left, top, 0.0, 0.0),
    (right, top, 1.0, 0.0),
    (right, bottom, 1.0, 1.0),
    (left, top, 0.0, 0.0),
    (right, bottom, 1.0, 1.0),
    (left, bottom, 0.0, 1.0),
  ]
  for corner in corners {
    let (corner_x, corner_y, u, v) = corner
    push_metal_uv_vertex(
      geometry,
      corner_x,
      corner_y,
      corner_x - left,
      corner_y - top,
      u,
      v,
      @core.Color::rgba(r=1.0, g=1.0, b=1.0),
    )
  }
  let shape = MetalShapePayload::{
    width: width.to_double() / scale,
    height: height.to_double() / scale,
    radius: mask_radius,
    mode: metal_mode_composite,
    stroke_width: 0.0,
    blur_radius: 0.0,
    effect_kind: metal_effect_none,
    effect_amount: 0.0,
    layer_opacity: opacity,
    mask_kind,
    mask_radius,
    filter_kind,
    filter_amount: filter_payload.amount,
    // The filter radius is a logical length and uv runs 0..1 across the target,
    // so one logical pixel is `scale / device_width` uv units.
    texel_x: scale / width.to_double(),
    texel_y: scale / height.to_double(),
    matrix: filter_payload.matrix,
  }
  push_metal_draw(
    geometry,
    start,
    @core.Rect::new(
      x=left,
      y=top,
      width=width.to_double() / scale,
      height=height.to_double() / scale,
    ),
    metal_pipeline_composite,
    shape,
    texture_key=slot,
  )
  geometry.layers_composited = geometry.layers_composited + 1
}

///|
/// The rounded clip this route can express as one rounded box, in surface
/// coordinates, or `None` when it cannot. Two things have to hold: the transform
/// must stay axis-aligned with a uniform scale (a rotation or a non-uniform
/// scale turns the corner arc into an ellipse, which the composite SDF cannot
/// describe), and neither the parent clip nor the surface may shrink the rect —
/// because the composite rounds the box it is handed, so a shrunk frame would
/// round the wrong corners. `None` is what keeps the bounding-rect scissor and
/// its `approximated_clips` record.
fn metal_exact_rounded_clip(
  rounded : @core.RoundedRect,
  state : MetalPaintState,
) -> @core.RoundedRect? {
  let t = state.transform
  let axis_aligned = t.a == t.d &&
    t.a > 0.0 &&
    t.b == 0.0 &&
    t.c == 0.0 &&
    rounded.radius > 0.0
  if !axis_aligned {
    None
  } else {
    let rect = metal_transformed_bounds(rounded.rect, t)
    match state.clip.intersection(rect) {
      Some(clipped) =>
        if clipped == rect {
          Some(@core.RoundedRect::new(rect~, radius=rounded.radius * t.a))
        } else {
          None
        }
      None => None
    }
  }
}

///|
/// Push one clip rect. The rect arrives in the coordinate space the current
/// transform paints in, so the scissor has to be the transformed bounds — the
/// same rule `moui_wgpu_renderer/native_visual_state.mbt` pushes with
/// `transform_rect`, and the reason a layer mask is *not* run through here: a
/// mask names a frame on the surface, not a shape in the caller's space.
fn metal_state_with_clip(
  state : MetalPaintState,
  rect : @core.Rect,
) -> MetalPaintState {
  MetalPaintState::{
    transform: state.transform,
    opacity: state.opacity,
    clip: state.clip
    .intersection(metal_transformed_bounds(rect, state.transform))
    .unwrap_or(empty_metal_rect()),
  }
}

///|
fn metal_state_pop_clip(
  state : MetalPaintState,
  stack : Array[@core.Rect],
) -> MetalPaintState {
  match stack.pop() {
    Some(previous) =>
      MetalPaintState::{
        transform: state.transform,
        opacity: state.opacity,
        clip: previous,
      }
    None =>
      MetalPaintState::{
        transform: state.transform,
        opacity: state.opacity,
        clip: empty_metal_rect(),
      }
  }
}
