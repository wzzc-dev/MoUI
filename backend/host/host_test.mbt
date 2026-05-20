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
test "input host owns capabilities focus modifiers and text input gating" {
  let input = InputHostState::new()
  let capabilities = input.capabilities()
  inspect(capabilities.pointer, content="true")
  inspect(capabilities.scroll, content="true")
  inspect(capabilities.ime, content="false")
  inspect(input.coordinate_policy().scale_factor_applied, content="true")
  match input.insert_text("a") {
    None => ()
    Some(_) => fail("unfocused input host should not emit text")
  }
  match input.focus_event(focused=true) {
    Some(HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
  input.set_modifiers(@core.KeyModifiers::new(shift=true))
  let key_event = input.keyboard_event(key="A", text=Some("A"))
  match key_event {
    Some(HostEvent::Keyboard(event)) => {
      inspect(event.key, content="A")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
  match input.insert_text("A") {
    Some(HostEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="A")
    _ => fail("expected focused text input")
  }
  match input.focus_event(focused=false) {
    Some(HostEvent::Focus({ focused: false, .. })) => ()
    _ => fail("expected blur event")
  }
  match input.insert_text("b") {
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
test "host service bridge gates typed platform requests by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      system_theme=true,
    ),
    handle=request =>
      match request {
        Clipboard(WriteText(_)) => HostServiceResponse::ClipboardWritten
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        ShowMenu(commands) =>
          if commands.length() > 0 {
            HostServiceResponse::MenuCommand(commands[0].intent)
          } else {
            HostServiceResponse::Unavailable("empty menu")
          }
        QuerySystemTheme => HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("not implemented")
      },
  )
  match bridge.dispatch(
    HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
  ) {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard text")
  }
  match bridge.dispatch(
    HostServiceRequest::ShowMenu([
      @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
    ]),
  ) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Copy) => ()
    _ => fail("expected selected menu command")
  }
  match bridge.dispatch(
    HostServiceRequest::FileDialog(
      HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
    ),
  ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file dialog")
  }
}

///|
test "host driver dispatches command intents through runtime action map" {
  let copied = Ref(0)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::EmptySpec,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::Command(@core.CommandIntent::Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match HostEvent::Command(@core.CommandIntent::Copy).to_core() {
    None => ()
    Some(_) => fail("host command should dispatch through runtime action map")
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
      background: @core.Brush::solid(@core.Color::white()),
      border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::gray()),
          width=1.0,
        ),
      ),
      focused_border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::blue()),
          width=2.0,
        ),
      ),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("a"))),
  )
  inspect(text.get(), content="")
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  let result = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
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
      background: @core.Brush::solid(@core.Color::white()),
      border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::gray()),
          width=1.0,
        ),
      ),
      focused_border: Some(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(@core.Color::blue()),
          width=2.0,
        ),
      ),
      cursor_color: @core.Color::blue(),
      corner_radius: 0.0,
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你")),
    ),
  )
  inspect(text.get(), content="你")
}

///|
test "text input session enables updates and disables ime requests" {
  let text = @core.State::new("ab")
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::FlexSpec({
      key: None,
      axis: @core.Axis::Vertical,
      spacing: 4.0,
      main_axis_alignment: @core.MainAxisAlignment::MainStart,
      cross_axis_alignment: @core.CrossAxisAlignment::CrossStart,
      children: [
        @core.ViewSpec::TextFieldSpec({
          key: None,
          value: text.binding(),
          placeholder: "Type",
          size: @core.Size::new(width=120.0, height=40.0),
          font: @core.FontSpec::new(size=16.0, weight=400),
          foreground: @core.Color::black(),
          placeholder_color: @core.Color::gray(),
          background: @core.Brush::solid(@core.Color::white()),
          border: None,
          focused_border: None,
          cursor_color: @core.Color::blue(),
          corner_radius: 0.0,
          on_submit: None,
        }),
      ],
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let session = TextInputSession::new()
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should not change ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    EnableIme(@window_core.ImeRequest::Enable(_)) => ()
    _ => fail("focused text field should enable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    UpdateIme(@window_core.ImeRequest::Update(data)) => {
      match data.cursor_area() {
        Some((_, size)) => assert_true(size.to_logical(1.0).height() > 0.0)
        None => fail("expected cursor area")
      }
      match data.surrounding_text() {
        Some(surrounding) => inspect(surrounding.text(), content="ab")
        None => fail("expected surrounding text")
      }
    }
    _ => fail("focused text field should update active ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=230.0, y=55.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    DisableIme(@window_core.ImeRequest::Disable) => ()
    _ => fail("blur should disable ime")
  }
}

///|
test "text input session enables ime when surrounding text is too long" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "a".repeat(@window_core.ImeSurroundingText::max_text_bytes() + 1),
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) => {
      assert_true(!request.capabilities().surrounding_text())
      assert_true(!request.request_data().has_surrounding_text())
    }
    _ => fail("focused text field should still enable ime")
  }
}

///|
test "host event converts to current core event model" {
  let event = HostEvent::TextInput(@core.TextInputEvent::InsertText("x")).to_core()
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="x")
    _ => fail("expected text input event")
  }
  let composition = HostEvent::TextInput(
    @core.TextInputEvent::CompositionEnd("你"),
  ).to_core()
  match composition {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="你")
    _ => fail("expected composition text input event")
  }
  let scroll = HostEvent::Scroll(
    HostScrollEvent::new(
      position=@core.Point::new(x=8.0, y=9.0),
      delta=HostScrollDelta::Lines(@core.Point::new(x=1.0, y=-2.0)),
    ),
  ).to_core()
  match scroll {
    Some(@core.AppEvent::Pointer({ wheel_delta: { x: 40.0, y: -80.0 }, .. })) =>
      ()
    _ => fail("expected scroll pointer event")
  }
  let blur = HostEvent::Focus(
    HostFocusEvent::new(
      focused=false,
      pointer_cancel_position=Some(@core.Point::new(x=2.0, y=3.0)),
    ),
  ).to_core()
  match blur {
    Some(@core.AppEvent::Pointer({ phase: @core.PointerPhase::Cancel, .. })) =>
      ()
    _ => fail("expected blur cancel pointer event")
  }
}
