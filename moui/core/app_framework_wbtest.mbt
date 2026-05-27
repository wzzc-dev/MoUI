///|
test "router state parses pushes replaces and pops route locations" {
  let router = RouterState::new(
    initial=RouteLocation::parse("/home?tab=overview"),
  )
  inspect(router.current().path, content="/home")
  inspect(router.current().query_value("tab").unwrap_or(""), content="overview")
  router.push(
    RouteLocation::new(path="/settings", query=[
      { key: "section", value: "display" },
    ]),
  )
  inspect(router.current().to_route(), content="/settings?section=display")
  router.replace(RouteLocation::new(path="/profile"))
  inspect(router.current().path, content="/profile")
  assert_true(router.pop())
  inspect(router.current().path, content="/home")
}

///|
test "form fields validate required values" {
  let name = FormFieldState::new(
    name="name",
    validator=required_field(message="Name required"),
  )
  let email = FormFieldState::new(name="email", initial="a@example.com")
  let invalid = validate_form([name, email])
  inspect(invalid.valid, content="false")
  inspect(invalid.errors.length(), content="1")
  inspect(invalid.errors[0].message, content="Name required")
  name.value.set("Ada")
  let valid = validate_form([name, email])
  inspect(valid.valid, content="true")
  inspect(valid.errors.length(), content="0")
}

///|
test "runtime inspector and frame profile expose devtool counters" {
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "Inspect",
      size: Size::new(width=80.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  let snapshot = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(snapshot.draw_command_count, content="2")
  inspect(snapshot.dirty_count, content="0")
  let layout = LayoutInspectorSnapshot::from_runtime(runtime)
  inspect(layout.node_count, content="1")
  inspect(layout.leaf_count, content="1")
  inspect(layout.max_depth, content="1")
  let render = RenderInspectorSnapshot::from_runtime(runtime)
  inspect(render.command_count, content="2")
  inspect(render.text_count, content="1")
  inspect(render.clip_depth, content="0")
  inspect(render.open_clip_depth, content="0")
  inspect(render.unbalanced_pop_count, content="0")
  let semantics = SemanticsInspectorSnapshot::from_runtime(runtime)
  assert_true(semantics.root_role == SemanticsRole::Text)
  inspect(semantics.node_count, content="1")
  inspect(semantics.action_count, content="0")
  let profile = FrameProfile::capture(
    runtime,
    Frame::new(time_ms=16.0, delta_ms=16.0),
  )
  inspect(profile.draw_command_count, content="2")
  inspect(profile.active_animations, content="0")
}

///|
test "render inspector reports open scopes and unbalanced pops" {
  let inspected = RenderInspectorSnapshot::from_commands([
    DrawCommand::PopClip,
    DrawCommand::PushClip(Rect::new(x=0.0, y=0.0, width=20.0, height=20.0)),
    DrawCommand::PushLayer(LayerSpec::new(opacity=0.5, offscreen=true)),
    DrawCommand::PopFilter,
    DrawCommand::DrawText(
      TextRun::new(
        text="One",
        frame=Rect::new(x=0.0, y=0.0, width=60.0, height=20.0),
        font=FontSpec::new(size=12.0, weight=400),
        color=Color::black(),
        align=TextAlign::TextStart,
      ),
    ),
  ])
  inspect(inspected.clip_depth, content="1")
  inspect(inspected.open_clip_depth, content="1")
  inspect(inspected.layer_depth, content="1")
  inspect(inspected.open_layer_depth, content="1")
  inspect(inspected.filter_depth, content="0")
  inspect(inspected.open_filter_depth, content="0")
  inspect(inspected.unbalanced_pop_count, content="2")
}
