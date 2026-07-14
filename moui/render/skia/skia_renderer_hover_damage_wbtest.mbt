///|
fn skia_hover_damage_cached_content() -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="SkiaHoverCachedContent"),
    revision=() => "skia-hover-cached-content",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=8.0)),
      )
    },
    paint=ctx => {
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::black()),
      ]
      {
        commands: [],
        child_layers: [
          @core.ViewPaintLayer::new(
            frame=ctx.frame,
            cache_key="skia-hover-cached-layer",
            content_revision=1,
            commands~,
          ),
        ],
        post_commands: [],
        overlay_commands: [],
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  )
}

///|
fn skia_hover_damage_control() -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="SkiaHoverControl"),
    revision=() => "skia-hover-control",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=8.0, height=8.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(
          ctx.frame,
          if ctx.state.hovered {
            @core.Color::black()
          } else {
            @core.Color::gray()
          },
        ),
      ])
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) => {
          let hovered = event.phase == @core.PointerPhase::Move &&
            ctx.frame.contains(event.position)
          if hovered != ctx.state.hovered {
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              captured: true,
              state: Some({ ..ctx.state, hovered, }),
              dirty: @core.ViewDirtyHint::ViewPaintDirty,
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn skia_hover_damage_stage() -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="SkiaHoverDamageStage"),
    revision=() => "skia-hover-damage-stage",
    children=() => {
      [skia_hover_damage_cached_content(), skia_hover_damage_control()]
    },
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=24.0, height=8.0)),
        child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
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
}

///|
test "skia hover damage preserves cached sibling pixels" {
  guard skia_available() else { return () }
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=8.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let runtime = @runtime.AppRuntime::new_view(
    root=skia_hover_damage_stage(),
    size=@core.Size::new(width=24.0, height=8.0),
  )
  for _ in 0..<4 {
    let result = renderer.render_frame(runtime.draw_frame())
    assert_true(result.presented)
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=4.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  let hover_frame = runtime.draw_frame()
  assert_true(hover_frame.damage is @core.DamageRegion::Rects(_))
  assert_false(
    hover_frame.commands.any(command => command is @core.DrawCommand::Clear(_)),
  )
  assert_true(
    hover_frame.commands.any(command => {
      command is @core.DrawCommand::DrawCachedLayer(_)
    }),
  )
  let hover_result = renderer.render_frame(hover_frame)
  assert_true(hover_result.presented)
  guard renderer.last_frame() is Some(pixels) else {
    fail("expected hover frame pixels")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      pixels,
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
    ),
  )
}
