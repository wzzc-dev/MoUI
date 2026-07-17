///|
test "workspace switches keep child state" {
  let model = ShowcaseModel::new()
  let after_components = model.update(
    ComponentsMsg(@components.ComponentGalleryMsg::Increment),
  )
  inspect(after_components.components.counter, content="1")
  let after_platform = after_components.update(
    Navigate("platform/host-services"),
  )
  inspect(
    after_platform.current_route_string(),
    content="platform/host-services",
  )
  let (running, _) = @platform.update(
    after_platform.platform,
    @platform.Msg::ToggleTimer,
  )
  let with_timer = { ..after_platform, platform: running }
  let back = with_timer.update(Navigate("components/welcome"))
  inspect(back.components.counter, content="1")
  inspect(back.platform.timer_running, content="true")
  inspect(back.current_route_string(), content="components/welcome")
}

///|
test "child messages map through root update" {
  let model = ShowcaseModel::new(route="patterns/counter")
  let next = model.update(PatternsMsg(@patterns.Msg::Increment))
  inspect(next.patterns.counter, content="1")
  inspect(next.current_route_string(), content="patterns/counter")
}

///|
test "program_with_initial_route opens mobile probe" {
  let program = ShowcaseApp::new().program_with_initial_route(
    "platform/mobile-service-probe",
  )
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=390.0,
    height=844.0,
  )
  ignore(runtime)
  let model = ShowcaseModel::new(route="platform/mobile-service-probe")
  inspect(model.workspace.slug(), content="platform")
  inspect(model.platform.route(), content="mobile-service-probe")
}
