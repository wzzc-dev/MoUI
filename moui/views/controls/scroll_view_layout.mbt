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
priv struct ScrollDragState {
  active : Bool
  dragging : Bool
  origin : @core.Point
  last_position : @core.Point
  raw_offset : @core.Point
}

///|
impl @core.ViewStateValue for ScrollDragState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollDragState.v1")
}

///|
impl @core.ViewStateValue for ScrollDragState with fn encode_view_state(self) {
  let output = Buffer(size_hint=50)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_byte(if self.dragging { 1 } else { 0 })
  output.write_double_be(self.origin.x)
  output.write_double_be(self.origin.y)
  output.write_double_be(self.last_position.x)
  output.write_double_be(self.last_position.y)
  output.write_double_be(self.raw_offset.x)
  output.write_double_be(self.raw_offset.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollDragState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 50 {
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
    match (flags, @common.view_decode_doubles(bytes, from=2, count=6)) {
      ((Some(active), Some(dragging)), Some(values)) =>
        Some({
          active,
          dragging,
          origin: @core.Point::new(x=values[0], y=values[1]),
          last_position: @core.Point::new(x=values[2], y=values[3]),
          raw_offset: @core.Point::new(x=values[4], y=values[5]),
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
impl @core.ViewNode for ScrollContainer with fn declaration(self) {
  @common.view_declaration(
    layout=@common.view_exact_channel(
      @common.view_record_key("ScrollContainer.layout", [
        (
          "offset",
          @core.DeclarationKey::option(self.offset.map(@common.view_point_key)),
        ),
        ("viewport", @common.view_size_option_key(self.viewport)),
        (
          "request",
          @core.DeclarationKey::option(
            self.request.map(request => {
              @core.DeclarationKey::record(
                type_tag="moui.core.ScrollRequest.v1",
                fields=[
                  ("id", @core.DeclarationKey::int(request.id)),
                  ("offset", @common.view_point_key(request.offset)),
                ],
              )
            }),
          ),
        ),
      ]),
    ),
    paint=@common.view_exact_channel(
      @core.DeclarationKey::bool(self.shows_indicator),
    ),
    semantics=@common.view_exact_channel(
      @core.DeclarationKey::bool(self.scrollable),
    ),
  )
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
      scroll_child_frame(
        frame=@core.Rect::new(
          x=0.0,
          y=0.0,
          width=viewport_size.width,
          height=viewport_size.height,
        ),
        offset~,
        viewport=viewport_size,
        child_size=measured,
        direction=ctx.environment.layout_direction,
      ),
    ],
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
  let shift = @core.Point::new(
    x=runtime_state.offset.x - surface_offset.x,
    y=runtime_state.offset.y - surface_offset.y,
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
    animating: !drag.active &&
    scroll_motion_is_animating(motion, runtime_state.offset, now_ms=ctx.now_ms),
  }
}

///|
impl @core.ViewNode for ScrollContainer with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(composition=Boundary, role=ScrollView)
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
        let moved = next_offset != current.offset
        if !moved && !settling {
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
    _ => @core.ViewEventResult::ignored()
  }
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
      }
      {
        changed: carried,
        activated: false,
        focused: false,
        captured: true,
        state: Some(
          ctx.state
          .without_slot(scroll_motion_state_slot())
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
      let next_drag = {
        ..drag,
        dragging: is_dragging,
        last_position: event.position,
        raw_offset,
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
      let state_context = if settling {
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
        changed: settling,
        activated: false,
        focused: false,
        captured: true,
        state: Some(state_context),
        text_control: None,
        dirty: if settling {
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
fn scroll_child_frame(
  frame~ : @core.Rect,
  offset~ : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
  direction~ : @core.LayoutDirection,
) -> @core.Rect {
  let clamped = scroll_clamp_offset(offset, viewport, child_size)
  let max_x = @common.view_max_double(0.0, child_size.width - viewport.width)
  let leading = match direction {
    LeftToRight => clamped.x
    RightToLeft => max_x - clamped.x
  }
  @core.Rect::new(
    x=frame.origin.x - leading,
    y=frame.origin.y - clamped.y,
    width=@common.view_max_double(viewport.width, child_size.width),
    height=@common.view_max_double(viewport.height, child_size.height),
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
