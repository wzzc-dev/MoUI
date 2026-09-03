///|
fn[Msg] runtime_test_rect(
  width~ : Double,
  height~ : Double,
  color~ : @core.Color,
  on_tap? : Msg? = None,
) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="Rect"),
    declaration=() => {
      runtime_fixture_exact_declaration("Rect", [
        ("width", @core.DeclarationKey::double(width)),
        ("height", @core.DeclarationKey::double(height)),
        ("red", @core.DeclarationKey::double(color.r)),
        ("green", @core.DeclarationKey::double(color.g)),
        ("blue", @core.DeclarationKey::double(color.b)),
        ("alpha", @core.DeclarationKey::double(color.a)),
      ])
    },
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
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="Padding", key~),
    declaration=() => {
      runtime_fixture_exact_declaration("Padding", [
        ("top", @core.DeclarationKey::double(insets.top)),
        ("right", @core.DeclarationKey::double(insets.right)),
        ("bottom", @core.DeclarationKey::double(insets.bottom)),
        ("left", @core.DeclarationKey::double(insets.left)),
      ])
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
  if snapshot.view_tree().root_kind() != "Padding" {
    fail("expected virtual node kind in inspector")
  }
  match snapshot.view_tree().nodes().get(0) {
    Some(node) =>
      if node.key() != "outer" {
        fail("expected virtual node key in inspector")
      }
    None => fail("expected inspector root node")
  }
}

///|
test "runtime-slot scroll dispatches its resulting offset" {
  let received : Array[@core.Point] = []
  let runtime = AppRuntime::new_view(
    root=@views.scroll_view(
      runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
      width=20.0,
      height=40.0,
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
  if received != [@core.Point::new(x=0.0, y=12.0)] {
    fail("expected virtual node scroll to dispatch on_scroll message")
  }
  let snapshot = runtime.inspector_snapshot()
  match snapshot.view_tree().nodes().get(0) {
    Some(node) =>
      if node.needs_build() {
        fail("expected committed semantics to drain the queued rebuild")
      }
    None => fail("expected inspector root node")
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
test "runtime dispatches declared accessibility activation by semantic node" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let snapshot = runtime_expect_full_semantics(runtime)
  let mut target : @core.SemanticsNodeId? = None
  for node in snapshot.nodes() {
    if node.actions.any(action => action == @core.SemanticsActionKind::Activate) {
      target = Some(node.node_id)
    }
  }
  guard target is Some(target) else {
    fail("expected button semantics activation target")
  }
  ignore(
    runtime_expect_semantics_action(
      runtime,
      @core.SemanticsTarget::ByNodeId(target),
      @core.SemanticsAction::Activate,
      snapshot.generation(),
    ),
  )
  assert_true(received == ["clicked"])
  match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::ByNodeId(target),
      action: @core.SemanticsAction::SetText("nope"),
      precondition: SemanticsGenerationPrecondition::Latest,
    }) {
    Err(ActionUnavailable(_, @core.SemanticsActionKind::SetText)) => ()
    _ => fail("expected unavailable SetText action")
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
    // Column wrapper: a root-level frame stretches to the window constraints,
    // which would put the picker's own frame under the click point.
    root=@views.column(
      [
        @views.frame(
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
      ],
      spacing=0.0,
    ),
    // The window is tall enough for the popup to fit below the anchor: the
    // placement pass clamps popups into the viewport instead of painting them
    // beyond the window edge like the old overlay-command popups.
    size=@core.Size::new(width=200.0, height=160.0),
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
  // Opening re-runs layout (the popup becomes a placed overlay child) and the
  // relayout completes inside dispatch, so the observable is a pending redraw
  // at the runtime level rather than a stale per-node dirty flag.
  if !(runtime.needs_paint() || runtime.needs_redraw()) {
    fail("expected opening picker to request a repaint")
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
  // Node order shifted with the wrapper: frame -> picker. The picker keeps
  // its virtual-node identity across the popup child subtree.
  match snapshot.view_tree().nodes().get(2) {
    Some(node) =>
      if node.kind() != "Picker" {
        fail("expected picker virtual node identity in inspector")
      }
    None => fail("expected picker inspector node")
  }
  if snapshot.view_tree().root_kind() != "Flex" {
    fail("expected picker virtual node identity in inspector")
  }
}

///|
test "picker overlay receives pointer events before covered siblings" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        @views.frame(
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
        @views.button(
          "Covered action",
          on_click="covered",
          width=200.0,
          height=120.0,
        ),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=200.0, height=160.0),
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
    fail("expected picker overlay to win over the covered sibling")
  }
}

///|
test "picker overlay keeps focus off covered text field on pointer down" {
  // Reproduces playground: expanded picker popup paints over a later sibling
  // text field. Pointer Down must not focus the covered field (which would move
  // its caret), and selection Up must still hit the picker overlay.
  let received : Array[String] = []
  let mut field_value = "line one\nline two\nline three"
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        @views.frame(
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
        @views.text_field(
          field_value,
          on_input=value => {
            field_value = value
            "field"
          },
          placeholder="Covered field",
          width=200.0,
          height=120.0,
        ),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=200.0, height=160.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  // Focus the text field first (click inside it while picker is closed).
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=100.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=100.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if !runtime.focused_text_input().focused {
    fail("expected text field to take focus before opening picker")
  }
  let caret_before = runtime.focused_text_input().caret
  // Open picker.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  // Down on the popup (over the covered field). Focus must leave the field so
  // caret placement under the popup cannot run.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if runtime.focused_text_input().focused {
    fail("expected picker overlay Down to steal focus from covered text field")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=84.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != ["two"] {
    fail("expected picker overlay selection while covering a text field")
  }
  // Covered field must not have been edited by the popup click.
  if field_value != "line one\nline two\nline three" {
    fail("expected covered text field value to stay unchanged")
  }
  ignore(caret_before)
}

///|
test "virtual node datepicker dispatches overlay selection without core primitive" {
  let received : Array[@core.DateValue] = []
  let runtime = AppRuntime::new_view(
    // Column wrapper: a root-level frame stretches to the window constraints,
    // which would put the datepicker's own frame under the click point.
    root=@views.column(
      [
        @views.frame(
          @views.datepicker(
            selected=@core.DateValue::new(year=2024, month=1, day=15),
            on_select=value => value,
            mode=@views.DatePickerMode::Date,
            placeholder="Select date",
          ),
          width=200.0,
          height=40.0,
        ),
      ],
      spacing=0.0,
    ),
    // The window is tall enough for the calendar panel to fit below the
    // anchor: the placement pass clamps popups into the viewport instead of
    // painting them beyond the window edge like the old overlay-command
    // popups.
    size=@core.Size::new(width=280.0, height=420.0),
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
  // Node order: column -> frame -> datepicker.
  match snapshot.view_tree().nodes().get(2) {
    Some(node) =>
      if node.kind() != "DatePicker" {
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
  if snapshot.view_tree().root_kind() != "Sheet" {
    fail("expected sheet virtual node identity in inspector")
  }
}

///|
test "runtime semantics includes declared state modifiers" {
  let root : @core.View[Unit] = @views.text("Stateful", width=80.0, height=24.0)
    .semantics_role(@core.SemanticsRole::Checkbox)
    .semantics_checked(checked=@core.SemanticsCheckedState::Checked)
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
  let snapshot = runtime_expect_full_semantics(runtime)
  let semantics = snapshot.nodes()[0]
  assert_eq(semantics.state.checked, Some(@core.SemanticsCheckedState::Checked))
  assert_true(semantics.state.selected)
  assert_true(semantics.state.pressed)
  assert_true(semantics.state.expanded)
  assert_true(semantics.state.invalid)
  assert_true(semantics.state.required)
  assert_true(semantics.state.disabled)
}

///|
test "runtime semantics preserves heading level and link url" {
  let root : @core.View[Unit] = @views.text("API", width=80.0, height=24.0)
    .semantics_role(@core.SemanticsRole::Heading)
    .semantics_level(2)
    .semantics_url("https://example.test/api")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=32.0),
  )
  let semantics = runtime_expect_full_semantics(runtime).nodes()[0]
  assert_true(semantics.role == @core.SemanticsRole::Heading)
  assert_true(semantics.level == Some(2))
  assert_true(semantics.url == "https://example.test/api")
}

///|
test "runtime dispatches semantic activation through typed action route" {
  let received : Array[Int] = []
  let root = @views.text("Open", width=80.0, height=24.0)
    .on_tap(7)
    .semantics_role(@core.SemanticsRole::Link)
    .semantics_url("https://example.test")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let snapshot = runtime_expect_full_semantics(runtime)
  let mut target : @core.SemanticsNodeId? = None
  for node in snapshot.nodes() {
    if node.actions.any(action => action == @core.SemanticsActionKind::Activate) {
      target = Some(node.node_id)
    }
  }
  guard target is Some(target) else {
    fail("expected tap modifier semantics activation target")
  }
  ignore(
    runtime_expect_semantics_action(
      runtime,
      @core.SemanticsTarget::ByNodeId(target),
      @core.SemanticsAction::Activate,
      snapshot.generation(),
    ),
  )
  assert_true(received == [7])
}

///|
test "runtime scrolls nearest scroll view to keyed descendant" {
  let target : @core.View[Unit] = @views.text(
    "Target",
    width=100.0,
    height=40.0,
  ).key("target")
  let content = @views.column(
    [
      @views.text("Before", width=100.0, height=240.0),
      target,
      @views.text("After", width=100.0, height=120.0),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  )
  let runtime = AppRuntime::new_view(
    root=@views.scroll_view(content, width=100.0, height=100.0),
    size=@core.Size::new(width=100.0, height=100.0),
  )
  assert_true(
    runtime.scroll_to_key("target", alignment=@core.ScrollAlignment::Start),
  )
  assert_true(runtime.layout().children[0].frame.origin.y == -240.0)
  assert_true(!runtime.scroll_to_key("missing"))
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
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="HoverTracker"),
    declaration=() => {
      runtime_fixture_exact_declaration("HoverTracker", [
        ("width", @core.DeclarationKey::double(width)),
        ("height", @core.DeclarationKey::double(height)),
      ])
    },
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
  let root : @core.View[Unit] = runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="HoverStage"),
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
/// Regression: when the pointer moves from one sibling control directly onto
/// another, the previously hovered sibling must receive a synthetic `Exit`
/// even though the new sibling was hit first. This mirrors the button hover
/// case that can leave the old control painted in its hover state.
test "runtime clears hover when moving between sibling controls" {
  let left_log : Array[Bool] = []
  let right_log : Array[Bool] = []
  let root : @core.View[Unit] = runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="SiblingHoverStage"),
    children=() => {
      [
        runtime_test_hover_tracker(width=100.0, height=40.0, log=left_log),
        runtime_test_hover_tracker(width=100.0, height=40.0, log=right_log),
      ]
    },
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let frames : Array[@core.Rect] = []
      for index, _size in ctx.child_sizes {
        let x = if index == 0 { 0.0 } else { 100.0 }
        frames.push(@core.Rect::new(x~, y=0.0, width=100.0, height=40.0))
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
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=150.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  if left_log != [true, false] {
    let rendered = left_log
      .map(b => if b { "true" } else { "false" })
      .join(", ")
    fail("expected left hover log [true, false] but got [\{rendered}]")
  }
  if right_log != [true] {
    let rendered = right_log
      .map(b => if b { "true" } else { "false" })
      .join(", ")
    fail("expected right hover log [true] but got [\{rendered}]")
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
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="HoverPhaseTracker"),
    declaration=() => {
      runtime_fixture_exact_declaration("HoverPhaseTracker", [
        ("width", @core.DeclarationKey::double(width)),
        ("height", @core.DeclarationKey::double(height)),
      ])
    },
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
  let root : @core.View[Unit] = runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="HoverParent"),
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

///|
/// Regression for the showcase sidebar: a `text_field` placed above a
/// `scroll_view` becomes un-clickable after the list scrolls, because the
/// scroll container's child `paint_bounds` spills over the field and wins
/// hit-test. The fix clips each child's `paint_bounds` to a leading
/// `PushClip`/`PushRoundedClip` rect, so the scroll viewport only claims the
/// region it actually paints.
test "scroll_view child paint_bounds does not spill over earlier siblings" {
  let mut field_value = ""
  // Sidebar: search field on top, scrollable story list below. The list is
  // much taller than the viewport so scrolling pushes its paint region up.
  let stories : Array[@core.View[String]] = []
  for i = 0; i < 20; i = i + 1 {
    stories.push(
      @views.button(
        "Story \{i}",
        on_click="story-\{i}",
        width=180.0,
        height=34.0,
      ),
    )
  }
  let sidebar : @core.View[String] = @views.column(
    [
      @views.text_field(
        field_value,
        on_input=value => {
          field_value = value
          "search"
        },
        placeholder="Search stories…",
        width=180.0,
      ),
      @views.scroll_view(
        @views.column(stories, spacing=4.0),
        width=180.0,
        height=200.0,
      ),
    ],
    spacing=8.0,
  )
  let runtime = AppRuntime::new_view(
    root=sidebar,
    size=@core.Size::new(width=200.0, height=280.0),
  )
  ignore(runtime.draw_frame())
  // Before scrolling, clicking the search field focuses it.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if !runtime.focused_text_input().focused {
    fail("expected search field to take focus before scrolling")
  }
  // Move focus off the field.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=120.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if runtime.focused_text_input().focused {
    fail("expected focus to leave the search field")
  }
  // Scroll the list down so its child paint_bounds would historically grow up
  // over the search field.
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=160.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-300.0),
      ),
    ),
  )
  ignore(runtime.draw_frame())
  // Click the search field again. Without the fix, the scroll list's
  // paint_bounds covers the field and the click lands on a story button.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if !runtime.focused_text_input().focused {
    fail(
      "expected search field to remain clickable after the list scrolls (scroll_view child paint_bounds spilled over an earlier sibling)",
    )
  }
}
