///|
enum ProgramSimpleMsg {
  ProgramSimpleIncrement
}

///|
test "program simple updates model and rebuilds view" {
  let program = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        ProgramSimpleIncrement => model + 1
      }
    },
    view=model => {
      View::primitive_button_view(
        text="Count \{model}",
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSimpleIncrement),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 0"))
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 1"))
}

///|
test "program button update waits for draw frame flush" {
  let program = Program::simple(
    init=0,
    update=(model, message) => {
      match message {
        ProgramSimpleIncrement => model + 1
      }
    },
    view=model => {
      View::primitive_button_view(
        text="Count \{model}",
        size=Size::new(width=120.0, height=44.0),
        font=FontSpec::new(size=16.0),
        foreground=Color::black(),
        background=Brush::solid(Color::gray()),
        hovered_background=Brush::solid(Color::gray()),
        pressed_background=Brush::solid(Color::blue()),
        on_click=Some(ProgramSimpleIncrement),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=160.0, height=80.0),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Count 0"))
  let before = runtime.inspector_snapshot().runtime
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(runtime.needs_rebuild(), content="true")
  let pending = runtime.inspector_snapshot().runtime
  inspect(pending.rebuild_pass_count, content="\{before.rebuild_pass_count}")
  inspect(pending.layout_pass_count, content="\{before.layout_pass_count}")
  inspect(pending.paint_pass_count, content="\{before.paint_pass_count}")
  assert_true(pending.dirty_build_count > 0)
  assert_true(pending.dirty_layout_count > 0)
  assert_true(pending.dirty_paint_count > 0)
  assert_true(has_draw_text(runtime.draw_commands(), "Count 1"))
  let after = runtime.inspector_snapshot().runtime
  assert_true(after.rebuild_pass_count > before.rebuild_pass_count)
  assert_true(after.layout_pass_count > before.layout_pass_count)
  assert_true(after.paint_pass_count > before.paint_pass_count)
}

///|
test "program simple with environment rebuilds from viewport and environment" {
  let program : Program[Int, Unit] = Program::simple_with_environment(
    init=0,
    update=(model, _message) => model,
    view=(model, env) => {
      let viewport = env.viewport_size()
      let environment = env.environment()
      runtime_test_label(
        "Env \{model}: \{viewport.width}x\{viewport.height} \{environment.locale}",
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=120.0, height=40.0),
    environment=Environment::default().with_locale("en-US"),
  )
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 120x40 en-US"))
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 240x160 en-US"))
  runtime.set_environment(runtime.environment().with_locale("zh-CN"))
  assert_true(has_draw_text(runtime.draw_commands(), "Env 0: 240x160 zh-CN"))
}
