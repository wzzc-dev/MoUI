///|
test "runtime draw frame separates clear color from content commands" {
  let root : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="DrawFrameContract"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=12.0, height=8.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::black()),
      ])
    },
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=12.0, height=8.0),
  )
  let frame = runtime.draw_frame()
  assert_true(frame.clear_color == @core.Color::white())
  assert_true(frame.overlay_bounds is None)
  assert_false(
    frame.commands.any(command => command is @core.DrawCommand::Clear(_)),
  )
  assert_true(
    frame.commands.any(command => command is @core.DrawCommand::FillRect(_, _)),
  )
  let legacy = runtime.draw_commands()
  assert_true(legacy[0] is @core.DrawCommand::Clear(_))
}

///|
test "runtime draw frame exposes view overlay paint bounds" {
  let overlay = @core.Rect::new(x=20.0, y=14.0, width=30.0, height=20.0)
  let root : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="DrawFrameOverlayContract"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=80.0, height=60.0)),
      )
    },
    paint=_ctx => {
      commands: [],
      child_layers: [],
      post_commands: [],
      overlay_commands: [
        @core.DrawCommand::FillRect(overlay, @core.Color::black()),
      ],
      repaint_boundary: false,
      animating: false,
    },
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=80.0, height=60.0),
  )
  let frame = runtime.draw_frame()
  assert_true(
    frame.overlay_bounds ==
    Some(@core.Rect::new(x=19.0, y=13.0, width=32.0, height=22.0)),
  )
  assert_true(frame.clear_color == @core.Color::white())
}

///|
test "runtime keeps a full-surface platform presenter transparent" {
  let root : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="FullSurfacePlatformView"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=80.0, height=60.0)),
      )
    },
    platform_views=ctx => {
      [
        @core.PlatformViewPlacement::new(
          id="full-surface",
          kind="test",
          frame=ctx.frame,
        ),
      ]
    },
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=80.0, height=60.0),
  )
  assert_true(
    runtime.draw_frame().clear_color ==
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  )
}

///|
test "runtime keeps a partial platform presenter opaque" {
  let root : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PartialPlatformView"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=80.0, height=60.0)),
      )
    },
    platform_views=_ctx => {
      [
        @core.PlatformViewPlacement::new(
          id="partial",
          kind="test",
          frame=@core.Rect::new(x=10.0, y=10.0, width=40.0, height=30.0),
        ),
      ]
    },
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=80.0, height=60.0),
  )
  assert_true(runtime.draw_frame().clear_color == @core.Color::white())
}
