///|
test "host surface metrics tracks logical physical and dpr" {
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=120.0, height=80.0))
  assert_true(
    metrics.physical_size == @core.Size::new(width=240.0, height=160.0),
  )
  inspect(metrics.scale_factor, content="2")
}

///|
test "host app info records shared model boundaries" {
  let info = HostAppInfo::new(
    backend=HostBackendKind::Native,
    description="native host",
  )
  assert_true(info.backend == HostBackendKind::Native)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "input host owns focus modifiers and text input gating" {
  let input = InputHostState::new()
  match input.text_input_event("a") {
    None => ()
    Some(_) => fail("unfocused input host should not emit text")
  }
  input.focus()
  input.set_modifiers(@core.KeyModifiers::new(shift=true))
  let key_event = input.keyboard_event(key="A", text=Some("A"))
  match key_event {
    HostEvent::Keyboard(event) => {
      inspect(event.key, content="A")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
  match input.text_input_event("A") {
    Some(HostEvent::TextInput(text)) => inspect(text, content="A")
    _ => fail("expected focused text input")
  }
  input.blur()
  match input.text_input_event("b") {
    None => ()
    Some(_) => fail("blurred input host should not emit text")
  }
}

///|
test "surface host resizes through host event" {
  let surface = SurfaceHostState::new(
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
    owns_surface=true,
  )
  let event = surface.resize(
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=12.0),
      scale_factor=2.0,
    ),
  )
  match event {
    HostEvent::Resized(metrics) => {
      assert_true(
        surface.logical_size() == @core.Size::new(width=20.0, height=12.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=40.0, height=24.0),
      )
      inspect(surface.owns_surface, content="true")
      inspect(surface.can_reconfigure, content="true")
    }
    _ => fail("expected resize event")
  }
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(HostEvent::Resized(metrics))
  let second = driver.dispatch(HostEvent::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(HostEvent::Resized(metrics)))
  inspect(scheduled.val, content="2")
}

///|
test "host driver maps focused text input through core text input event" {
  let text = @core.State::new("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Color::white(),
      border_color: @core.Color::gray(),
      focused_border_color: @core.Color::blue(),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(driver.dispatch(HostEvent::TextInput("a")))
  inspect(text.get(), content="")
  ignore(
    driver.dispatch(
      HostEvent::PointerButton(
        @core.Point::new(x=10.0, y=10.0),
        @core.PointerPhase::Down,
        0,
      ),
    ),
  )
  let result = driver.dispatch(HostEvent::TextInput("a"))
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver dispatches ime composition text input events" {
  let text = @core.State::new("")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::TextFieldSpec({
      key: None,
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=400),
      foreground: @core.Color::black(),
      placeholder_color: @core.Color::gray(),
      background: @core.Color::white(),
      border_color: @core.Color::gray(),
      focused_border_color: @core.Color::blue(),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::PointerButton(
        @core.Point::new(x=10.0, y=10.0),
        @core.PointerPhase::Down,
        0,
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInputEvent(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInputEvent(@core.TextInputEvent::CompositionEnd("你")),
    ),
  )
  inspect(text.get(), content="你")
}

///|
test "host event converts to current core event model" {
  let event = HostEvent::TextInput("x").to_core()
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text))) => {
      inspect(text, content="x")
    }
    _ => fail("expected text input event")
  }
  let composition = HostEvent::TextInputEvent(
    @core.TextInputEvent::CompositionEnd("你"),
  ).to_core()
  match composition {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="你")
    _ => fail("expected composition text input event")
  }
}
