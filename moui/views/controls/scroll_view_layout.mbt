///|
pub fn[Msg] scroll_container(
  child~ : @core.View[Msg],
  offset? : @core.Point,
  viewport? : @core.Size? = None,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  request? : @core.ScrollRequest,
  shows_indicator? : Bool = false,
  kind? : String = "Scroll",
  key? : String? = None,
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
  applied_request_id : Int
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
        Some({ offset: @core.Point::new(x~, y~), applied_request_id })
      _ => None
    }
  }
}

///|
fn scroll_runtime_state_slot() -> @core.ViewStateSlot[ScrollRuntimeState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.position"),
    initial={ offset: @core.Point::new(x=0.0, y=0.0), applied_request_id: -1 },
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
      { offset: request.offset, applied_request_id: request.id }
    _ => current
  }
}

///|
/// Transient pointer state for touch/mouse dragging over the scroll surface.
/// The runtime owns this value so it survives the rebuild triggered by a
/// scroll-state update without leaking platform pointer state into controls.
priv struct ScrollDragState {
  active : Bool
  dragging : Bool
  origin : @core.Point
  last_position : @core.Point
}

///|
impl @core.ViewStateValue for ScrollDragState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ScrollDragState.v1")
}

///|
impl @core.ViewStateValue for ScrollDragState with fn encode_view_state(self) {
  let output = Buffer(size_hint=34)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_byte(if self.dragging { 1 } else { 0 })
  output.write_double_be(self.origin.x)
  output.write_double_be(self.origin.y)
  output.write_double_be(self.last_position.x)
  output.write_double_be(self.last_position.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for ScrollDragState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() == 17 {
    // Accept the pre-slop state encoding so a saved pointer state can be
    // discarded cleanly when upgrading an already-mounted view.
    let active = match bytes[0] {
      0 => Some(false)
      1 => Some(true)
      _ => None
    }
    let x = @core.ViewStateValue::decode_view_state(0.0, bytes[1:9].to_owned())
    let y = @core.ViewStateValue::decode_view_state(0.0, bytes[9:17].to_owned())
    match (active, x, y) {
      (Some(active), Some(x), Some(y)) => {
        let position = @core.Point::new(x~, y~)
        Some({
          active,
          dragging: false,
          origin: position,
          last_position: position,
        })
      }
      _ => None
    }
  } else if bytes.length() == 34 {
    let active = match bytes[0] {
      0 => Some(false)
      1 => Some(true)
      _ => None
    }
    let dragging = match bytes[1] {
      0 => Some(false)
      1 => Some(true)
      _ => None
    }
    let origin_x = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[2:10].to_owned(),
    )
    let origin_y = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[10:18].to_owned(),
    )
    let last_x = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[18:26].to_owned(),
    )
    let last_y = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[26:34].to_owned(),
    )
    match (active, dragging, origin_x, origin_y, last_x, last_y) {
      (
        Some(active),
        Some(dragging),
        Some(origin_x),
        Some(origin_y),
        Some(last_x),
        Some(last_y),
      ) =>
        Some({
          active,
          dragging,
          origin: @core.Point::new(x=origin_x, y=origin_y),
          last_position: @core.Point::new(x=last_x, y=last_y),
        })
      _ => None
    }
  } else {
    None
  }
}

///|
fn scroll_drag_state_slot() -> @core.ViewStateSlot[ScrollDragState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.scroll.drag"),
    initial=ScrollDragState::{
      active: false,
      dragging: false,
      origin: @core.Point::new(x=0.0, y=0.0),
      last_position: @core.Point::new(x=0.0, y=0.0),
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
  let viewport_size = self.viewport.unwrap_or(
    @common.first_child_size(ctx.child_sizes),
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
        child_size=@common.first_child_size(ctx.child_sizes),
      ),
    ],
    clips_children=true,
  )
}

///|
impl @core.ViewNode for ScrollContainer with fn paint(self, ctx) {
  let viewport_size = self.viewport.unwrap_or(ctx.frame.size)
  let offset = scroll_runtime_state(self, ctx.state).offset
  {
    commands: [
      @core.DrawCommand::PushClip(
        @core.Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=ctx.frame.size.width,
          height=ctx.frame.size.height,
        ),
      ),
    ],
    child_layers: [],
    post_commands: [@core.DrawCommand::PopClip],
    overlay_commands: if self.shows_indicator {
      scroll_indicator_commands(
        ctx.frame,
        first_child_frame_size(ctx.child_frames, viewport_size),
        offset,
      )
    } else {
      []
    },
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for ScrollContainer with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::ScrollView,
  )
}

///|
fn[Msg] scroll_container_event(
  node : ScrollContainer,
  ctx : @core.ViewEventContext,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
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
        )
        if next_offset == current.offset {
          @core.ViewEventResult::ignored()
        } else {
          let next = { ..current, offset: next_offset }
          @common.view_event_result(
            changed=true,
            activated=on_scroll is Some(_),
            captured=true,
            state=Some(ctx.state.with_slot(scroll_runtime_state_slot(), next)),
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
            messages=match on_scroll {
              Some(handler) => [handler(next_offset)]
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
    @core.PointerPhase::Down => ctx.frame.contains(event.position)
    @core.PointerPhase::Move
    | @core.PointerPhase::Up
    | @core.PointerPhase::Cancel
    | @core.PointerPhase::Exit => drag.active
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
  match event.phase {
    @core.PointerPhase::Down => {
      let next = ScrollDragState::{
        active: true,
        dragging: false,
        origin: event.position,
        last_position: event.position,
      }
      {
        changed: false,
        activated: false,
        focused: false,
        captured: true,
        state: Some(ctx.state.with_slot(slot, next)),
        text_control: None,
        dirty: @core.ViewDirtyHint::ViewClean,
        messages: [],
      }
    }
    @core.PointerPhase::Move => {
      if !drag.active {
        return @core.ViewEventResult::ignored()
      }
      let delta = @core.Point::new(
        x=event.position.x - drag.last_position.x,
        y=event.position.y - drag.last_position.y,
      )
      let distance_x = event.position.x - drag.origin.x
      let distance_y = event.position.y - drag.origin.y
      let starts_dragging = !drag.dragging &&
        distance_x * distance_x + distance_y * distance_y >=
        scroll_drag_slop() * scroll_drag_slop()
      let is_dragging = drag.dragging || starts_dragging
      let next_drag = {
        ..drag,
        dragging: is_dragging,
        last_position: event.position,
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
          dirty: @core.ViewDirtyHint::ViewClean,
          messages: [],
        }
      }
      let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
      let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
      let current = scroll_runtime_state(node, ctx.state)
      let next = scroll_offset_after_wheel(
        current.offset,
        delta,
        viewport_size,
        child_size,
      )
      let moved = next != current.offset
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
        changed: moved,
        activated: dispatch && on_scroll is Some(_),
        focused: false,
        captured: true,
        state: Some(state_context),
        text_control: None,
        dirty: if moved {
          @core.ViewDirtyHint::ViewLayoutDirty
        } else {
          @core.ViewDirtyHint::ViewClean
        },
        messages: match on_scroll {
          Some(handler) => if dispatch { [handler(next)] } else { [] }
          None => []
        },
      }
    }
    @core.PointerPhase::Up
    | @core.PointerPhase::Cancel
    | @core.PointerPhase::Exit => {
      if !drag.active {
        return @core.ViewEventResult::ignored()
      }
      {
        changed: false,
        activated: false,
        focused: false,
        captured: true,
        state: Some(ctx.state.without_slot(slot)),
        text_control: None,
        dirty: @core.ViewDirtyHint::ViewClean,
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
    @core.SemanticsScrollDirection::Forward
    | @core.SemanticsScrollDirection::Down =>
      @core.Point::new(x=0.0, y=-vertical_step)
    @core.SemanticsScrollDirection::Backward
    | @core.SemanticsScrollDirection::Up =>
      @core.Point::new(x=0.0, y=vertical_step)
    @core.SemanticsScrollDirection::Left =>
      @core.Point::new(x=horizontal_step, y=0.0)
    @core.SemanticsScrollDirection::Right =>
      @core.Point::new(x=-horizontal_step, y=0.0)
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
      ctx.state.with_slot(scroll_runtime_state_slot(), {
        ..current,
        offset: next,
      }),
    ),
    dirty=@core.ViewDirtyHint::ViewLayoutDirty,
    messages~,
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
  let track_top = frame.origin.y + 4.0
  let track_height = @common.view_max_double(1.0, viewport_height - 8.0)
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
      x=frame.origin.x + frame.size.width - 7.0,
      y=track_top + travel * clamped.y / max_offset,
      width=3.0,
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
        @core.DrawCommand::FillRoundedRectBrush(
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
    event.position.x >= ctx.frame.origin.x + ctx.frame.size.width - 16.0 &&
    event.phase == @core.PointerPhase::Down
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
  let next_dragging = event.phase == @core.PointerPhase::Down ||
    event.phase == @core.PointerPhase::Move
  let next_state = if next_dragging {
    ctx.state.with_slot(scroll_indicator_drag_slot(), true)
  } else {
    ctx.state.without_slot(scroll_indicator_drag_slot())
  }
  let should_move = event.phase == @core.PointerPhase::Down ||
    event.phase == @core.PointerPhase::Move
  let next_y = if should_move {
    let track_height = @common.view_max_double(1.0, viewport_size.height - 8.0)
    let thumb_height = @common.view_max_double(
      28.0,
      track_height *
      viewport_size.height /
      @common.view_max_double(viewport_size.height, child_size.height),
    )
    let travel = @common.view_max_double(1.0, track_height - thumb_height)
    let ratio = @common.clamp_view_double(
      (event.position.y - ctx.frame.origin.y - 4.0 - thumb_height / 2.0) /
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
  let next_state = next_state.with_slot(scroll_runtime_state_slot(), {
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
    dirty: @core.ViewDirtyHint::ViewLayoutDirty,
    messages: match on_scroll {
      Some(handler) => if should_move { [handler(next_offset)] } else { [] }
      None => []
    },
  }
}

///|
fn scroll_child_frame(
  frame~ : @core.Rect,
  offset~ : @core.Point,
  viewport~ : @core.Size,
  child_size~ : @core.Size,
) -> @core.Rect {
  let clamped = scroll_clamp_offset(offset, viewport, child_size)
  @core.Rect::new(
    x=frame.origin.x - clamped.x,
    y=frame.origin.y - clamped.y,
    width=@common.view_max_double(viewport.width, child_size.width),
    height=@common.view_max_double(viewport.height, child_size.height),
  )
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
) -> @core.Point {
  let clamped = scroll_clamp_offset(current, viewport, child_size)
  scroll_clamp_offset(
    @core.Point::new(x=clamped.x - delta.x, y=clamped.y - delta.y),
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
