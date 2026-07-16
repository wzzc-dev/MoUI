///|
test "router state parses pushes replaces and pops route locations" {
  let router = RouterState::new(
    initial=RouteLocation::parse("/home?tab=overview"),
  )
  inspect(router.current().path, content="/home")
  inspect(router.current().query_value("tab").unwrap_or(""), content="overview")
  router.push(
    RouteLocation::new(path="/settings", query=[
      RouteQueryParam::new(key="section", value="display"),
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
test "route history tracks deep links back forward and router snapshots" {
  let initial = RouteHistoryState::from_deep_link(
    "/home?tab=overview",
    title="Home",
  )
  inspect(initial.current().path, content="/home")
  inspect(initial.current_route(), content="/home?tab=overview")
  inspect(initial.current_entry().unwrap().source, content="deep-link")
  let settings = initial.push(
    RouteLocation::new(path="/settings"),
    title="Settings",
  )
  let detail = settings.replace(
    RouteLocation::parse("/settings?panel=display"),
    title="Settings",
  )
  inspect(detail.entries.length(), content="2")
  inspect(detail.entries[1].title, content="Settings")
  inspect(detail.current_route(), content="/settings?panel=display")
  assert_true(detail.can_go_back())
  let home = detail.back()
  inspect(home.current_route(), content="/home?tab=overview")
  assert_true(home.can_go_forward())
  let profile = home.push(RouteLocation::new(path="/profile"), title="Profile")
  inspect(profile.entries.length(), content="2")
  inspect(profile.current_route(), content="/profile")
  assert_false(profile.can_go_forward())
  let router = RouterState::new(initial=RouteLocation::new(path="/placeholder"))
  profile.restore_router(router)
  inspect(router.current().to_route(), content="/profile")
  let restored = RouteHistoryState::from_snapshot(
    detail.router_snapshot(),
    source="router",
  )
  inspect(restored.entries.length(), content="2")
  inspect(restored.current_route(), content="/settings?panel=display")
  inspect(restored.entries[0].source, content="router")
}
