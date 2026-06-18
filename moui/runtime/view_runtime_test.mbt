///|
fn[Msg] runtime_test_rect(
  width~ : Double,
  height~ : Double,
  color~ : @core.Color,
  on_tap? : Msg? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Rect"),
    revision=() => "test-rect:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, color),
      ])
    },
    event=ctx => {
      match (ctx.event, on_tap) {
        (@core.AppEvent::Pointer(event), Some(message)) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) {
            @core.ViewEventResult::message(message)
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn[Msg] runtime_test_padding(
  child~ : @core.View[Msg],
  insets~ : @core.Insets,
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Padding", key~),
    revision=() => {
      "test-padding:\{insets.top}:\{insets.right}:\{insets.bottom}:\{insets.left}"
    },
    children=() => [child],
    child_constraints=constraints => constraints.deflate(insets),
    layout=ctx => {
      let child_size = runtime_test_first_child_size(ctx.child_sizes)
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(child_size.inflate(insets)),
        child_frames=[
          @core.Rect::new(
            x=insets.left,
            y=insets.top,
            width=child_size.width,
            height=child_size.height,
          ),
        ],
      )
    },
  )
}

///|
fn runtime_test_first_child_size(sizes : Array[@core.Size]) -> @core.Size {
  match sizes.get(0) {
    Some(size) => size
    None => @core.Size::new(width=0.0, height=0.0)
  }
}

///|
test "runtime dispatches messages from virtual node" {
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=runtime_test_rect(
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
    fail("expected runtime to dispatch virtual node message")
  }
}

///|
test "virtual node layout constrains children and inspector keeps identity" {
  let root : @core.View[Unit] = runtime_test_padding(
    child=runtime_test_rect(width=20.0, height=10.0, color=@core.Color::blue()),
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
    fail("expected virtual node kind in inspector")
  }
  match snapshot.view_tree.nodes.get(0) {
    Some(node) =>
      if node.key != "outer" {
        fail("expected virtual node key in inspector")
      }
    None => fail("expected inspector root node")
  }
}

///|
test "virtual node component builds child and reports component inspector state" {
  let root : @core.View[Unit] = @views.component(_ctx => {
    runtime_test_rect(width=32.0, height=18.0, color=@core.Color::blue())
  })
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  let layout = runtime.layout()
  match layout.children.get(0) {
    Some(child) =>
      if child.frame.size != @core.Size::new(width=32.0, height=18.0) {
        fail("expected component virtual node to lay out built child")
      }
    None => fail("expected component virtual node to build child")
  }
  let snapshot = runtime.inspector_snapshot()
  if snapshot.view_tree.root_kind != "Component" ||
    snapshot.view_tree.component_count != 1 {
    fail("expected generic virtual node component in inspector")
  }
}

///|
test "virtual node component watch rebuilds built child" {
  let width_state = @core.State::new(24.0)
  let root : @core.View[Unit] = @views.component(ctx => {
    runtime_test_rect(
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
test "virtual node scroll updates state and marks layout dirty" {
  let received : Array[@core.Point] = []
  let state = @core.ScrollState::new()
  let runtime = AppRuntime::new_view(
    root=@views.scroll_view(
      runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
      width=20.0,
      height=40.0,
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
    fail("expected virtual node scroll to update scroll state")
  }
  if received != [@core.Point::new(x=0.0, y=-12.0)] {
    fail("expected virtual node scroll to dispatch on_scroll message")
  }
  let snapshot = runtime.inspector_snapshot()
  match snapshot.view_tree.nodes.get(0) {
    Some(node) =>
      if !node.needs_layout {
        fail("expected virtual node scroll to mark layout dirty")
      }
    None => fail("expected inspector root node")
  }
}

///|
test "virtual node webview paints platform view and dispatches events" {
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
        fail("expected virtual node webview platform placement")
      }
    None => fail("expected virtual node webview platform placement")
  }
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "docs",
      @views.WebViewEvent::TitleChanged("Loaded").to_platform_event(),
    ),
  )
  if received != [@views.WebViewEvent::TitleChanged("Loaded")] {
    fail("expected virtual node webview to dispatch event")
  }
}

///|
test "nested virtual node webview dispatches events through generic children" {
  let received : Array[@views.WebViewEvent] = []
  let runtime = AppRuntime::new_view(
    root=runtime_test_padding(
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
    fail("expected nested virtual node webview to dispatch event")
  }
}

///|
test "virtual node button dispatches click through runtime" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
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
    fail("expected virtual node button to dispatch on_click")
  }
}

///|
test "virtual node checkbox controlled event dispatches without core primitive" {
  let received : Array[Bool] = []
  let runtime = AppRuntime::new_view(
    root=@views.checkbox(
      "Enabled",
      checked=false,
      on_change=next => next,
      box_size=18.0,
      height=32.0,
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
    fail("expected controlled checkbox virtual node to dispatch next value")
  }
}

///|
test "virtual node picker dispatches overlay selection without core primitive" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.frame(
      @views.picker(
        [@views.picker_item("one", "One"), @views.picker_item("two", "Two")],
        selected="one",
        on_select=id => id,
        placeholder="Pick",
        max_height=160.0,
      ),
      width=200.0,
      height=40.0,
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
        fail("expected picker virtual node identity in inspector")
      }
    None => fail("expected picker inspector node")
  }
  if snapshot.view_tree.root_kind != "Frame" {
    fail("expected picker virtual node identity in inspector")
  }
}

///|
test "virtual node picker binding selection mutates binding" {
  let selected_state = @core.State::new("one")
  let root : @core.View[Unit] = @views.frame(
    @views.picker_binding(
      [@views.picker_item("one", "One"), @views.picker_item("two", "Two")],
      selected=selected_state.binding(),
      placeholder="Pick",
      max_height=160.0,
    ),
    width=200.0,
    height=40.0,
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
test "virtual node datepicker dispatches overlay selection without core primitive" {
  let received : Array[@core.DateValue] = []
  let runtime = AppRuntime::new_view(
    root=@views.frame(
      @views.datepicker(
        selected=@core.DateValue::new(year=2024, month=1, day=15),
        on_select=value => value,
        mode=@views.DatePickerMode::Date,
        placeholder="Select date",
      ),
      width=200.0,
      height=40.0,
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
        fail("expected datepicker virtual node identity in inspector")
      }
    None => fail("expected datepicker inspector node")
  }
}

///|
test "virtual node datepicker binding selection mutates binding after month navigation" {
  let selected_state = @core.State::new(
    @core.DateValue::new(year=2024, month=1, day=15),
  )
  let root : @core.View[Unit] = @views.frame(
    @views.datepicker_binding(
      selected=selected_state.binding(),
      mode=@views.DatePickerMode::Date,
      placeholder="Select date",
    ),
    width=200.0,
    height=40.0,
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
test "virtual node sheet handles outside dismiss and preserves child event" {
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=@views.sheet(
      content=runtime_test_rect(
        width=40.0,
        height=40.0,
        color=@core.Color::blue(),
        on_tap=Some(1),
      ),
      background=@core.Color::white(),
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
    fail("expected sheet virtual node identity in inspector")
  }
}

///|
test "runtime semantics includes declared state modifiers" {
  let root : @core.View[Unit] = @views.text("Stateful", width=80.0, height=24.0)
    .semantics_role(@core.SemanticsRole::Checkbox)
    .semantics_checked(checked=true)
    .semantics_selected(selected=true)
    .semantics_pressed(pressed=true)
    .semantics_expanded(expanded=true)
    .semantics_invalid(invalid=true)
    .semantics_required(required=true)
    .disabled(disabled=true)
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=32.0),
  )
  let semantics = runtime.semantics()
  assert_true(semantics.state.checked)
  assert_true(semantics.state.selected)
  assert_true(semantics.state.pressed)
  assert_true(semantics.state.expanded)
  assert_true(semantics.state.invalid)
  assert_true(semantics.state.required)
  assert_true(semantics.state.disabled)
}
