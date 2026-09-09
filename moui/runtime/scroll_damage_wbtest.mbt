///|
/// Regression for the scrolled-image ghost: the scroll-bearing editor
/// element is paint-dirty itself and owns same-element-id ViewPaintLayer
/// children in the render tree. A small sibling (a scroll indicator) marked
/// dirty in the same pass used to be the only damage rect, because the
/// ancestor's own bounds were skipped whenever any dirty descendant existed.
/// The frame must instead damage the scrolled area, or previous-frame image
/// pixels survive outside the small rect.
fn scroll_damage_pointer_event(x : Double, y : Double) -> @core.AppEvent {
  @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x~, y~),
      phase=@core.PointerPhase::Move,
    ),
  )
}

///|
test "damage covers a paint-dirty ancestor even with a dirty sibling" {
  let scroll = Ref(0)
  let hovered = Ref(false)
  let editor : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="ScrollDamageEditor"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=16.0, height=8.0)),
      )
    },
    paint=ctx => {
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::FillRect(
          ctx.frame,
          if scroll.val % 2 == 0 {
            @core.Color::black()
          } else {
            @core.Color::gray()
          },
        ),
      ]
      // Same-id child layers exactly like the rich-text editor's block
      // window, which is what made the old descendant check fire for the
      // editor element on every scroll frame.
      {
        commands: [],
        child_layers: [
          @core.ViewPaintLayer::new(
            frame=ctx.frame,
            cache_key="scroll-damage-layer",
            content_revision=1,
            commands~,
          ),
        ],
        post_commands: [],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Move &&
            ctx.frame.contains(event.position) {
            scroll.val = scroll.val + 1
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              dirty: @core.ViewDirtyHint::ViewPaintDirty,
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
  let indicator : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="ScrollDamageIndicator"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=8.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(
          ctx.frame,
          if hovered.val {
            @core.Color::black()
          } else {
            @core.Color::white()
          },
        ),
      ])
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Move &&
            ctx.frame.contains(event.position) {
            hovered.val = !hovered.val
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              dirty: @core.ViewDirtyHint::ViewPaintDirty,
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
  let stage : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="ScrollDamageStage"),
    children=() => [editor, indicator],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=24.0, height=8.0)),
        child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=8.0),
          @core.Rect::new(x=16.0, y=0.0, width=8.0, height=8.0),
        ],
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::white()),
      ])
    },
  )
  let runtime = AppRuntime::new_view(
    root=stage,
    size=@core.Size::new(width=40.0, height=40.0),
  )
  let first = runtime.draw_frame()
  assert_true(first.damage is @core.DamageRegion::FullSurface(_))
  // Scroll the editor and dirty the indicator in the same paint pass. The
  // combined surface union stays far below the full-surface threshold, so
  // the resolved damage must be explicit rects.
  runtime.dispatch_event(scroll_damage_pointer_event(8.0, 4.0))
  runtime.dispatch_event(scroll_damage_pointer_event(20.0, 4.0))
  let scrolled = runtime.draw_frame()
  match scrolled.damage {
    @core.DamageRegion::Rects(rects) => {
      // The old ancestor-skip left only the indicator's rect. The editor
      // area must be covered by damage so previous-frame pixels there are
      // cleared (or fully overwritten by the frame contract).
      let point = @core.Point::new(x=1.0, y=1.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(point)))
      let indicator_point = @core.Point::new(x=20.0, y=4.0)
      assert_true(
        rects.any(rect => rect.inflate(1.0).contains(indicator_point)),
      )
    }
    @core.DamageRegion::FullSurface(_) => ()
    @core.DamageRegion::Empty => fail("scroll frame must not be empty")
  }
}
