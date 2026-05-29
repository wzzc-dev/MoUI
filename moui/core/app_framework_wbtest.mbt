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
test "router helpers resolve params snapshots and fallback routes" {
  let router = RouterState::new(initial=RouteLocation::new(path="/home"))
  router.push(
    RouteLocation::new(path="/detail", query=[
      RouteQueryParam::new(key="id", value="42"),
      RouteQueryParam::new(key="tab", value="activity"),
    ]),
  )
  let current = router.current()
  inspect(current.param_value("id").unwrap_or(""), content="42")
  inspect(current.params().length(), content="2")
  let snapshot = router.snapshot()
  inspect(snapshot.routes.length(), content="2")
  router.replace(RouteLocation::new(path="/other"))
  inspect(router.current().path, content="/other")
  router.restore(snapshot)
  inspect(router.current().to_route(), content="/detail?id=42&tab=activity")
  let routes = [
    RouteDescriptor::new(id="home", path="/home", title="Home"),
    RouteDescriptor::new(id="detail", path="/detail", title="Detail"),
    RouteDescriptor::new(id="missing", path="/missing", fallback=true),
  ]
  match router.resolve(routes) {
    Some({ id: "detail", title: "Detail", .. }) => ()
    _ => fail("expected detail route")
  }
  router.replace(RouteLocation::new(path="/unknown"))
  match router.resolve(routes) {
    Some({ id: "missing", fallback: true, .. }) => ()
    _ => fail("expected fallback route")
  }
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
test "form controller aggregates rules and first invalid field" {
  let name = FormFieldState::new(
    name="name",
    label="Name",
    rules=[FormValidationRule::required(message="Name required")],
  )
  let email = FormFieldState::new(
    name="email",
    initial="ada",
    rules=[
      FormValidationRule::required(message="Email required"),
      FormValidationRule::new(
        message="Email must contain @",
        validate=value => value.contains("@"),
      ),
    ],
  )
  let controller = FormController::new(fields=[name, email])
  let summary = controller.validate()
  inspect(summary.valid, content="false")
  inspect(summary.errors.length(), content="2")
  inspect(summary.first_invalid_id.unwrap_or(""), content="name")
  inspect(controller.field_error("email"), content="Email must contain @")
  name.value.set("Ada")
  email.value.set("ada@example.com")
  let valid = controller.validate()
  inspect(valid.valid, content="true")
  inspect(valid.first_invalid_id is None, content="true")
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
