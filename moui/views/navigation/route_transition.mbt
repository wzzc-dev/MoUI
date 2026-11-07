///|
/// The visual style of an automatic route transition.
pub(all) enum RouteTransitionKind {
  Slide
  Fade
  Scale
}

///|
/// Automatic push/pop transition parameters for `router_stack` and
/// `navigation_stack_selected`. The node samples the clock itself: a route
/// change observed on a frame tick stamps the start time, the paint pass
/// interpolates until the duration elapses, and the animation latch keeps the
/// host ticking for exactly that window. `none()` keeps the instant swap.
pub struct RouteTransition {
  kind : RouteTransitionKind
  duration_ms : Double
}

///|
pub fn route_transition_slide(duration_ms~ : Double = 220.0) -> RouteTransition {
  { kind: Slide, duration_ms: duration_ms.max(0.0), }
}

///|
pub fn route_transition_fade(duration_ms~ : Double = 180.0) -> RouteTransition {
  { kind: Fade, duration_ms: duration_ms.max(0.0), }
}

///|
pub fn route_transition_scale(duration_ms~ : Double = 180.0) -> RouteTransition {
  { kind: Scale, duration_ms: duration_ms.max(0.0), }
}

///|
pub fn route_transition_none() -> RouteTransition {
  { kind: Slide, duration_ms: 0.0, }
}

///|
/// Whether a transition moves, and which way: a growing route stack pushes
/// (the incoming page enters from the trailing edge), a shrinking stack pops
/// (it enters from the leading edge), and a same-length top swap crossfades
/// with no directional offset.
pub fn route_transition_direction(
  previous_count~ : Int32,
  next_count~ : Int32,
) -> Int32 {
  if next_count > previous_count {
    0
  } else if next_count < previous_count {
    1
  } else {
    2
  }
}

///|
/// Runtime-owned stamp of the last observed route change: the top route and
/// stack depth the transition started FROM (the previous values), the clock
/// time it started at, and the direction. Written by the frame-tick handler
/// the first time a tick observes the node's route differing from the stamp —
/// the paint pass solicits that tick by latching while unstamped.
priv struct RouteTransitionStamp {
  previous_route : String
  count : Int32
  started_ms : Double
  direction : Int32
}

///|
impl @core.ViewStateValue for RouteTransitionStamp with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.RouteTransitionStamp.v1")
}

///|
impl @core.ViewStateValue for RouteTransitionStamp with fn encode_view_state(
  self,
) {
  let route_bytes = @utf8.encode(self.previous_route[:], bom=false)
  let output = Buffer(size_hint=17 + route_bytes.length())
  output.write_int_be(route_bytes.length())
  output.write_bytes(route_bytes[:])
  output.write_int_be(self.count)
  output.write_double_be(self.started_ms)
  output.write_int_be(self.direction)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for RouteTransitionStamp with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() < 17 {
    None
  } else {
    let route_length = @core.ViewStateValue::decode_view_state(
      0,
      bytes[0:4].to_owned(),
    ).unwrap_or(0)
    if route_length < 0 || bytes.length() < 17 + route_length {
      None
    } else {
      let route = @utf8.decode_lossy(
        bytes[4:4 + route_length].to_owned(),
        ignore_bom=false,
      )
      match
        (
          @core.ViewStateValue::decode_view_state(
            0,
            bytes[4 + route_length:8 + route_length].to_owned(),
          ),
          @core.ViewStateValue::decode_view_state(
            0.0,
            bytes[8 + route_length:16 + route_length].to_owned(),
          ),
          @core.ViewStateValue::decode_view_state(
            0,
            bytes[16 + route_length:20 + route_length].to_owned(),
          ),
        ) {
        (Some(count), Some(started_ms), Some(direction)) =>
          Some({ previous_route: route, count, started_ms, direction, })
        _ => None
      }
    }
  }
}

///|
fn route_transition_stamp_slot() -> @core.ViewStateSlot[RouteTransitionStamp] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.route.transition"),
    initial={ previous_route: "", count: 0 - 1, started_ms: 0.0, direction: 0, },
  )
}

///|
/// Concrete view node wrapping a router stack's resolved page: detects route
/// changes on frame ticks, stamps the transition, and paints the enter
/// interpolation until the duration elapses.
priv struct RouteStackTransition {
  top_route : String
  route_count : Int32
  transition : RouteTransition
}

///|
impl @core.ViewNode for RouteStackTransition with fn identity(_self) {
  @core.ViewIdentity::new(kind="RouteStackTransition")
}

///|
impl @core.ViewNode for RouteStackTransition with fn child_constraints(
  _self,
  constraints,
) {
  constraints
}

///|
impl @core.ViewNode for RouteStackTransition with fn layout(_self, ctx) {
  let child_size = match ctx.child_sizes {
    [size, ..] => size
    [] => @core.Size::new(width=0.0, height=0.0)
  }
  let size = ctx.constraints.constrain(child_size)
  @core.ViewLayoutResult::new(size~, child_frames=[
    @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
  ])
}

///|
/// Whether the stamp disagrees with the node's current route: the pending
/// state a paint pass latches on so the next frame tick stamps it.
fn route_transition_pending(
  node : RouteStackTransition,
  stamp : RouteTransitionStamp,
) -> Bool {
  stamp.previous_route != node.top_route || stamp.count != node.route_count
}

///|
/// The paint-time interpolation state: the eased 0..1 progress and whether
/// frames must keep ticking.
fn route_transition_paint_state(
  node : RouteStackTransition,
  stamp : RouteTransitionStamp,
  now_ms~ : Double,
) -> (Double, Bool) {
  if route_transition_pending(node, stamp) || node.transition.duration_ms <= 0.0 {
    // Unstamped changes paint settled and solicit a stamping tick; a zero
    // duration is an instant swap.
    return (1.0, route_transition_pending(node, stamp))
  }
  let elapsed = now_ms - stamp.started_ms
  if elapsed < 0.0 {
    return (0.0, true)
  }
  let raw = (elapsed / node.transition.duration_ms).clamp(min=0.0, max=1.0)
  let eased = @core.Easing::EaseInOut.sample(raw)
  (eased, raw < 1.0)
}

///|
impl @core.ViewNode for RouteStackTransition with fn paint(self, ctx) {
  let stamp = ctx.state.read_slot(route_transition_stamp_slot())
  let (progress, animating) = route_transition_paint_state(
    self,
    stamp,
    now_ms=ctx.now_ms,
  )
  let commands : Array[@core.DrawCommand] = []
  let post_commands : Array[@core.DrawCommand] = []
  // Enter style per direction and kind. The outgoing page is not replayed —
  // only the incoming page interpolates (an enter-only transition; a paired
  // exit ghost is follow-up work).
  if animating && progress < 1.0 {
    let direction = if route_transition_pending(self, stamp) {
      2
    } else {
      stamp.direction
    }
    match self.transition.kind {
      Slide =>
        if direction == 2 {
          commands.push(PushOpacity(progress))
          post_commands.push(PopOpacity)
        } else {
          let dx = if direction == 0 {
            (1.0 - progress) * ctx.frame.size.width
          } else {
            0.0 - (1.0 - progress) * ctx.frame.size.width
          }
          commands.push(
            PushTransform(@core.Transform2D::translation(dx~, dy=0.0)),
          )
          post_commands.push(PopTransform)
        }
      Fade => {
        commands.push(PushOpacity(progress))
        post_commands.push(PopOpacity)
      }
      Scale => {
        // Scale about the frame center: T(c) * S * T(-c).
        let sx = 0.92 + 0.08 * progress
        let cx = ctx.frame.origin.x + ctx.frame.size.width / 2.0
        let cy = ctx.frame.origin.y + ctx.frame.size.height / 2.0
        commands.push(
          PushTransform({
            a: sx,
            b: 0.0,
            c: 0.0,
            d: sx,
            tx: cx - sx * cx,
            ty: cy - sx * cy,
          }),
        )
        commands.push(PushOpacity(progress))
        post_commands.push(PopOpacity)
        post_commands.push(PopTransform)
      }
    }
  }
  {
    commands,
    child_layers: [],
    post_commands,
    overlay_commands: [],
    repaint_boundary: false,
    animating,
  }
}

///|
fn[Msg] route_stack_transition_event(
  node : RouteStackTransition,
  context : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match context.event {
    FrameTick(frame) => {
      let slot = route_transition_stamp_slot()
      let stamp = context.state.read_slot(slot)
      if route_transition_pending(node, stamp) {
        let direction = route_transition_direction(
          previous_count=stamp.count,
          next_count=node.route_count,
        )
        {
          ..@core.ViewEventResult::ignored(),
          changed: true,
          state: Some(
            context.state.with_slot(slot, {
              previous_route: node.top_route,
              count: node.route_count,
              started_ms: frame.time_ms,
              direction,
            }),
          ),
          dirty: ViewPaintDirty,
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] route_stack_transition_view(
  inner : @core.View[Msg],
  top_route~ : String,
  route_count~ : Int32,
  transition~ : RouteTransition,
) -> @core.View[Msg] {
  @core.View::from_node(
    RouteStackTransition::{ top_route, route_count, transition, },
    children=_node => [inner],
    event=(node, context) => route_stack_transition_event(node, context),
  )
}
