///|
/// Transient pointer state for a carousel swipe: the drag origin and the raw
/// horizontal offset the pointer has pulled, in logical pixels. Runtime-owned
/// like the scroll container's drag state, so the swipe survives the rebuild
/// an `on_page_change` rebuild triggers. The offset is paint-only: the
/// authoritative page changes on release, never mid-drag.
priv struct CarouselDrag {
  active : Bool
  origin_x : Double
  raw_dx : Double
}

///|
impl @core.ViewStateValue for CarouselDrag with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.CarouselDrag.v1")
}

///|
impl @core.ViewStateValue for CarouselDrag with fn encode_view_state(self) {
  let output = Buffer(size_hint=17)
  output.write_byte(if self.active { 1 } else { 0 })
  output.write_double_be(self.origin_x)
  output.write_double_be(self.raw_dx)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for CarouselDrag with fn decode_view_state(
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
          (Some(origin_x), Some(raw_dx)) =>
            Some({ active: bytes[0] == 1, origin_x, raw_dx, })
          _ => None
        }
      _ => None
    }
  }
}

///|
fn carousel_drag_slot() -> @core.ViewStateSlot[CarouselDrag] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.carousel.drag"),
    initial={ active: false, origin_x: 0.0, raw_dx: 0.0, },
  )
}

///|
/// Concrete view node for the `carousel` control: one swipeable surface
/// showing the current page (plus the neighbors laid out off-screen so a
/// drag slides into them), a dots indicator, and page-flip semantics.
priv struct Carousel {
  page : Int32
  count : Int32
  width : Double
  height : Double
  theme : @core.Theme?
}

///|
impl @core.ViewNode for Carousel with fn identity(_self) {
  @core.ViewIdentity::new(kind="Carousel")
}

///|
impl @core.ViewNode for Carousel with fn child_constraints(_self, constraints) {
  constraints
}

///|
impl @core.ViewNode for Carousel with fn layout(self, ctx) {
  let viewport = ctx.constraints.constrain(
    @core.Size::new(width=self.width, height=self.height),
  )
  // Windowed placement: the current page sits at x=0; its neighbors sit one
  // viewport width to each side, outside the clipped surface, so a drag
  // slides real content in instead of an empty gap.
  let child_count = ctx.child_sizes.length()
  let first_page = self.page - (if self.page > 0 { 1 } else { 0 })
  let frames : Array[@core.Rect] = []
  for index in 0..<child_count {
    let page = first_page + index
    frames.push(
      @core.Rect::new(
        x=(page - self.page).to_double() * viewport.width,
        y=0.0,
        width=viewport.width,
        height=viewport.height,
      ),
    )
  }
  @core.ViewLayoutResult::new(
    size=viewport,
    child_frames=frames,
    clips_children=true,
  )
}

///|
impl @core.ViewNode for Carousel with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let drag = ctx.state.read_slot(carousel_drag_slot())
  let dx = if drag.active { drag.raw_dx } else { 0.0 }
  let commands : Array[@core.DrawCommand] = []
  let post_commands : Array[@core.DrawCommand] = []
  if dx != 0.0 {
    commands.push(PushTransform(@core.Transform2D::translation(dx~, dy=0.0)))
    post_commands.push(PopTransform)
  }
  // Dots indicator along the bottom edge; a page count past ten reads its
  // position from the semantics value instead of an unreadable dot row.
  if self.count <= 10 {
    let dot = 6.0
    let gap = 6.0
    let total = self.count.to_double() * dot +
      (self.count - 1).to_double().max(0.0) * gap
    let start_x = ctx.frame.origin.x + (ctx.frame.size.width - total) / 2.0
    let y = ctx.frame.origin.y + ctx.frame.size.height - dot - 6.0
    for index in 0..<self.count {
      let active = index == self.page
      let size = if active { dot + 2.0 } else { dot }
      let offset = index.to_double() * (dot + gap) -
        (if active { 1.0 } else { 0.0 })
      commands.push(
        FillRoundedRect(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=start_x + offset,
              y=y - (if active { 1.0 } else { 0.0 }),
              width=size,
              height=size,
            ),
            radius=size / 2.0,
          ),
          if active {
            resolved_theme.palette.primary
          } else {
            resolved_theme.palette.outline
          },
        ),
      )
    }
  }
  {
    commands,
    child_layers: [],
    post_commands,
    overlay_commands: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for Carousel with fn semantics(self) {
  @core.ViewSemanticsInfo::container(
    composition=Boundary,
    role=ScrollView,
    value="page \{self.page + 1} of \{self.count}",
  )
}

///|
/// Clamp a raw drag offset to the directions pages actually exist in: at the
/// first page a rightward pull shows nothing, at the last a leftward pull
/// shows nothing.
fn carousel_bounded_dx(
  raw_dx : Double,
  page : Int32,
  count : Int32,
  viewport_width~ : Double,
) -> Double {
  let mut bounded = raw_dx.clamp(min=0.0 - viewport_width, max=viewport_width)
  if page == 0 {
    bounded = bounded.min(0.0)
  }
  if page >= count - 1 {
    bounded = bounded.max(0.0)
  }
  bounded
}

///|
/// The page a release lands on: a drag past a third of the viewport flips one
/// page in the drag direction, anything shorter snaps back.
fn carousel_release_page(
  raw_dx : Double,
  page : Int32,
  count : Int32,
  viewport_width~ : Double,
) -> Int32 {
  if raw_dx.abs() > viewport_width / 3.0 {
    let next = if raw_dx < 0.0 { page + 1 } else { page - 1 }
    next.clamp(min=0, max=count - 1)
  } else {
    page
  }
}

///|
fn[Msg] carousel_drag_event(
  node : Carousel,
  ctx : @core.ViewEventContext,
  event : @core.PointerEvent,
  on_page_change : (Int32) -> Msg,
) -> @core.ViewEventResult[Msg] {
  let slot = carousel_drag_slot()
  let drag = ctx.state.read_slot(slot)
  let viewport_width = node.width
  match event.phase {
    // Primary button only: secondary presses belong to context menus.
    Down =>
      if event.button == 0 && ctx.frame.contains(event.position) {
        {
          ..@core.ViewEventResult::ignored(),
          captured: true,
          state: Some(
            ctx.state.with_slot(slot, {
              active: true,
              origin_x: event.position.x,
              raw_dx: 0.0,
            }),
          ),
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    Move =>
      if drag.active {
        let raw_dx = carousel_bounded_dx(
          event.position.x - drag.origin_x,
          node.page,
          node.count,
          viewport_width~,
        )
        let moved = raw_dx != drag.raw_dx
        if moved {
          {
            ..@core.ViewEventResult::ignored(),
            changed: true,
            captured: true,
            state: Some({ ..ctx.state.with_slot(slot, { ..drag, raw_dx, }), }),
            dirty: ViewPaintDirty,
          }
        } else {
          @core.ViewEventResult::ignored()
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    Up | Cancel | Exit =>
      if drag.active {
        let raw_dx = carousel_bounded_dx(
          event.position.x - drag.origin_x,
          node.page,
          node.count,
          viewport_width~,
        )
        let next = carousel_release_page(
          raw_dx,
          node.page,
          node.count,
          viewport_width~,
        )
        let moved = next != node.page
        {
          ..@core.ViewEventResult::ignored(),
          changed: true,
          activated: moved,
          captured: true,
          state: Some(ctx.state.without_slot(slot)),
          dirty: ViewPaintDirty,
          messages: if moved {
            [on_page_change(next)]
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
/// A swipeable page surface: shows the page the app declares, lets a
/// horizontal drag pull the neighbors in (paint-only, bounded), and flips one
/// page per release past a third of the viewport. Vertically the surface is
/// not a scroller — nested scrolling belongs to the page content.
pub fn[Msg] carousel(
  page_count : Int32,
  page : Int32,
  on_page_change~ : (Int32) -> Msg,
  builder~ : (Int32) -> @core.View[Msg],
  theme? : @core.Theme,
  width~ : Double = 300.0,
  height~ : Double = 180.0,
) -> @core.View[Msg] {
  let count = if page_count < 1 { 1 } else { page_count }
  let resolved_page = page.clamp(min=0, max=count - 1)
  let node = Carousel::{ page: resolved_page, count, width, height, theme, }
  @core.View::from_node(
    node,
    children=_node => {
      // Windowed pages: previous, current, next — neighbors only exist at
      // interior pages, and the layout pass places each at its page offset.
      let views : Array[@core.View[Msg]] = []
      if resolved_page > 0 {
        views.push(builder(resolved_page - 1))
      }
      views.push(builder(resolved_page))
      if resolved_page + 1 < count {
        views.push(builder(resolved_page + 1))
      }
      views
    },
    event=(node, ctx) => {
      match ctx.event {
        Pointer(event) => carousel_drag_event(node, ctx, event, on_page_change)
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics_actions=node => {
      [
        @core.ViewSemanticsActionHandler::scroll((_ctx, direction) => {
          let next = match direction {
            Forward | Right => node.page + 1
            Backward | Left => node.page - 1
            Up | Down => node.page
          }
          if next == node.page || next < 0 || next >= node.count {
            @core.ViewSemanticsActionResult::rejected()
          } else {
            @core.ViewSemanticsActionResult::accepted(messages=[
              on_page_change(next),
            ])
          }
        }),
      ]
    },
  )
}
