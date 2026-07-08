///|
fn runtime_test_cached_layer_source(
  layer_index : @core.State[Int],
) -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="RuntimeCachedLayerSource"),
    revision=() => "runtime-cached-layer-source",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=12.0, height=12.0)),
      )
    },
    paint=ctx => {
      let index = layer_index.get()
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::FillRect(ctx.frame, @core.Color::black()),
      ]
      {
        commands: [],
        child_layers: [
          @core.ViewPaintLayer::new(
            frame=ctx.frame,
            cache_key="runtime-test-layer-\{index}",
            content_revision=index,
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
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if ctx.frame.contains(event.position) {
            layer_index.set(layer_index.get() + 1)
            @core.ViewEventResult::message(())
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn runtime_test_stable_cached_layer_source(
  revision : @core.State[Int],
) -> @core.View[Unit] {
  @core.View::node(
    identity=() => {
      @core.ViewIdentity::new(kind="RuntimeStableCachedLayerSource")
    },
    revision=() => "runtime-stable-cached-layer-source",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=12.0, height=12.0)),
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
            cache_key="runtime-stable-test-layer",
            content_revision=revision.get(),
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
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if ctx.frame.contains(event.position) {
            revision.set(revision.get() + 1)
            @core.ViewEventResult::message(())
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn runtime_test_begin_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::BeginCachedLayer(_))
  .length()
}

///|
fn runtime_test_draw_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::DrawCachedLayer(_))
  .length()
}

///|
fn runtime_test_bump_cached_layer_revision(runtime : AppRuntime) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=4.0, y=4.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
}

///|
test "runtime cached layer tracking is frame scoped for transient layers" {
  let layer_index = @core.State::new(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_cached_layer_source(layer_index),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  for _ in 0..<176 {
    ignore(runtime.draw_frame())
    runtime_test_bump_cached_layer_revision(runtime)
  }
  let frame = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(frame.commands), content="0")
  inspect(runtime_test_draw_cached_layer_count(frame.commands), content="0")
  let count = runtime
    .inspector_snapshot()
    .runtime()
    .dirty_state()
    .cached_layer_count()
  inspect(count, content="0")
}

///|
test "runtime cached layer warms up before admission" {
  let revision = @core.State::new(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_stable_cached_layer_source(revision),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  let first = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(first.commands), content="0")
  inspect(runtime_test_draw_cached_layer_count(first.commands), content="0")
  let second = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(second.commands), content="0")
  inspect(runtime_test_draw_cached_layer_count(second.commands), content="0")
  let third = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(third.commands), content="1")
  inspect(runtime_test_draw_cached_layer_count(third.commands), content="0")
  let fourth = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(fourth.commands), content="0")
  inspect(runtime_test_draw_cached_layer_count(fourth.commands), content="1")
}

///|
test "runtime cached layer revision change resets warmup" {
  let revision = @core.State::new(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_stable_cached_layer_source(revision),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  inspect(
    runtime_test_draw_cached_layer_count(runtime.draw_frame().commands),
    content="1",
  )
  runtime_test_bump_cached_layer_revision(runtime)
  let first_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(first_changed.commands),
    content="0",
  )
  inspect(
    runtime_test_draw_cached_layer_count(first_changed.commands),
    content="0",
  )
  let second_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(second_changed.commands),
    content="0",
  )
  inspect(
    runtime_test_draw_cached_layer_count(second_changed.commands),
    content="0",
  )
  let third_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(third_changed.commands),
    content="1",
  )
  inspect(
    runtime_test_draw_cached_layer_count(third_changed.commands),
    content="0",
  )
  let fourth_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(fourth_changed.commands),
    content="0",
  )
  inspect(
    runtime_test_draw_cached_layer_count(fourth_changed.commands),
    content="1",
  )
}
