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
  let received : Array[@webview_host.WebViewEvent] = []
  let runtime = AppRuntime::new_view(
    root=@webview_views.web_view(
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
      @webview_host.WebViewEvent::TitleChanged("Loaded").to_platform_event(),
    ),
  )
  if received != [@webview_host.WebViewEvent::TitleChanged("Loaded")] {
    fail("expected virtual node webview to dispatch event")
  }
}

///|
test "nested virtual node webview dispatches events through generic children" {
  let received : Array[@webview_host.WebViewEvent] = []
  let runtime = AppRuntime::new_view(
    root=runtime_test_padding(
      child=@webview_views.web_view(
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
      @webview_host.WebViewEvent::NavigationFinished(
        "https://example.com/nested",
      ).to_platform_event(),
    ),
  )
  if received !=
    [
      @webview_host.WebViewEvent::NavigationFinished(
        "https://example.com/nested",
      ),
    ] {
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

///|
test "runtime propagates text style modifiers into draw commands" {
  let color = @core.Color::rgba(r=0.91, g=0.12, b=0.18)
  let font = @core.FontSpec::new(size=23.0, weight=700)
  let root : @core.View[Unit] = @views.text("Styled", width=90.0, height=28.0)
    .font(font)
    .foreground(color)
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=40.0),
  )
  match runtime_test_text_run(runtime.draw_commands(), "Styled") {
    Some(run) => {
      assert_true(run.color == color)
      assert_true(run.font == font)
    }
    None => fail("expected styled text draw command")
  }
}

///|
test "runtime propagates theme modifier into default text color" {
  let theme = @views.dark_theme()
  let root : @core.View[Unit] = @views.text("Themed", width=90.0, height=28.0).theme(
    theme,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=40.0),
  )
  match runtime_test_text_run(runtime.draw_commands(), "Themed") {
    Some(run) => assert_true(run.color == theme.palette.foreground)
    None => fail("expected themed text draw command")
  }
}

///|
/// A primary button paints its background from `theme.palette.primary`. Because
/// the button resolves its style ambient-ly at paint time (reading
/// `ctx.environment.theme` rather than baking a light theme at construction),
/// switching the environment's color scheme must recolor the same view tree
/// without rebuilding it. This is the core ambient-theme contract: the button
/// view is constructed once below, then `set_environment` flips the scheme.
test "ambient button recolors when environment scheme flips without rebuild" {
  let light_env = @core.Environment::neutral()
  let dark_env = light_env.with_system_scheme(@core.ColorScheme::Dark)
  let light_primary = light_env.theme.palette.primary
  let dark_primary = dark_env.theme.palette.primary
  // Sanity: the two schemes must actually differ, otherwise the test proves
  // nothing.
  assert_true(light_primary != dark_primary)
  // The button view is constructed ONCE against the light environment. No
  // `theme=` argument is passed, so it must read the ambient theme at paint.
  let root : @core.View[Unit] = @views.button(
    "Ambient",
    on_click=(),
    width=120.0,
    height=40.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=40.0),
    environment=light_env,
  )
  // First paint: button background must be the light primary.
  match runtime_test_solid_fill_color(runtime.draw_commands()) {
    Some(color) => assert_true(color == light_primary)
    None => fail("expected a solid fill for the ambient button")
  }
  // Flip the environment to dark WITHOUT rebuilding the view tree. The runtime
  // marks the tree dirty and re-paints; the same button node must now emit the
  // dark primary.
  runtime.set_environment(dark_env)
  match runtime_test_solid_fill_color(runtime.draw_commands()) {
    Some(color) => assert_true(color == dark_primary)
    None => fail("expected a solid fill for the ambient button after flip")
  }
}

///|
/// Extract the first solid-fill rounded-rect color from a draw-command list.
/// Used to assert the ambient background of a control.
fn runtime_test_solid_fill_color(
  commands : Array[@core.DrawCommand],
) -> @core.Color? {
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(_, @core.Brush::Solid(color)) =>
        return Some(color)
      _ => ()
    }
  }
  None
}

///|
fn runtime_test_text_run(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.TextRun? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) =>
        if run.text == text {
          return Some(run)
        }
      _ => ()
    }
  }
  None
}

///|
/// A minimal hover-tracking view used to verify the runtime's synthetic
/// `PointerPhase::Exit` delivery. It mirrors the button's state machine: a
/// `Move` inside sets `hovered`, a `Move` outside (or an `Exit`) clears it.
/// Each state change appends the resulting `hovered` flag to `log` so the test
/// can assert the full hover-enter/leave sequence.
fn[Msg] runtime_test_hover_tracker(
  width~ : Double,
  height~ : Double,
  log~ : Array[Bool],
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="HoverTracker"),
    revision=() => "hover-tracker:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) => {
          let inside = ctx.frame.contains(event.position)
          // Treat Exit like an out-of-bounds move: the pointer has left.
          let effective_inside = if event.phase == @core.PointerPhase::Exit {
            false
          } else {
            inside
          }
          let next_hovered = match event.phase {
            @core.PointerPhase::Down => ctx.state.hovered
            @core.PointerPhase::Move => effective_inside
            @core.PointerPhase::Up => effective_inside
            @core.PointerPhase::Cancel | @core.PointerPhase::Exit => false
          }
          let changed = next_hovered != ctx.state.hovered
          if changed {
            log.push(next_hovered)
          }
          if changed {
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              captured: true,
              state: Some({ ..ctx.state, hovered: next_hovered }),
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
/// Regression: a control that turns hovered on pointer-enter must clear that
/// hover when the pointer moves off it. Host backends only emit `Move`, and a
/// move landing outside the control is never delivered by hit-testing — so the
/// runtime synthesizes a `PointerPhase::Exit` to the previously hovered
/// element. Two trackers sit at fixed frames with a gap between them, so the
/// pointer can land on genuinely empty space. Asserts the enter/leave log is
/// `[true, false, true]` after hovering the left tracker, moving into the gap,
/// then back onto it.
test "runtime delivers synthetic Exit to clear hover on pointer leave" {
  let log : Array[Bool] = []
  // Canvas is 300x40. Left tracker occupies x in [0,100); a gap spans
  // [100,200) with no element; right tracker occupies [200,300). The parent
  // places children at fixed frames so hit-testing distinguishes them and the
  // gap resolves to the parent (not the left tracker).
  let root : @core.View[Unit] = @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="HoverStage"),
    revision=() => "hover-stage",
    children=() => {
      [
        runtime_test_hover_tracker(width=100.0, height=40.0, log~),
        runtime_test_hover_tracker(
          width=100.0,
          height=40.0,
          log=runtime_test_unused_log(),
        ),
      ]
    },
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let frames : Array[@core.Rect] = []
      // Left tracker at [0,0,100,40], right tracker at [200,0,100,40].
      for index, _size in ctx.child_sizes {
        let x = if index == 0 { 0.0 } else { 200.0 }
        frames.push(@core.Rect::new(x~, y=0.0, width=100.0, height=40.0))
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=300.0, height=40.0),
        ),
        child_frames=frames,
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.layout())
  // Hover the left tracker.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  // Move into the gap (x in [100,200)). No tracker is hit, so the left tracker
  // must receive a synthetic Exit and clear its hover.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=150.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  // Move back onto the left tracker: it should hover again.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  // Expected: enter (true), leave (false), enter (true).
  if log != [true, false, true] {
    let rendered = log.map(b => if b { "true" } else { "false" }).join(", ")
    fail("expected hover log [true, false, true] but got [\{rendered}]")
  }
}

///|
fn runtime_test_unused_log() -> Array[Bool] {
  []
}

///|
/// A hover-tracker that also records the pointer phase of every event it
/// receives. Used to assert the synthetic `Exit` is never delivered to a
/// descendant of the previously hovered element (which would clear the
/// descendant's hover a frame before the `Move` re-sets it — a flicker).
fn[Msg] runtime_test_hover_phase_tracker(
  width~ : Double,
  height~ : Double,
  log~ : Array[Bool],
  phases~ : Array[@core.PointerPhase],
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="HoverPhaseTracker"),
    revision=() => "hover-phase-tracker:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) => {
          phases.push(event.phase)
          let effective_inside = if event.phase == @core.PointerPhase::Exit {
            false
          } else {
            ctx.frame.contains(event.position)
          }
          let next_hovered = match event.phase {
            @core.PointerPhase::Down => ctx.state.hovered
            @core.PointerPhase::Move => effective_inside
            @core.PointerPhase::Up => effective_inside
            @core.PointerPhase::Cancel | @core.PointerPhase::Exit => false
          }
          let changed = next_hovered != ctx.state.hovered
          if changed {
            log.push(next_hovered)
          }
          if changed {
            {
              ..@core.ViewEventResult::ignored(),
              changed: true,
              captured: true,
              state: Some({ ..ctx.state, hovered: next_hovered }),
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
/// Regression: when the pointer moves from empty parent space onto a child
/// button, the child must hover without receiving a spurious `Exit` in the same
/// event (which would clear its hover a frame before the `Move` re-sets it — a
/// flicker). The hover-clearing `Exit` is only sent to children the pointer no
/// longer hits, so a child being entered never gets one. Mirrors the Showcase
/// "Dialog" button reached by moving off empty space in its parent.
test "runtime Exit does not propagate to descendant being entered" {
  let child_log : Array[Bool] = []
  let child_phases : Array[@core.PointerPhase] = []
  // Parent fills the canvas [0,200]x[0,40]; child sits at [80,180]. Empty space
  // [0,80) lets the pointer rest on the parent (not the child) first.
  let child : @core.View[Unit] = runtime_test_hover_phase_tracker(
    width=100.0,
    height=40.0,
    log=child_log,
    phases=child_phases,
  )
  let root : @core.View[Unit] = @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="HoverParent"),
    revision=() => "hover-parent",
    children=() => [child],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let frames : Array[@core.Rect] = []
      for _index, _size in ctx.child_sizes {
        frames.push(@core.Rect::new(x=80.0, y=0.0, width=100.0, height=40.0))
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=200.0, height=40.0),
        ),
        child_frames=frames,
      )
    },
    paint=_ctx => @core.ViewPaintPlan::commands([]),
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=40.0),
  )
  ignore(runtime.layout())
  // Rest the pointer on empty parent space.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  // Move onto the child button. The parent gets an Exit; the child must get
  // only the Move (no Exit) — otherwise its hover flickers.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  // Child should have entered hover exactly once and never seen an Exit.
  if child_log != [true] {
    let rendered = child_log
      .map(b => if b { "true" } else { "false" })
      .join(", ")
    fail("expected child hover log [true] but got [\{rendered}]")
  }
  let has_exit = child_phases.any(p => p == @core.PointerPhase::Exit)
  if has_exit {
    fail(
      "child must not receive Exit while being entered; phase count=\{child_phases.length()}",
    )
  }
}

///|
/// Count `FillRoundedRectBrush` commands whose solid color has nonzero alpha —
/// the hover background a ghost/outline button paints. Used to assert hover
/// clears after the pointer leaves.
fn runtime_test_hover_fill_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut n = 0
  for cmd in commands {
    match cmd {
      @core.DrawCommand::FillRoundedRectBrush(_, brush) =>
        match brush {
          @core.Brush::Solid(color) => if color.a > 0.0 { n = n + 1 }
          _ => ()
        }
      _ => ()
    }
  }
  n
}

///|
/// Regression for the markdown_editor "More" menu: a ghost button floating in a
/// `stack` > `align` > `container(Overlay)` > `scroll_view` > `column` overlay.
/// Hovering a row then moving the pointer off into the workspace must clear the
/// hover background — even though the overlay's `align` wrapper spans the whole
/// canvas (so a naive top-down hover resolver returns the wrapper, not the
/// button, and never fires an `Exit`). The hover-clearing `Exit` is delivered
/// in the same traversal as the `Move`, so it reaches the button regardless of
/// how the overlay is nested.
test "runtime clears hover on a button nested in an overlay" {
  let theme = @views.light_theme()
  let row : @core.View[Unit] = @views.button(
    "Row",
    variant=@views.ButtonVariant::Ghost,
    theme~,
    width=168.0,
    height=36.0,
  )
  // Overlay anchored top-trailing, mirroring the markdown popover.
  let overlay : @core.View[Unit] = @views.container(
    @views.scroll_view(
      @views.column([row], spacing=4.0),
      width=232.0,
      height=200.0,
    ),
    theme~,
    width=232.0,
    height=200.0,
    variant=@views.ContainerVariant::Overlay,
  ).align(alignment=@core.Alignment::top_trailing())
  let root : @core.View[Unit] = @views.stack([
    @views.container(
      @views.text("workspace", width=400.0, height=300.0),
      width=400.0,
      height=300.0,
    ),
    overlay,
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=300.0),
  )
  ignore(runtime.layout())
  ignore(runtime.draw_frame())
  let baseline = runtime_test_hover_fill_count(runtime.draw_commands())
  // The overlay is top-trailing in a 400-wide canvas; the button sits inside it
  // near x≈300, y≈20.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=300.0, y=20.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.advance_time(16.0)
  ignore(runtime.draw_frame())
  let on_hover = runtime_test_hover_fill_count(runtime.draw_commands())
  // Hover must have appeared.
  if on_hover <= baseline {
    fail("hover fill did not appear: baseline=\{baseline} on_hover=\{on_hover}")
  }
  // Move the pointer off the overlay into the workspace center.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=200.0, y=150.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.advance_time(16.0)
  ignore(runtime.draw_frame())
  let after_off = runtime_test_hover_fill_count(runtime.draw_commands())
  // The hover background must clear (return to at most the baseline count).
  if after_off > baseline {
    fail(
      "hover did not clear after move-off: baseline=\{baseline} after_off=\{after_off}",
    )
  }
}
