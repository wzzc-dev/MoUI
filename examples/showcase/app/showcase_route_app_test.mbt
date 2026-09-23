///|
test "parse formats canonical workspace routes" {
  inspect(
    @app.ShowcaseRoute::parse("components/button").format(),
    content="components/button",
  )
  inspect(
    @app.ShowcaseRoute::parse("patterns/todo").format(),
    content="patterns/todo",
  )
  inspect(
    @app.ShowcaseRoute::parse("platform/mobile-service-probe").format(),
    content="platform/mobile-service-probe",
  )
  inspect(
    @app.ShowcaseRoute::parse("diagnostics/advanced-rendering").format(),
    content="diagnostics/advanced-rendering",
  )
}

///|
test "legacy bare routes map into workspaces" {
  inspect(
    @app.ShowcaseRoute::parse("advanced-rendering").format(),
    content="diagnostics/advanced-rendering",
  )
  inspect(
    @app.ShowcaseRoute::parse("runtime-renderer").format(),
    content="diagnostics/runtime-renderer",
  )
  inspect(
    @app.ShowcaseRoute::parse("theme-renderer").format(),
    content="diagnostics/runtime-renderer",
  )
  inspect(
    @app.ShowcaseRoute::parse("examples").format(),
    content="patterns/counter",
  )
  inspect(
    @app.ShowcaseRoute::parse("mobile-service-probe").format(),
    content="platform/mobile-service-probe",
  )
  inspect(
    @app.ShowcaseRoute::parse("overview").format(),
    content="components/welcome",
  )
}

///|
test "default routes" {
  inspect(@app.ShowcaseRoute::default().format(), content="components/welcome")
  inspect(
    @app.ShowcaseRoute::mobile_default().format(),
    content="platform/mobile-service-probe",
  )
  inspect(
    @app.ShowcaseModel::new().current_route_string(),
    content="components/welcome",
  )
  inspect(
    @app.ShowcaseModel::new(route="platform/mobile-service-probe").current_route_string(),
    content="platform/mobile-service-probe",
  )
}
