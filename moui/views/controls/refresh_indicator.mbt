///|
/// Transient pointer state for a refresh pull: the drag origin and the damped
/// downward offset the pointer has pulled, in logical pixels. Runtime-owned
/// like the carousel's drag state. The offset is paint-only: the app-owned
/// `refreshing` state is the only thing that keeps the indicator alive past
/// the release, and the authoritative refresh signal is the `on_refresh`
/// message emitted once per armed release.
priv struct RefreshPull {
  active : Bool
  origin_y : Double
  raw_dy : Double
}

///|
impl @core.ViewStateValue for RefreshPull with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.RefreshPull.v1")
}

///|
impl @core.ViewStateValue for RefreshPull with fn encode_view_state(self) {
  let output = Buffer(size_hint=17)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_double_be(self.origin_y)
  output.write_double_be(self.raw_dy)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for RefreshPull with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 17 {
    None
  } else {
    match bytes[0] {
      0 | 1 =>
        match
          (
            @core.ViewStateValue::decode_view_state(0.0, bytes[1:9].to_owned()),
            @core.ViewStateValue::decode_view_state(0.0, bytes[9:17].to_owned()),
          ) {
          (Some(origin_y), Some(raw_dy)) =>
            Some({ active: bytes[0] == 1, origin_y, raw_dy, })
          _ => None
        }
      _ => None
    }
  }
}

///|
fn refresh_pull_slot() -> @core.ViewStateSlot[RefreshPull] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.refresh.pull"),
    initial={ active: false, origin_y: 0.0, raw_dy: 0.0, },
  )
}

///|
/// Concrete view node for the `refresh_indicator` control: the child is
/// clipped inside the surface and rides the pull offset; an arc indicator at
/// the top edge grows with the pull and spins while the app reports
/// `refreshing`.
priv struct RefreshIndicator {
  refreshing : Bool
  trigger_distance : Double
  width : Double
  height : Double
  theme : @core.Theme?
}

///|
impl @core.ViewNode for RefreshIndicator with fn identity(_self) {
  @core.ViewIdentity::new(kind="RefreshIndicator")
}

///|
impl @core.ViewNode for RefreshIndicator with fn child_constraints(
  _self,
  constraints,
) {
  constraints
}

///|
impl @core.ViewNode for RefreshIndicator with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
    child_frames=[
      @core.Rect::new(x=0.0, y=0.0, width=self.width, height=self.height),
    ],
    clips_children=true,
  )
}

///|
/// Damped pull offset: a raw downward travel reads through the same
/// saturating curve the scroll band uses, so a long pull approaches but never
/// passes one and a half trigger distances.
fn refresh_pull_offset(raw_dy : Double, trigger~ : Double) -> Double {
  let raw = raw_dy.max(0.0)
  let extent = trigger * 1.5
  if raw == 0.0 || extent <= 0.0 {
    0.0
  } else {
    raw * extent / (raw + extent)
  }
}

///|
/// The pull progress as a 0..1 fraction of the trigger distance.
fn refresh_pull_progress(pull : Double, trigger~ : Double) -> Double {
  if trigger <= 0.0 {
    0.0
  } else {
    (pull / trigger).clamp(min=0.0, max=1.0)
  }
}

///|
/// One arc sample of the refresh indicator, in surface-local coordinates
/// relative to the arc center.
fn refresh_arc_point(
  center_x~ : Double,
  center_y~ : Double,
  radius~ : Double,
  angle~ : Double,
) -> @core.Point {
  @core.Point::new(
    x=center_x + radius * @math.cos(angle),
    y=center_y + radius * @math.sin(angle),
  )
}

///|
/// Build the indicator arc as a stroked polyline path: `sweep` radians from
/// the twelve o'clock position, clockwise.
fn refresh_arc_path(
  center_x~ : Double,
  center_y~ : Double,
  radius~ : Double,
  sweep~ : Double,
  color~ : @core.Color,
) -> @core.PathSpec {
  let segments = 12
  let verbs : Array[@core.PathVerb] = [
    @core.PathVerb::MoveTo(
      refresh_arc_point(
        center_x~,
        center_y~,
        radius~,
        angle=0.0 - @math.PI / 2.0,
      ),
    ),
  ]
  for index in 1..<=segments {
    verbs.push(
      @core.PathVerb::LineTo(
        refresh_arc_point(
          center_x~,
          center_y~,
          radius~,
          angle=0.0 -
            @math.PI / 2.0 +
            sweep * index.to_double() / segments.to_double(),
        ),
      ),
    )
  }
  {
    verbs,
    fill: None,
    stroke: Some(@core.Brush::Solid(color)),
    stroke_width: 2.5,
  }
}

///|
impl @core.ViewNode for RefreshIndicator with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let pull = ctx.state.read_slot(refresh_pull_slot())
  let offset = if pull.active {
    refresh_pull_offset(pull.raw_dy, trigger=self.trigger_distance)
  } else {
    0.0
  }
  let commands : Array[@core.DrawCommand] = []
  let post_commands : Array[@core.DrawCommand] = []
  if offset != 0.0 {
    commands.push(
      PushTransform(@core.Transform2D::translation(dx=0.0, dy=offset)),
    )
    post_commands.push(PopTransform)
  }
  // The indicator band rides above the content: visible while refreshing,
  // growing with the pull otherwise. While refreshing the sweep rotates with
  // the paint clock, and the animating latch below keeps the host ticking.
  let indicator_visible = self.refreshing || offset > 0.0
  if indicator_visible {
    let progress = if self.refreshing {
      1.0
    } else {
      refresh_pull_progress(offset, trigger=self.trigger_distance)
    }
    let spin = if self.refreshing { ctx.now_ms / 1000.0 } else { 0.0 }
    let sweep = (progress * 4.5).max(0.6) + spin * (2.0 * @math.PI)
    commands.push(
      FillRect(
        @core.Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=ctx.frame.size.width,
          height=36.0,
        ),
        resolved_theme.palette.primary.with_alpha(0.12),
      ),
    )
    let stroke_color = match resolved_theme.scheme {
      Light => resolved_theme.palette.primary
      Dark => resolved_theme.palette.on_primary
    }
    commands.push(
      DrawPath(
        refresh_arc_path(
          center_x=ctx.frame.origin.x + ctx.frame.size.width / 2.0,
          center_y=ctx.frame.origin.y + 22.0,
          radius=9.0,
          sweep~,
          color=stroke_color,
        ),
      ),
    )
  }
  {
    commands,
    child_layers: [],
    post_commands,
    overlay_commands: [],
    repaint_boundary: false,
    animating: self.refreshing,
  }
}

///|
impl @core.ViewNode for RefreshIndicator with fn semantics(self) {
  @core.ViewSemanticsInfo::container(
    composition=Boundary,
    role=Group,
    value=if self.refreshing { "refreshing" } else { "pull to refresh" },
  )
}

///|
fn[Msg] refresh_pull_event(
  node : RefreshIndicator,
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
  on_refresh : Msg,
) -> @core.ViewEventResult[Msg] {
  let slot = refresh_pull_slot()
  let pull = ctx.state.read_slot(slot)
  match event.phase {
    // Primary button only; a refreshing surface takes no new pull.
    Down =>
      if !node.refreshing &&
        event.button == 0 &&
        ctx.frame.contains(event.position) {
        {
          ..@core.ViewEventResult::ignored(),
          captured: true,
          state: Some(
            ctx.state.with_slot(slot, {
              active: true,
              origin_y: event.position.y,
              raw_dy: 0.0,
            }),
          ),
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    Move =>
      if pull.active {
        let raw_dy = (event.position.y - pull.origin_y).max(0.0)
        let offset = refresh_pull_offset(raw_dy, trigger=node.trigger_distance)
        if offset != pull.raw_dy {
          {
            ..@core.ViewEventResult::ignored(),
            changed: true,
            captured: true,
            state: Some(ctx.state.with_slot(slot, { ..pull, raw_dy: offset, })),
            dirty: ViewPaintDirty,
          }
        } else {
          @core.ViewEventResult::ignored()
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    Up | Cancel | Exit =>
      if pull.active {
        let armed = pull.raw_dy >= node.trigger_distance
        {
          ..@core.ViewEventResult::ignored(),
          changed: true,
          activated: armed,
          captured: true,
          state: Some(ctx.state.without_slot(slot)),
          dirty: ViewPaintDirty,
          messages: if armed && event.phase == Up {
            [on_refresh]
          } else {
            []
          },
        }
      } else {
        @core.ViewEventResult::ignored()
      }
  }
}

///|
/// A pull-to-refresh surface: the child content rides a damped downward pull,
/// an arc indicator grows toward the trigger distance, and an armed release
/// emits `on_refresh` exactly once — the app flips `refreshing` to true and
/// back, and the indicator spins (and latches frames) while it lasts.
///
/// The pull gesture is observed on this surface's own pointer stream. A nested
/// child that claims pointer capture (a `scroll_view` drag) owns the stream
/// and the wrapper observes nothing; composing the scrollable *inside* the
/// child view or triggering the refresh through semantics is the supported
/// shape until the runtime bubbles scroll-ancestor streams to refresh
/// observers.
pub fn[Msg] refresh_indicator(
  refreshing~ : Bool,
  on_refresh~ : Msg,
  child~ : @core.View[Msg],
  theme? : @core.Theme,
  trigger_distance~ : Double = 64.0,
  width~ : Double = 300.0,
  height~ : Double = 400.0,
) -> @core.View[Msg] {
  let node = RefreshIndicator::{
    refreshing,
    trigger_distance,
    width,
    height,
    theme,
  }
  @core.View::from_node(
    node,
    children=_node => [child],
    event=(node, ctx) => {
      match ctx.event {
        Pointer(event) => refresh_pull_event(node, ctx, event, on_refresh)
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::activate(_ctx => {
          if node.refreshing {
            @core.ViewSemanticsActionResult::rejected()
          } else {
            @core.ViewSemanticsActionResult::accepted(messages=[on_refresh])
          }
        }),
      ]
    },
  )
}
