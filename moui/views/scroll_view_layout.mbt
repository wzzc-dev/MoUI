///|
fn[Msg] scroll_container(
  child~ : @core.View[Msg],
  offset? : @core.Point = @core.Point::new(x=0.0, y=0.0),
  viewport? : @core.Size? = None,
  state? : @core.ScrollState? = None,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  shows_indicator? : Bool = false,
  kind? : String = "Scroll",
  key? : String? = None,
) -> @core.View[Msg] {
  let scrollable = state is Some(_) || on_scroll is Some(_)
  @core.View::from_node(
    ScrollContainer::{
      offset,
      viewport,
      shows_indicator,
      scrollable,
      kind,
      key,
    },
    children=_node => [child],
    event=(node, ctx) => scroll_container_event(node, ctx, state, on_scroll),
    semantics_actions=node => {
      if node.scrollable {
        [
          @core.ViewSemanticsActionHandler::scroll((ctx, direction) => {
            scroll_container_semantics_action(
              node, ctx, direction, state, on_scroll,
            )
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
  offset : @core.Point
  viewport : @core.Size?
  shows_indicator : Bool
  scrollable : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for ScrollContainer with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for ScrollContainer with fn declaration(self) {
  view_declaration(
    layout=view_exact_channel(
      view_record_key("ScrollContainer.layout", [
        ("offset", view_point_key(self.offset)),
        ("viewport", view_size_option_key(self.viewport)),
      ]),
    ),
    paint=view_exact_channel(@core.DeclarationKey::bool(self.shows_indicator)),
    semantics=view_exact_channel(@core.DeclarationKey::bool(self.scrollable)),
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
  let viewport_size = self.viewport.unwrap_or(first_child_size(ctx.child_sizes))
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(viewport_size), child_frames=[
    scroll_child_frame(
      frame=@core.Rect::new(
        x=0.0,
        y=0.0,
        width=viewport_size.width,
        height=viewport_size.height,
      ),
      offset=self.offset,
      viewport=viewport_size,
      child_size=first_child_size(ctx.child_sizes),
    ),
  ])
}

///|
impl @core.ViewNode for ScrollContainer with fn paint(self, ctx) {
  let viewport_size = self.viewport.unwrap_or(ctx.frame.size)
  // Clip to the actually rendered frame. Using `viewport_size` here would
  // misalign the clip when the frame is smaller than the requested viewport.
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
        self.offset,
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
  state : @core.ScrollState?,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      if node.shows_indicator && scroll_indicator_handles_event(ctx, event) {
        scroll_indicator_event_result(
          ctx,
          event,
          offset=node.offset,
          viewport=node.viewport,
          state~,
          on_scroll~,
        )
      } else if ctx.frame.contains(event.position) &&
        (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
        match (state, on_scroll) {
          (Some(state), Some(handler)) => {
            let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
            let child_size = first_child_frame_size(
              ctx.child_frames,
              viewport_size,
            )
            let current = state.offset()
            let next = scroll_offset_after_wheel(
              current,
              event.wheel_delta,
              viewport_size,
              child_size,
            )
            if next == current {
              @core.ViewEventResult::ignored()
            } else {
              state.scroll_to(x=next.x, y=next.y)
              view_event_result(
                changed=true,
                activated=true,
                captured=true,
                dirty=@core.ViewDirtyHint::ViewBuildDirty,
                messages=[handler(event.wheel_delta)],
              )
            }
          }
          (Some(state), None) => {
            let viewport_size = node.viewport.unwrap_or(ctx.frame.size)
            let child_size = first_child_frame_size(
              ctx.child_frames,
              viewport_size,
            )
            let current = state.offset()
            let next = scroll_offset_after_wheel(
              current,
              event.wheel_delta,
              viewport_size,
              child_size,
            )
            if next == current {
              @core.ViewEventResult::ignored()
            } else {
              state.scroll_to(x=next.x, y=next.y)
              view_event_result(
                changed=true,
                captured=true,
                dirty=@core.ViewDirtyHint::ViewBuildDirty,
              )
            }
          }
          (None, Some(handler)) =>
            view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=[handler(event.wheel_delta)],
            )
          (None, None) => @core.ViewEventResult::ignored()
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn semantics_scroll_wheel_delta(
  direction : @core.SemanticsScrollDirection,
  viewport : @core.Size,
) -> @core.Point {
  let horizontal_step = view_max_double(40.0, viewport.width * 0.8)
  let vertical_step = view_max_double(40.0, viewport.height * 0.8)
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
  state : @core.ScrollState?,
  on_scroll : ((@core.Point) -> Msg)?,
) -> @core.ViewSemanticsActionResult[Msg] {
  if state is None && on_scroll is None {
    return @core.ViewSemanticsActionResult::rejected()
  }
  let viewport = node.viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport)
  let current = match state {
    Some(scroll_state) => scroll_state.offset()
    None => node.offset
  }
  let delta = semantics_scroll_wheel_delta(direction, viewport)
  let next = scroll_offset_after_wheel(current, delta, viewport, child_size)
  let messages = match on_scroll {
    Some(handler) => [handler(delta)]
    None => []
  }
  if next == current && messages.is_empty() {
    return @core.ViewSemanticsActionResult::rejected()
  }
  match state {
    Some(scroll_state) =>
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewBuildDirty,
        messages~,
        commit=Some(() => scroll_state.set_offset(next)),
      )
    None =>
      @core.ViewSemanticsActionResult::accepted(
        dirty=@core.ViewDirtyHint::ViewBuildDirty,
        messages~,
      )
  }
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
  let track_height = view_max_double(1.0, viewport_height - 8.0)
  let thumb_height = view_max_double(
    28.0,
    track_height * viewport_height / child_size.height,
  )
  let travel = view_max_double(0.0, track_height - thumb_height)
  let max_offset = view_max_double(1.0, child_size.height - viewport_height)
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
  offset~ : @core.Point,
  viewport~ : @core.Size?,
  state~ : @core.ScrollState?,
  on_scroll~ : ((@core.Point) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let viewport_size = viewport.unwrap_or(ctx.frame.size)
  let child_size = first_child_frame_size(ctx.child_frames, viewport_size)
  let current = scroll_clamp_offset(
    scroll_offset(offset, state),
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
    let track_height = view_max_double(1.0, viewport_size.height - 8.0)
    let thumb_height = view_max_double(
      28.0,
      track_height *
      viewport_size.height /
      view_max_double(viewport_size.height, child_size.height),
    )
    let travel = view_max_double(1.0, track_height - thumb_height)
    let ratio = clamp_view_double(
      (event.position.y - ctx.frame.origin.y - 4.0 - thumb_height / 2.0) /
      travel,
      0.0,
      1.0,
    )
    ratio * view_max_double(0.0, child_size.height - viewport_size.height)
  } else {
    current.y
  }
  match state {
    Some(state) => state.scroll_to(x=current.x, y=next_y)
    None => ()
  }
  {
    changed: should_move || next_state != ctx.state,
    activated: should_move && on_scroll is Some(_),
    focused: false,
    captured: true,
    state: Some(next_state),
    text_control: None,
    dirty: if state is Some(_) {
      @core.ViewDirtyHint::ViewBuildDirty
    } else {
      @core.ViewDirtyHint::ViewLayoutDirty
    },
    messages: match on_scroll {
      Some(handler) =>
        if should_move {
          [handler(@core.Point::new(x=0.0, y=current.y - next_y))]
        } else {
          []
        }
      None => []
    },
  }
}

///|
fn scroll_offset(
  offset : @core.Point,
  state : @core.ScrollState?,
) -> @core.Point {
  match state {
    Some(state) => state.offset()
    None => offset
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
    width=view_max_double(viewport.width, child_size.width),
    height=view_max_double(viewport.height, child_size.height),
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
  let max_x = view_max_double(0.0, child_size.width - viewport.width)
  let max_y = view_max_double(0.0, child_size.height - viewport.height)
  @core.Point::new(
    x=view_min_double(max_x, view_max_double(0.0, offset.x)),
    y=view_min_double(max_y, view_max_double(0.0, offset.y)),
  )
}
