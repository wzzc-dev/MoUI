///|
test "runtime dispatches messages from widget ops" {
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=@widget.rect(
      width=20.0,
      height=20.0,
      color=@core.Color::blue(),
      on_tap=Some(9),
    ),
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != [9] {
    fail("expected runtime to dispatch widget message")
  }
}

///|
test "widget layout constrains children and inspector keeps identity" {
  let root : @core.View[Unit] = @widget.padding(
    child=@widget.rect(width=20.0, height=10.0, color=@core.Color::blue()),
    insets=@core.Insets::all(4.0),
    key=Some("outer"),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=28.0, height=18.0),
  )
  let layout = runtime.layout()
  if layout.frame.size != @core.Size::new(width=28.0, height=18.0) {
    fail("expected padding to inflate measured size")
  }
  match layout.children.get(0) {
    Some(child) =>
      if child.frame != @core.Rect::new(x=4.0, y=4.0, width=20.0, height=10.0) {
        fail("expected child frame to include padding offset")
      }
    None => fail("expected padded child")
  }
  let snapshot = runtime.inspector_snapshot()
  if snapshot.view_tree.root_kind != "Padding" {
    fail("expected widget kind in inspector")
  }
  match snapshot.view_tree.nodes.get(0) {
    Some(node) =>
      if node.key != "outer" {
        fail("expected widget key in inspector")
      }
    None => fail("expected inspector root node")
  }
}

///|
test "widget component builds child and reports component inspector state" {
  let root : @core.View[Unit] = @widget.component(_ctx => {
    @widget.rect(width=32.0, height=18.0, color=@core.Color::blue())
  })
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  let layout = runtime.layout()
  match layout.children.get(0) {
    Some(child) =>
      if child.frame.size != @core.Size::new(width=32.0, height=18.0) {
        fail("expected component widget to lay out built child")
      }
    None => fail("expected component widget to build child")
  }
  let snapshot = runtime.inspector_snapshot()
  if snapshot.view_tree.root_kind != "Component" ||
    snapshot.view_tree.component_count != 1 {
    fail("expected generic widget component in inspector")
  }
}

///|
test "widget component watch rebuilds built child" {
  let width_state = @core.State::new(24.0)
  let root : @core.View[Unit] = @widget.component(ctx => {
    @widget.rect(
      width=ctx.watch(width_state),
      height=10.0,
      color=@core.Color::blue(),
    )
  })
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  match runtime.layout().children.get(0) {
    Some(child) =>
      if child.frame.size != @core.Size::new(width=24.0, height=10.0) {
        fail("expected initial component child size")
      }
    None => fail("expected initial component child")
  }
  width_state.set(48.0)
  match runtime.layout().children.get(0) {
    Some(child) =>
      if child.frame.size != @core.Size::new(width=48.0, height=10.0) {
        fail("expected watched state to rebuild component child")
      }
    None => fail("expected rebuilt component child")
  }
}

///|
test "widget scroll updates state and marks layout dirty" {
  let received : Array[@core.Point] = []
  let state = @core.ScrollState::new()
  let runtime = AppRuntime::new_view(
    root=@widget.scroll(
      child=@widget.rect(width=20.0, height=200.0, color=@core.Color::blue()),
      viewport=Some(@core.Size::new(width=20.0, height=40.0)),
      state=Some(state),
      on_scroll=Some(delta => delta),
    ),
    size=@core.Size::new(width=20.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  if state.offset() != @core.Point::new(x=0.0, y=12.0) {
    fail("expected widget scroll to update scroll state")
  }
  if received != [@core.Point::new(x=0.0, y=-12.0)] {
    fail("expected widget scroll to dispatch on_scroll message")
  }
  let snapshot = runtime.inspector_snapshot()
  match snapshot.view_tree.nodes.get(0) {
    Some(node) =>
      if !node.needs_layout {
        fail("expected widget scroll to mark layout dirty")
      }
    None => fail("expected inspector root node")
  }
}

///|
test "widget webview paints platform view and dispatches events" {
  let received : Array[@views.WebViewEvent] = []
  let runtime = AppRuntime::new_view(
    root=@views.web_view(
      id="docs",
      url="https://example.com",
      width=Some(320.0),
      height=Some(180.0),
      title="Docs",
      on_event=Some(event => event),
    ),
    size=@core.Size::new(width=320.0, height=180.0),
    on_message=Some(message => received.push(message)),
  )
  let frame = runtime.draw_frame()
  match frame.platform_views.get(0) {
    Some(view) =>
      if view.id != "docs" ||
        view.property_or("url", "") != "https://example.com" {
        fail("expected widget webview platform placement")
      }
    None => fail("expected widget webview platform placement")
  }
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "docs",
      @views.WebViewEvent::TitleChanged("Loaded").to_platform_event(),
    ),
  )
  if received != [@views.WebViewEvent::TitleChanged("Loaded")] {
    fail("expected widget webview to dispatch event")
  }
}

///|
test "nested widget webview dispatches events through generic children" {
  let received : Array[@views.WebViewEvent] = []
  let runtime = AppRuntime::new_view(
    root=@widget.padding(
      child=@views.web_view(
        id="nested",
        url="https://example.com/nested",
        width=Some(320.0),
        height=Some(180.0),
        title="Nested",
        on_event=Some(event => event),
      ),
      insets=@core.Insets::all(4.0),
    ),
    size=@core.Size::new(width=328.0, height=188.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "nested",
      @views.WebViewEvent::NavigationFinished("https://example.com/nested").to_platform_event(),
    ),
  )
  if received !=
    [@views.WebViewEvent::NavigationFinished("https://example.com/nested")] {
    fail("expected nested widget webview to dispatch event")
  }
}

///|
test "widget button dispatches click through runtime" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@widget.button(
      text="Go",
      size=@core.Size::new(width=80.0, height=32.0),
      font=@core.FontSpec::new(size=14.0),
      foreground=@core.Color::white(),
      background=@core.Brush::solid(@core.Color::blue()),
      hovered_background=@core.Brush::solid(@core.Color::blue()),
      pressed_background=@core.Brush::solid(@core.Color::gray()),
      on_click=Some("clicked"),
    ),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=8.0, y=8.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=8.0, y=8.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != ["clicked"] {
    fail("expected widget button to dispatch on_click")
  }
}

///|
test "widget checkbox controlled event dispatches without core primitive" {
  let received : Array[Bool] = []
  let checked = @core.Binding::new(get=() => false, set=_next => ())
  let runtime = AppRuntime::new_view(
    root=@widget.checkbox(
      label="Enabled",
      checked~,
      font=@core.FontSpec::new(size=14.0),
      foreground=@core.Color::black(),
      check_color=@core.Color::blue(),
      size=@core.Size::new(width=18.0, height=32.0),
      on_change=Some(next => next),
    ),
    size=@core.Size::new(width=120.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=8.0, y=8.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != [true] {
    fail("expected controlled checkbox widget to dispatch next value")
  }
}

///|
test "widget picker dispatches overlay selection without core primitive" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@widget.frame(
      child=@widget.picker(
        items=[
          @widget.PickerOption::new(id="one", label="One"),
          @widget.PickerOption::new(id="two", label="Two"),
        ],
        selected=@core.Binding::new(get=() => "one", set=_value => ()),
        placeholder="Pick",
        font=@core.FontSpec::new(size=14.0),
        foreground=@core.Color::black(),
        background=@core.Brush::solid(@core.Color::white()),
        corner_radius=6.0,
        max_height=160.0,
        on_select=Some(id => id),
      ),
      width=Some(200.0),
      height=Some(40.0),
      min_width=None,
      min_height=None,
      max_width=None,
      max_height=None,
    ),
    size=@core.Size::new(width=200.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  let opened = runtime.inspector_snapshot()
  match opened.view_tree.nodes.get(1) {
    Some(node) =>
      if !node.needs_paint {
        fail("expected opening picker to dirty paint")
      }
    None => fail("expected picker inspector node")
  }
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=84.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != ["two"] {
    fail("expected picker overlay selection message")
  }
  let snapshot = runtime.inspector_snapshot()
  match snapshot.view_tree.nodes.get(1) {
    Some(node) =>
      if node.kind != "Picker" {
        fail("expected picker widget identity in inspector")
      }
    None => fail("expected picker inspector node")
  }
  if snapshot.view_tree.root_kind != "Frame" {
    fail("expected picker widget identity in inspector")
  }
}

///|
test "widget picker binding selection mutates binding" {
  let selected_state = @core.State::new("one")
  let root : @core.View[Unit] = @widget.frame(
    child=@widget.picker(
      items=[
        @widget.PickerOption::new(id="one", label="One"),
        @widget.PickerOption::new(id="two", label="Two"),
      ],
      selected=selected_state.binding(),
      placeholder="Pick",
      font=@core.FontSpec::new(size=14.0),
      foreground=@core.Color::black(),
      background=@core.Brush::solid(@core.Color::white()),
      corner_radius=6.0,
      max_height=160.0,
    ),
    width=Some(200.0),
    height=Some(40.0),
    min_width=None,
    min_height=None,
    max_width=None,
    max_height=None,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=84.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if selected_state.get() != "two" {
    fail("expected picker binding to update")
  }
}

///|
test "widget datepicker dispatches overlay selection without core primitive" {
  let received : Array[@core.DateValue] = []
  let runtime = AppRuntime::new_view(
    root=@widget.frame(
      child=@widget.datepicker(
        selected=@core.Binding::new(
          get=() => @core.DateValue::new(year=2024, month=1, day=15),
          set=_value => (),
        ),
        mode=@core.DatePickerMode::Date,
        placeholder="Select date",
        font=@core.FontSpec::new(size=14.0),
        foreground=@core.Color::black(),
        background=@core.Brush::solid(@core.Color::white()),
        corner_radius=6.0,
        on_select=Some(value => value),
      ),
      width=Some(200.0),
      height=Some(40.0),
      min_width=None,
      min_height=None,
      max_width=None,
      max_height=None,
    ),
    size=@core.Size::new(width=200.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  let opened = runtime.inspector_snapshot()
  match opened.view_tree.nodes.get(1) {
    Some(node) =>
      if !node.needs_paint {
        fail("expected opening datepicker to dirty paint")
      }
    None => fail("expected datepicker inspector node")
  }
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=148.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != [@core.DateValue::new(year=2024, month=1, day=2)] {
    fail("expected datepicker overlay selection message")
  }
  let snapshot = runtime.inspector_snapshot()
  match snapshot.view_tree.nodes.get(1) {
    Some(node) =>
      if node.kind != "DatePicker" {
        fail("expected datepicker widget identity in inspector")
      }
    None => fail("expected datepicker inspector node")
  }
}

///|
test "widget datepicker binding selection mutates binding after month navigation" {
  let selected_state = @core.State::new(
    @core.DateValue::new(year=2024, month=1, day=15),
  )
  let root : @core.View[Unit] = @widget.frame(
    child=@widget.datepicker(
      selected=selected_state.binding(),
      mode=@core.DatePickerMode::Date,
      placeholder="Select date",
      font=@core.FontSpec::new(size=14.0),
      foreground=@core.Color::black(),
      background=@core.Brush::solid(@core.Color::white()),
      corner_radius=6.0,
    ),
    width=Some(200.0),
    height=Some(40.0),
    min_width=None,
    min_height=None,
    max_width=None,
    max_height=None,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=256.0, y=69.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=220.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if selected_state.get() != @core.DateValue::new(year=2024, month=2, day=14) {
    fail("expected datepicker binding to preserve navigated month")
  }
}

///|
test "widget sheet handles outside dismiss and preserves child event" {
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=@widget.sheet(
      content=@widget.rect(
        width=40.0,
        height=40.0,
        color=@core.Color::blue(),
        on_tap=Some(1),
      ),
      background=@core.Brush::solid(@core.Color::white()),
      corner_radius=8.0,
      on_dismiss=Some(2),
    ),
    size=@core.Size::new(width=72.0, height=72.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=4.0, y=4.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != [1, 2] {
    fail("expected sheet content tap and outside dismiss messages")
  }
  let snapshot = runtime.inspector_snapshot()
  if snapshot.view_tree.root_kind != "Sheet" {
    fail("expected sheet widget identity in inspector")
  }
}
