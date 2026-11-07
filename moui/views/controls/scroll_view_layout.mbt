///|
pub fn[Msg] scroll_container(
  child~ : @core.View[Msg],
  offset? : @core.Point,
  viewport~ : @core.Size? = None,
  on_scroll~ : ((@core.Point) -> Msg)? = None,
  request? : @core.ScrollRequest,
  shows_indicator~ : Bool = false,
  kind~ : String = "Scroll",
  key~ : String? = None,
) -> @core.View[Msg] {
  let scrollable = offset is None || on_scroll is Some(_)
  @core.View::from_node(
    ScrollContainer::{
      offset,
      viewport,
      request,
      shows_indicator,
      scrollable,
      kind,
      key,
    },
    children=_node => [child],
    event=(node, ctx) => scroll_container_event(node, ctx, on_scroll),
    semantics_actions=node => {
      if node.scrollable {
        [
          @core.ViewSemanticsActionHandler::scroll((ctx, direction) => {
            scroll_container_semantics_action(node, ctx, direction, on_scroll)
          }),
        ]
      } else {
        []
      }
    },
  )
}

///|
priv struct ScrollContainer {
  offset : @core.Point?
  viewport : @core.Size?
  request : @core.ScrollRequest?
  shows_indicator : Bool
  scrollable : Bool
  kind : String
  key : String?
}

///|
/// Element-owned scroll position and exactly-once request cursor.
priv struct ScrollRuntimeState {
  offset : @core.Point
  applied_request_id : Int32
}

///|
impl @core.ViewStateValue for ScrollRuntimeState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollRuntimeState.v1")
}

///|
impl @core.ViewStateValue for ScrollRuntimeState with fn encode_view_state(self) {
  let output = Buffer(size_hint=20)
  output.write_double_be(self.offset.x)
  output.write_double_be(self.offset.y)
  output.write_int_be(self.applied_request_id)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollRuntimeState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 20 {
    None
  } else {
    match
      (
        @core.ViewStateValue::decode_view_state(0.0, bytes[0:8].to_owned()),
        @core.ViewStateValue::decode_view_state(0.0, bytes[8:16].to_owned()),
        @core.ViewStateValue::decode_view_state(0, bytes[16:20].to_owned()),
      ) {
      (Some(x), Some(y), Some(applied_request_id)) =>
        Some({ offset: @core.Point::new(x~, y~), applied_request_id, })
      _ => None
    }
  }
}

///|
fn scroll_runtime_state_slot() -> @core.ViewStateSlot[ScrollRuntimeState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.position"),
    initial={ offset: @core.Point::new(x=0.0, y=0.0), applied_request_id: -1, },
  )
}

///|
fn scroll_runtime_state(
  node : ScrollContainer,
  state : @core.ViewStateContext,
) -> ScrollRuntimeState {
  let stored = state.read_slot(scroll_runtime_state_slot())
  let current = match node.offset {
    Some(offset) => { ..stored, offset, }
    None => stored
  }
  match node.request {
    Some(request) if request.id > current.applied_request_id =>
      { offset: request.offset, applied_request_id: request.id, }
    _ => current
  }
}

///|
/// Transient pointer state for touch/mouse dragging over the scroll surface.
/// The runtime owns this value so it survives the rebuild triggered by a
/// scroll-state update without leaking platform pointer state into controls.
///
/// `raw_offset` is the offset the pointer has pulled the surface to *before*
/// clamping. The authoritative offset stays hard-clamped — layout, hit-testing
/// and `on_scroll` all report that value — while `raw_offset` retains the
/// overshoot so the paint pass can draw a bounded rubber band and release can
/// settle it back.
///
/// `track_position`/`track_time_ms`/`velocity` carry release-velocity tracking
/// for the fling: the tracked pair is the last sample with a distinct clock
/// stamp and real travel, and `velocity` is that interval's offset-space
/// speed in px/ms.
priv struct ScrollDragState {
  active : Bool
  dragging : Bool
  origin : @core.Point
  last_position : @core.Point
  raw_offset : @core.Point
  track_position : @core.Point
  track_time_ms : Double
  velocity : @core.Point
}

///|
impl @core.ViewStateValue for ScrollDragState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollDragState.v2")
}

///|
impl @core.ViewStateValue for ScrollDragState with fn encode_view_state(self) {
  let output = Buffer(size_hint=90)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_byte(if self.dragging { 1 } else { 0 })
  output.write_double_be(self.origin.x)
  output.write_double_be(self.origin.y)
  output.write_double_be(self.last_position.x)
  output.write_double_be(self.last_position.y)
  output.write_double_be(self.raw_offset.x)
  output.write_double_be(self.raw_offset.y)
  output.write_double_be(self.track_position.x)
  output.write_double_be(self.track_position.y)
  output.write_double_be(self.track_time_ms)
  output.write_double_be(self.velocity.x)
  output.write_double_be(self.velocity.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollDragState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 90 {
    // A rejected decode falls back to the slot's initial value, i.e. no drag
    // in progress. The pre-overscroll encodings are rejected rather than
    // folded into this shape: a fabricated `raw_offset` would pull the surface
    // to the head of the content on the next `Move`.
    None
  } else {
    let flags = (
      match bytes[0] {
        0 => Some(false)
        1 => Some(true)
        _ => None
      },
      match bytes[1] {
        0 => Some(false)
        1 => Some(true)
        _ => None
      },
    )
    match (flags, @common.view_decode_doubles(bytes, from=2, count=11)) {
      ((Some(active), Some(dragging)), Some(values)) =>
        Some({
          active,
          dragging,
          origin: @core.Point::new(x=values[0], y=values[1]),
          last_position: @core.Point::new(x=values[2], y=values[3]),
          raw_offset: @core.Point::new(x=values[4], y=values[5]),
          track_position: @core.Point::new(x=values[6], y=values[7]),
          track_time_ms: values[8],
          velocity: @core.Point::new(x=values[9], y=values[10]),
        })
      _ => None
    }
  }
}

///|
fn scroll_drag_state_slot() -> @core.ViewStateSlot[ScrollDragState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.drag"),
    initial={
      active: false,
      dragging: false,
      origin: @core.Point::new(x=0.0, y=0.0),
      last_position: @core.Point::new(x=0.0, y=0.0),
      raw_offset: @core.Point::new(x=0.0, y=0.0),
      track_position: @core.Point::new(x=0.0, y=0.0),
      track_time_ms: 0.0,
      velocity: @core.Point::new(x=0.0, y=0.0),
    },
  )
}

///|
/// A small pointer movement is ordinary click jitter, especially for a mouse.
/// Do not cancel a child control until the pointer has moved far enough to be a
/// deliberate scroll gesture.
fn scroll_drag_slop() -> Double {
  4.0
}

///|
impl @core.ViewNode for ScrollContainer with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for ScrollContainer with fn child_constraints(
  _self,
  _constraints,
) {
  @core.Constraints::unbounded()
}

///|
impl @core.ViewNode for ScrollContainer with fn layout(self, ctx) {
  // Viewport fallback: the child measures under unbounded constraints, so a
  // windowed list (spacers + rows) reports its full virtual extent here —
  // clamping against that would zero the offset and pin the child frame to
  // the top while the window/paint paths use the real frame. Constrain the
  // measured size instead: the viewport is the space the parent actually
  // allots, which is also what the event path reads off `ctx.frame`.
  let measured = @common.first_child_size(ctx.child_sizes)
  let viewport_size = self.viewport.unwrap_or(
    ctx.constraints.constrain(measured),
  )
  let offset = scroll_runtime_state(self, ctx.state).offset
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(viewport_size),
    child_frames=[
      scroll_content_frame(
        frame=@core.Rect::new(
          x=0.0,
          y=0.0,
          width=viewport_size.width,
          height=viewport_size.height,
        ),
        viewport=viewport_size,
        child_size=measured,
      ),
    ],
    child_transform=scroll_child_transform(
      offset~,
      viewport=viewport_size,
      child_size=measured,
      direction=ctx.environment.layout_direction,
    ),
    clips_children=true,
  )
}

///|
impl @core.ViewNode for ScrollContainer with fn paint(self, ctx) {
  let viewport_size = self.viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
  let runtime_state = scroll_runtime_state(self, ctx.state)
  let drag = ctx.state.read_slot(scroll_drag_state_slot())
  let motion = ctx.state.read_slot(scroll_motion_state_slot())
  let fling = ctx.state.read_slot(scroll_fling_state_slot())
  // Geometry stays at the authoritative clamped offset; only the painted
  // surface moves, by the overshoot a held drag is carrying or a released band
  // is still settling.
  let surface_offset = scroll_visible_offset(
    drag,
    motion,
    runtime_state.offset,
    viewport=viewport_size,
    child_size~,
    now_ms=ctx.now_ms,
  )
  // Runtime paint already applies the authoritative content transform. Only
  // the rubber-band overshoot remains as an additional local translation.
  let shift = scroll_paint_shift(
    runtime_state.offset,
    surface_offset,
    viewport_size,
    child_size,
    direction=ctx.environment.layout_direction,
  )
  let commands : Array[@core.DrawCommand] = [
    PushClip(
      @core.Rect::new(
        x=ctx.frame.origin.x,
        y=ctx.frame.origin.y,
        width=ctx.frame.size.width,
        height=ctx.frame.size.height,
      ),
    ),
  ]
  let post_commands : Array[@core.DrawCommand] = []
  if shift.x != 0.0 || shift.y != 0.0 {
    commands.push(
      PushTransform(@core.Transform2D::translation(dx=shift.x, dy=shift.y)),
    )
    post_commands.push(PopTransform)
  }
  post_commands.push(PopClip)
  {
    commands,
    child_layers: [],
    post_commands,
    overlay_commands: if self.shows_indicator {
      scroll_indicator_commands(ctx.frame, child_size, surface_offset)
    } else {
      []
    },
    repaint_boundary: false,
    // Keep producing frames while the rubber band is settling or a fling is
    // still gliding; without this the surface freezes mid-interpolation. The
    // runtime's frame pump turns this latch into `FrameTick` events for the
    // fling (see `moui/runtime/frame_pump.mbt`).
    animating: !drag.active &&
    (
      scroll_motion_is_animating(
        motion,
        runtime_state.offset,
        now_ms=ctx.now_ms,
      ) ||
      scroll_fling_is_live(fling, runtime_state.offset, now_ms=ctx.now_ms)
    ),
  }
}

///|
impl @core.ViewNode for ScrollContainer with fn semantics(_self) {
  @core.ViewSemanticsInfo::container(composition=Boundary, role=ScrollView)
}

///|
fn[Msg] scroll_container_event(
  node : ScrollContainer,
  ctx : @core.ViewEventContext,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) =>
      if node.shows_indicator && scroll_indicator_handles_event(ctx, event) {
        scroll_indicator_event_result(
          ctx,
          event,
          node~,
          viewport=node.viewport,
          on_scroll~,
        )
      } else if scroll_container_drag_handles_event(node, ctx, event) {
        scroll_container_drag_event(node, ctx, event, on_scroll)
      } else if ctx.frame.contains(event.position) &&
        (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
        let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
        let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
        let current = scroll_runtime_state(node, ctx.state)
        let next_offset = scroll_offset_after_wheel(
          current.offset,
          event.wheel_delta,
          viewport_size,
          child_size,
          direction=ctx.environment.layout_direction,
        )
        let settling = scroll_motion_is_animating(
          ctx.state.read_slot(scroll_motion_state_slot()),
          current.offset,
          now_ms=ctx.now_ms,
        )
        // A wheel step takes over from a live fling even when it clamps to
        // the same offset: the glide must not keep fighting the wheel.
        let flinging = scroll_fling_is_live(
          ctx.state.read_slot(scroll_fling_state_slot()),
          current.offset,
          now_ms=ctx.now_ms,
        )
        let moved = next_offset != current.offset
        if !moved && !settling && !flinging {
          @core.ViewEventResult::ignored()
        } else {
          let next = { ..current, offset: next_offset, }
          @common.view_event_result(
            changed=true,
            activated=moved && on_scroll is Some(_),
            captured=true,
            state=Some(
              ctx.state
              .without_slot(scroll_motion_state_slot())
              .without_slot(scroll_fling_state_slot())
              .with_slot(scroll_runtime_state_slot(), next),
            ),
            dirty=if moved { ViewLayoutDirty } else { ViewPaintDirty },
            messages=match on_scroll {
              Some(handler) => if moved { [handler(next_offset)] } else { [] }
              None => []
            },
          )
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    FrameTick(frame) => scroll_container_fling_tick(node, ctx, frame, on_scroll)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
/// Advance a live fling by one frame. Runs on the runtime's frame pump
/// (`AppEvent::FrameTick` dispatched into animating subtrees): the
/// authoritative offset moves through the normal state -> layout ->
/// `on_scroll` path, so a windowed list re-materializes its rows from the
/// app's offset exactly as it does for a drag.
fn[Msg] scroll_container_fling_tick(
  node : ScrollContainer,
  ctx : @core.ViewEventContext,
  frame : @core.Frame,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let fling_slot = scroll_fling_state_slot()
  let fling = ctx.state.read_slot(fling_slot)
  let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
  let current = scroll_runtime_state(node, ctx.state)
  // An offset the fling does not own — a wheel step, a request, a controlled
  // app value — ends it, as does a clock that stopped moving forward: a tick
  // that cannot make progress must not hold the frame latch forever.
  if fling.anchor != current.offset ||
    frame.time_ms <= fling.last_time_ms ||
    frame.time_ms >= fling.start_time_ms + scroll_fling_max_duration_ms() {
    return @common.view_event_result(
      state=Some(ctx.state.without_slot(fling_slot)),
    )
  }
  let dt = @common.view_min_double(
    frame.time_ms - fling.last_time_ms,
    scroll_fling_max_step_ms(),
  )
  // Mirror `scroll_drag_band`'s extent gating: a rangeless horizontal axis
  // pulls no band, so an accidental sideways fling stops instead of sliding
  // the surface over content that never overflowed.
  let x_extent = if scroll_axis_has_range(
      viewport_axis=viewport_size.width,
      child_axis=child_size.width,
    ) {
    scroll_overscroll_extent(viewport_size.width)
  } else {
    0.0
  }
  let x = scroll_fling_axis_step(
    velocity=fling.velocity.x,
    position=current.offset.x,
    dt~,
    extent=x_extent,
    max_offset=@common.view_max_double(
      0.0,
      child_size.width - viewport_size.width,
    ),
  )
  let y = scroll_fling_axis_step(
    velocity=fling.velocity.y,
    position=current.offset.y,
    dt~,
    extent=scroll_overscroll_extent(viewport_size.height),
    max_offset=@common.view_max_double(
      0.0,
      child_size.height - viewport_size.height,
    ),
  )
  let next_offset = @core.Point::new(x=x.position, y=y.position)
  let next_velocity = @core.Point::new(x=x.velocity, y=y.velocity)
  let moved = next_offset != current.offset
  let banded = x.band != 0.0 || y.band != 0.0
  let stopped = next_velocity.x.abs() < scroll_fling_stop_velocity_px_per_ms() &&
    next_velocity.y.abs() < scroll_fling_stop_velocity_px_per_ms()
  // The rebound band plays only when the fling as a whole finishes at the
  // edge: one axis hitting its clamp while the other still glides takes the
  // hard stop and keeps its glide.
  let hands_off_to_band = banded && stopped
  let dispatch = moved && (node.offset is None || on_scroll is Some(_))
  let mut state_context = ctx.state
  if moved {
    state_context = state_context.with_slot(scroll_runtime_state_slot(), {
      ..current,
      offset: next_offset,
    })
  }
  if hands_off_to_band {
    state_context = state_context
      .without_slot(fling_slot)
      .with_slot(scroll_motion_state_slot(), {
        anchor: next_offset,
        start_time_ms: frame.time_ms,
        duration: @core.Point::new(
          x=scroll_rebound_axis_duration(
            overscroll=x.band,
            extent=scroll_overscroll_extent(viewport_size.width),
          ),
          y=scroll_rebound_axis_duration(
            overscroll=y.band,
            extent=scroll_overscroll_extent(viewport_size.height),
          ),
        ),
        band: @core.Point::new(x=x.band, y=y.band),
      })
  } else if stopped {
    state_context = state_context.without_slot(fling_slot)
  } else {
    state_context = state_context.with_slot(fling_slot, {
      anchor: next_offset,
      start_time_ms: fling.start_time_ms,
      last_time_ms: frame.time_ms,
      velocity: next_velocity,
    })
  }
  @common.view_event_result(
    changed=moved || hands_off_to_band,
    activated=dispatch && on_scroll is Some(_),
    state=Some(state_context),
    dirty=if moved {
      ViewLayoutDirty
    } else if hands_off_to_band {
      ViewPaintDirty
    } else {
      ViewClean
    },
    messages=match on_scroll {
      Some(handler) => if dispatch { [handler(next_offset)] } else { [] }
      None => []
    },
  )
}

///|
fn scroll_container_drag_handles_event(
  node : ScrollContainer,
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
) -> Bool {
  if !node.scrollable {
    return false
  }
  let drag = ctx.state.read_slot(scroll_drag_state_slot())
  match event.phase {
    // Primary button only: right-button presses reach the view tree for
    // per-target context menus and must not start a scroll drag.
    Down => event.button == 0 && ctx.frame.contains(event.position)
    Move | Up | Cancel | Exit => drag.active
  }
}

///|
fn[Msg] scroll_container_drag_event(
  node : ScrollContainer,
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let slot = scroll_drag_state_slot()
  let drag = ctx.state.read_slot(slot)
  let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
  let current = scroll_runtime_state(node, ctx.state)
  match event.phase {
    Down => {
      // Grabbing a band that is still settling keeps the surface painted where
      // it looks: the band is inverted back through the pull damping to the
      // unclamped offset the drag continues from, then dropped.
      let motion = ctx.state.read_slot(scroll_motion_state_slot())
      let band = scroll_motion_band(motion, current.offset, now_ms=ctx.now_ms)
      let carried = band.x != 0.0 || band.y != 0.0
      let raw_offset = if carried {
        @core.Point::new(
          x=current.offset.x +
            scroll_overscroll_raw(
              band.x,
              extent=scroll_overscroll_extent(viewport_size.width),
            ),
          y=current.offset.y +
            scroll_overscroll_raw(
              band.y,
              extent=scroll_overscroll_extent(viewport_size.height),
            ),
        )
      } else {
        current.offset
      }
      let next = ScrollDragState::{
        active: true,
        dragging: false,
        origin: event.position,
        last_position: event.position,
        raw_offset,
        track_position: event.position,
        track_time_ms: ctx.now_ms,
        velocity: @core.Point::new(x=0.0, y=0.0),
      }
      {
        changed: carried,
        activated: false,
        focused: false,
        captured: true,
        state: Some(
          ctx.state
          .without_slot(scroll_motion_state_slot())
          .without_slot(scroll_fling_state_slot())
          .with_slot(slot, next),
        ),
        text_control: None,
        dirty: if carried {
          ViewPaintDirty
        } else {
          ViewClean
        },
        messages: [],
      }
    }
    Move => {
      if !drag.active {
        return @core.ViewEventResult::ignored()
      }
      // A rangeless axis carries no scroll input (see `scroll_axis_has_range`).
      // The slop test below still reads the physical pointer, so a drag that
      // starts on this surface cancels a child control either way.
      let delta_x = if scroll_axis_has_range(
          viewport_axis=viewport_size.width,
          child_axis=child_size.width,
        ) {
        event.position.x - drag.last_position.x
      } else {
        0.0
      }
      let delta = @core.Point::new(
        x=delta_x,
        y=event.position.y - drag.last_position.y,
      )
      let distance_x = event.position.x - drag.origin.x
      let distance_y = event.position.y - drag.origin.y
      let starts_dragging = !drag.dragging &&
        distance_x * distance_x + distance_y * distance_y >=
        scroll_drag_slop() * scroll_drag_slop()
      let is_dragging = drag.dragging || starts_dragging
      // Pointer travel inside the slop is click jitter and stays out of the
      // surface offset, exactly as the clamped path treated it.
      let raw_offset = if is_dragging {
        @core.Point::new(
          x=drag.raw_offset.x -
            scroll_leading_x_delta(delta.x, ctx.environment.layout_direction),
          y=drag.raw_offset.y - delta.y,
        )
      } else {
        drag.raw_offset
      }
      // Track release velocity in offset space. A tracked pair needs a clock
      // step and real travel to divide by: same-stamp samples (several host
      // events inside one frame) and zero-delta samples (the runtime's
      // pressed-pointer re-sample while something else animates) leave the
      // tracked pair alone, so the next real sample measures the full travel
      // and a held-still finger never inherits stale speed. The interval is
      // used as-is rather than blended — a micro-stall inside a flick reads
      // as "no fling" on release, which is the conservative failure.
      let track_dt = ctx.now_ms - drag.track_time_ms
      let (next_track_position, next_track_time_ms, next_velocity) = if !is_dragging {
        (drag.track_position, drag.track_time_ms, drag.velocity)
      } else if !drag.dragging {
        // First dragging sample: measure from here, so a held press before
        // the slop does not dilute the flick that follows.
        (event.position, ctx.now_ms, drag.velocity)
      } else if track_dt > 0.0 && event.position != drag.track_position {
        let instant = @core.Point::new(
          x=scroll_fling_clamp_velocity(
            0.0 -
            scroll_leading_x_delta(
              event.position.x - drag.track_position.x,
              ctx.environment.layout_direction,
            ) /
            track_dt,
          ),
          y=scroll_fling_clamp_velocity(
            0.0 - (event.position.y - drag.track_position.y) / track_dt,
          ),
        )
        (event.position, ctx.now_ms, instant)
      } else {
        (drag.track_position, drag.track_time_ms, drag.velocity)
      }
      let next_drag = {
        ..drag,
        dragging: is_dragging,
        last_position: event.position,
        raw_offset,
        track_position: next_track_position,
        track_time_ms: next_track_time_ms,
        velocity: next_velocity,
      }
      let next_context = ctx.state.with_slot(slot, next_drag)
      if !is_dragging {
        return {
          changed: false,
          activated: false,
          focused: false,
          // Keep the pointer stream alive without making the ancestor appear
          // to have started a drag. This preserves a child button click.
          captured: false,
          state: Some(next_context),
          text_control: None,
          dirty: ViewClean,
          messages: [],
        }
      }
      let next = scroll_clamp_offset(raw_offset, viewport_size, child_size)
      let band = scroll_drag_band(
        raw_offset,
        viewport=viewport_size,
        child_size~,
      )
      let previous_band = scroll_drag_band(
        drag.raw_offset,
        viewport=viewport_size,
        child_size~,
      )
      let moved = next != current.offset
      let band_changed = band != previous_band
      let dispatch = moved && (node.offset is None || on_scroll is Some(_))
      let state_context = if moved {
        next_context.with_slot(scroll_runtime_state_slot(), {
          ..current,
          offset: next,
        })
      } else {
        next_context
      }
      {
        changed: moved || band_changed,
        activated: dispatch && on_scroll is Some(_),
        focused: false,
        captured: true,
        state: Some(state_context),
        text_control: None,
        dirty: if moved {
          ViewLayoutDirty
        } else if band_changed {
          // Only the painted band moved, so the surface needs a repaint but the
          // authoritative geometry it is measured against does not.
          ViewPaintDirty
        } else {
          ViewClean
        },
        messages: match on_scroll {
          Some(handler) => if dispatch { [handler(next)] } else { [] }
          None => []
        },
      }
    }
    Up | Cancel | Exit => {
      if !drag.active {
        return @core.ViewEventResult::ignored()
      }
      // A release past the clamp animates back to it. The authoritative offset
      // is already that clamp, so only the bounded band settles and no geometry
      // has to move under a windowed child. Without an advancing animation
      // clock a band could never decay and would keep asking the host for
      // frames, so a frozen clock gets the plain release instead.
      let band = if drag.dragging && ctx.now_ms > 0.0 {
        scroll_drag_band(drag.raw_offset, viewport=viewport_size, child_size~)
      } else {
        @core.Point::new(x=0.0, y=0.0)
      }
      let settling = band.x != 0.0 || band.y != 0.0
      // A fling needs a live clock (a frozen one could never advance it), a
      // release that did not end past the clamp — that release answers with
      // the band — and tracked motion recent enough to still be the gesture's
      // own velocity. Only a real `Up` flings: an explicit `Cancel`/`Exit`
      // take the plain release.
      let can_fling = event.phase == Up &&
        drag.dragging &&
        ctx.now_ms > 0.0 &&
        !settling &&
        ctx.now_ms > drag.track_time_ms &&
        ctx.now_ms - drag.track_time_ms <= scroll_fling_track_window_ms()
      let starts_fling = can_fling &&
        (
          drag.velocity.x.abs() >= scroll_fling_start_velocity_px_per_ms() ||
          drag.velocity.y.abs() >= scroll_fling_start_velocity_px_per_ms()
        )
      let state_context = if starts_fling {
        ctx.state
        .without_slot(slot)
        .without_slot(scroll_motion_state_slot())
        .with_slot(scroll_fling_state_slot(), {
          anchor: current.offset,
          start_time_ms: ctx.now_ms,
          last_time_ms: ctx.now_ms,
          velocity: drag.velocity,
        })
      } else if settling {
        ctx.state
        .without_slot(slot)
        .with_slot(scroll_motion_state_slot(), {
          anchor: current.offset,
          start_time_ms: ctx.now_ms,
          duration: @core.Point::new(
            x=scroll_rebound_axis_duration(
              overscroll=band.x,
              extent=scroll_overscroll_extent(viewport_size.width),
            ),
            y=scroll_rebound_axis_duration(
              overscroll=band.y,
              extent=scroll_overscroll_extent(viewport_size.height),
            ),
          ),
          band,
        })
      } else {
        ctx.state.without_slot(slot)
      }
      {
        changed: settling || starts_fling,
        activated: false,
        focused: false,
        captured: true,
        state: Some(state_context),
        text_control: None,
        dirty: if settling || starts_fling {
          ViewPaintDirty
        } else {
          ViewClean
        },
        messages: [],
      }
    }
  }
}

///|
fn semantics_scroll_wheel_delta(
  direction : @core.SemanticsScrollDirection,
  viewport : @core.Size,
) -> @core.Point {
  let horizontal_step = @common.view_max_double(40.0, viewport.width * 0.8)
  let vertical_step = @common.view_max_double(40.0, viewport.height * 0.8)
  match direction {
    Forward | Down => @core.Point::new(x=0.0, y=-vertical_step)
    Backward | Up => @core.Point::new(x=0.0, y=vertical_step)
    Left => @core.Point::new(x=horizontal_step, y=0.0)
    Right => @core.Point::new(x=-horizontal_step, y=0.0)
  }
}

///|
fn[Msg] scroll_container_semantics_action(
  node : ScrollContainer,
  ctx : @core.ViewSemanticsActionContext,
  direction : @core.SemanticsScrollDirection,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewSemanticsActionResult[Msg] {
  if !node.scrollable {
    return @core.ViewSemanticsActionResult::rejected()
  }
  let viewport = node.viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport)
  let current = scroll_runtime_state(node, ctx.state)
  let delta = semantics_scroll_wheel_delta(direction, viewport)
  let next = scroll_offset_after_wheel(
    current.offset,
    delta,
    viewport,
    child_size,
    direction=ctx.environment.layout_direction,
  )
  let messages = match on_scroll {
    Some(handler) => [handler(next)]
    None => []
  }
  if next == current.offset && messages.is_empty() {
    return @core.ViewSemanticsActionResult::rejected()
  }
  @core.ViewSemanticsActionResult::accepted(
    state=Some(
      ctx.state
      .without_slot(scroll_motion_state_slot())
      .with_slot(scroll_runtime_state_slot(), { ..current, offset: next, }),
    ),
    dirty=ViewLayoutDirty,
    messages~,
  )
}

///|
/// A vertical scrollbar rides the trailing cross-axis edge of the viewport.
/// Both the thumb and its hit region derive from here, so they cannot drift
/// apart and mirroring the bar for a right-to-left surface is one change.
fn scroll_indicator_track_x(frame : @core.Rect) -> Double {
  frame.origin.x +
  frame.size.width -
  scroll_indicator_edge_inset() -
  scroll_indicator_thumb_width()
}

///|
fn scroll_indicator_thumb_width() -> Double {
  3.0
}

///|
fn scroll_indicator_edge_inset() -> Double {
  4.0
}

///|
/// Extra grab room beside the thumb, on top of its own width.
fn scroll_indicator_hit_inset() -> Double {
  9.0
}

///|
fn scroll_indicator_track_height(viewport_axis : Double) -> Double {
  @common.view_max_double(
    1.0,
    viewport_axis - 2.0 * scroll_indicator_edge_inset(),
  )
}

///|
fn scroll_indicator_thumb(
  frame : @core.Rect,
  child_size : @core.Size,
  offset : @core.Point,
) -> @core.Rect? {
  let viewport_height = frame.size.height
  if viewport_height <= 0.0 || child_size.height <= viewport_height {
    return None
  }
  let track_top = frame.origin.y + scroll_indicator_edge_inset()
  let track_height = scroll_indicator_track_height(viewport_height)
  let thumb_height = @common.view_max_double(
    28.0,
    track_height * viewport_height / child_size.height,
  )
  let travel = @common.view_max_double(0.0, track_height - thumb_height)
  let max_offset = @common.view_max_double(
    1.0,
    child_size.height - viewport_height,
  )
  let clamped = scroll_clamp_offset(offset, frame.size, child_size)
  Some(
    @core.Rect::new(
      x=scroll_indicator_track_x(frame),
      y=track_top + travel * clamped.y / max_offset,
      width=scroll_indicator_thumb_width(),
      height=thumb_height,
    ),
  )
}

///|
fn scroll_indicator_commands(
  frame : @core.Rect,
  child_size : @core.Size,
  offset : @core.Point,
) -> Array[@core.DrawCommand] {
  match scroll_indicator_thumb(frame, child_size, offset) {
    Some(thumb) =>
      [
        FillRoundedRectBrush(
          @core.RoundedRect::new(rect=thumb, radius=1.5),
          @core.Brush::solid(@core.Color::rgba(r=0.15, g=0.18, b=0.22, a=0.48)),
        ),
      ]
    None => []
  }
}

///|
fn scroll_indicator_handles_event(
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
) -> Bool {
  ctx.state.read_slot(scroll_indicator_drag_slot()) ||
  (
    ctx.frame.contains(event.position) &&
    event.position.x >=
    scroll_indicator_track_x(ctx.frame) - scroll_indicator_hit_inset() &&
    event.phase == Down
  )
}

///|
fn scroll_indicator_drag_slot() -> @core.ViewStateSlot[Bool] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll-indicator.drag"),
    initial=false,
  )
}

///|
fn[Msg] scroll_indicator_event_result(
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
  node~ : ScrollContainer,
  viewport~ : @core.Size?,
  on_scroll~ : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let viewport_size = viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
  let runtime_state = scroll_runtime_state(node, ctx.state)
  let current = scroll_clamp_offset(
    runtime_state.offset,
    viewport_size,
    child_size,
  )
  let next_dragging = event.phase == Down || event.phase == Move
  let next_state = if next_dragging {
    ctx.state.with_slot(scroll_indicator_drag_slot(), true)
  } else {
    ctx.state.without_slot(scroll_indicator_drag_slot())
  }
  let should_move = event.phase == Down || event.phase == Move
  let next_y = if should_move {
    let track_height = scroll_indicator_track_height(viewport_size.height)
    let thumb_height = @common.view_max_double(
      28.0,
      track_height *
      viewport_size.height /
      @common.view_max_double(viewport_size.height, child_size.height),
    )
    let travel = @common.view_max_double(1.0, track_height - thumb_height)
    let ratio = @common.clamp_view_double(
      (
        event.position.y -
        ctx.frame.origin.y -
        scroll_indicator_edge_inset() -
        thumb_height / 2.0
      ) /
      travel,
      0.0,
      1.0,
    )
    ratio *
    @common.view_max_double(0.0, child_size.height - viewport_size.height)
  } else {
    current.y
  }
  let next_offset = @core.Point::new(x=current.x, y=next_y)
  let next_state = next_state
    .without_slot(scroll_motion_state_slot())
    .with_slot(scroll_runtime_state_slot(), {
      ..runtime_state,
      offset: next_offset,
    })
  {
    changed: should_move || next_state != ctx.state,
    activated: should_move && on_scroll is Some(_),
    focused: false,
    captured: true,
    state: Some(next_state),
    text_control: None,
    dirty: ViewLayoutDirty,
    messages: match on_scroll {
      Some(handler) => if should_move { [handler(next_offset)] } else { [] }
      None => []
    },
  }
}

///|
/// `offset.x` is a *leading-edge* distance — how far the content has scrolled
/// away from the edge reading starts at. Left-to-right content therefore hangs
/// off the left edge of the viewport, right-to-left content off the right one,
/// and `d = 0` is always flush with the leading edge. This is placement against
/// a scroll distance, not a reflection of a child box, so it deliberately does
/// not go through `Rect::mirrored_x`.
fn scroll_content_frame(
  frame~ : @core.Rect,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y,
    width=@common.view_max_double(viewport.width, child_size.width),
    height=@common.view_max_double(viewport.height, child_size.height),
  )
}

///|
/// The viewport translation is content-local state, not part of descendant
/// frames. `offset.x` remains a leading-edge distance, so RTL presents the
/// mirrored content translation while layout and caches keep the same frame.
fn scroll_child_transform(
  offset~ : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
  direction~ : @core.LayoutDirection,
) -> @core.Transform2D {
  let clamped = scroll_clamp_offset(offset, viewport, child_size)
  let leading = scroll_leading_point(clamped, viewport, child_size, direction)
  @core.Transform2D::translation(dx=0.0 - leading.x, dy=0.0 - leading.y)
}

///|
/// Map a scroll distance to the physical content edge it exposes. Unlike the
/// child transform this does not clamp: the paint-only rubber band can sit
/// outside the scroll range on either side of a clamp.
fn scroll_leading_point(
  offset : @core.Point,
  viewport : @core.Size,
  child_size : @core.Size,
  direction : @core.LayoutDirection,
) -> @core.Point {
  let max_x = @common.view_max_double(0.0, child_size.width - viewport.width)
  @core.Point::new(
    x=match direction {
      LeftToRight => offset.x
      RightToLeft => max_x - offset.x
    },
    y=offset.y,
  )
}

///|
fn scroll_paint_shift(
  authoritative : @core.Point,
  visible : @core.Point,
  viewport : @core.Size,
  child_size : @core.Size,
  direction~ : @core.LayoutDirection,
) -> @core.Point {
  let authoritative_leading = scroll_leading_point(
    scroll_clamp_offset(authoritative, viewport, child_size),
    viewport,
    child_size,
    direction,
  )
  let visible_leading = scroll_leading_point(
    visible, viewport, child_size, direction,
  )
  @core.Point::new(
    x=authoritative_leading.x - visible_leading.x,
    y=authoritative_leading.y - visible_leading.y,
  )
}

///|
/// Re-express a physical x movement vector (wheel delta, finger travel) as the
/// change it produces in a leading-edge distance. Both stay physical at the
/// event boundary — a swipe right always moves content right — and only the
/// sign applied to the mirrored offset space changes.
fn scroll_leading_x_delta(
  delta_x : Double,
  direction : @core.LayoutDirection,
) -> Double {
  match direction {
    LeftToRight => delta_x
    RightToLeft => 0.0 - delta_x
  }
}

///|
fn first_child_frame_size(
  frames : Array[@core.Rect],
  fallback : @core.Size,
) -> @core.Size {
  match frames.get(0) {
    Some(frame) => frame.size
    None => fallback
  }
}

///|
fn scroll_offset_after_wheel(
  current : @core.Point,
  delta : @core.Point,
  viewport : @core.Size,
  child_size : @core.Size,
  direction~ : @core.LayoutDirection,
) -> @core.Point {
  let clamped = scroll_clamp_offset(current, viewport, child_size)
  scroll_clamp_offset(
    @core.Point::new(
      x=clamped.x - scroll_leading_x_delta(delta.x, direction),
      y=clamped.y - delta.y,
    ),
    viewport,
    child_size,
  )
}

///|
fn scroll_clamp_offset(
  offset : @core.Point,
  viewport : @core.Size,
  child_size : @core.Size,
) -> @core.Point {
  let max_x = @common.view_max_double(0.0, child_size.width - viewport.width)
  let max_y = @common.view_max_double(0.0, child_size.height - viewport.height)
  @core.Point::new(
    x=@common.view_min_double(max_x, @common.view_max_double(0.0, offset.x)),
    y=@common.view_min_double(max_y, @common.view_max_double(0.0, offset.y)),
  )
}
