///|
fn runtime_test_cached_layer_source(
  layer_index : Ref[Int],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="RuntimeCachedLayerSource"),
    declaration=() => @core.ViewDeclaration::uncacheable(),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=12.0, height=12.0)),
      )
    },
    paint=ctx => {
      let index = layer_index.val
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
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if ctx.frame.contains(event.position) {
            layer_index.val = layer_index.val + 1
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
  revision : Ref[Int],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(kind="RuntimeStableCachedLayerSource")
    },
    declaration=() => @core.ViewDeclaration::uncacheable(),
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
            content_revision=revision.val,
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
          if ctx.frame.contains(event.position) {
            revision.val = revision.val + 1
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
  .filter(command => command is @core.DrawCommand::BeginRetainedLayer(_))
  .length()
}

///|
fn runtime_test_retained_payload_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  commands
  .filter(command => command is @core.DrawCommand::FillRect(_, _))
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
test "runtime retained layer declarations are frame scoped" {
  let layer_index = Ref(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_cached_layer_source(layer_index),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  for _ in 0..<176 {
    ignore(runtime.draw_frame())
    runtime_test_bump_cached_layer_revision(runtime)
  }
  let frame = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(frame.commands), content="1")
  inspect(runtime_test_retained_payload_count(frame.commands), content="1")
}

///|
test "runtime retained layer payload is complete on every frame" {
  let revision = Ref(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_stable_cached_layer_source(revision),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  let first = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(first.commands), content="1")
  inspect(runtime_test_retained_payload_count(first.commands), content="1")
  let second = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(second.commands), content="1")
  inspect(runtime_test_retained_payload_count(second.commands), content="1")
  let third = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(third.commands), content="1")
  inspect(runtime_test_retained_payload_count(third.commands), content="1")
  let fourth = runtime.draw_frame()
  inspect(runtime_test_begin_cached_layer_count(fourth.commands), content="1")
  inspect(runtime_test_retained_payload_count(fourth.commands), content="1")
}

///|
test "runtime retained layer revision change keeps complete payload" {
  let revision = Ref(0)
  let runtime = AppRuntime::new_view(
    root=runtime_test_stable_cached_layer_source(revision),
    size=@core.Size::new(width=12.0, height=12.0),
  )
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  inspect(
    runtime_test_begin_cached_layer_count(runtime.draw_frame().commands),
    content="1",
  )
  runtime_test_bump_cached_layer_revision(runtime)
  let first_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(first_changed.commands),
    content="1",
  )
  inspect(
    runtime_test_retained_payload_count(first_changed.commands),
    content="1",
  )
  let second_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(second_changed.commands),
    content="1",
  )
  inspect(
    runtime_test_retained_payload_count(second_changed.commands),
    content="1",
  )
  let third_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(third_changed.commands),
    content="1",
  )
  inspect(
    runtime_test_retained_payload_count(third_changed.commands),
    content="1",
  )
  let fourth_changed = runtime.draw_frame()
  inspect(
    runtime_test_begin_cached_layer_count(fourth_changed.commands),
    content="1",
  )
  inspect(
    runtime_test_retained_payload_count(fourth_changed.commands),
    content="1",
  )
}
