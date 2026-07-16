///|
test "parse formats canonical workspace routes" {
  inspect(
    ShowcaseRoute::parse("components/button").format(),
    content="components/button",
  )
  inspect(
    ShowcaseRoute::parse("patterns/todo").format(),
    content="patterns/todo",
  )
  inspect(
    ShowcaseRoute::parse("platform/mobile-service-probe").format(),
    content="platform/mobile-service-probe",
  )
  inspect(
    ShowcaseRoute::parse("diagnostics/advanced-rendering").format(),
    content="diagnostics/advanced-rendering",
  )
}

///|
test "legacy bare routes map into workspaces" {
  inspect(
    ShowcaseRoute::parse("advanced-rendering").format(),
    content="diagnostics/advanced-rendering",
  )
  inspect(
    ShowcaseRoute::parse("runtime-renderer").format(),
    content="diagnostics/runtime-renderer",
  )
  inspect(
    ShowcaseRoute::parse("theme-renderer").format(),
    content="diagnostics/runtime-renderer",
  )
  inspect(ShowcaseRoute::parse("examples").format(), content="patterns/counter")
  inspect(
    ShowcaseRoute::parse("mobile-service-probe").format(),
    content="platform/mobile-service-probe",
  )
  inspect(ShowcaseRoute::parse("overview").format(), content="components/welcome")
}

///|
test "default routes" {
  inspect(ShowcaseRoute::default().format(), content="components/welcome")
  inspect(
    ShowcaseRoute::mobile_default().format(),
    content="platform/mobile-service-probe",
  )
  inspect(
    ShowcaseModel::new().current_route_string(),
    content="components/welcome",
  )
  inspect(
    ShowcaseModel::new(route="platform/mobile-service-probe")
    .current_route_string(),
    content="platform/mobile-service-probe",
  )
}
