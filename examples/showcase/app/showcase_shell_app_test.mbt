///|
test "global catalog merges packages into categories" {
  let model = ShowcaseModel::new(route="components/welcome")
  let groups = model.catalog_groups().map(group => group.id)
  assert_true(groups.contains("start"))
  assert_true(groups.contains("controls"))
  assert_true(groups.contains("patterns"))
  assert_true(groups.contains("platform"))
  assert_true(groups.contains("runtime"))
  let items = model.catalog_items()
  assert_true(items.any(item => item.route() == "components/button"))
  assert_true(items.any(item => item.route() == "patterns/todo"))
  assert_true(
    items.any(item => item.route() == "platform/mobile-service-probe"),
  )
  assert_true(
    items.any(item => item.route() == "diagnostics/advanced-rendering"),
  )
  // Probe only under Platform, not Components.
  assert_false(
    items.any(item => {
      item.workspace == "components" && item.id == "mobile-service-probe"
    }),
  )
  inspect(
    items.filter(item => item.group_id == "runtime").length(),
    content="5",
  )
}

///|
test "nav query filters across workspaces" {
  let model = ShowcaseModel::new(route="components/welcome").update(
    NavQueryChanged("todo"),
  )
  let filtered = model.filtered_catalog_items()
  assert_true(filtered.length() >= 1)
  assert_true(filtered.any(item => item.route() == "patterns/todo"))
}

///|
test "current catalog item resolves full route" {
  let model = ShowcaseModel::new(route="platform/mobile-service-probe")
  guard model.current_catalog_item() is Some(item) else {
    fail("expected catalog item")
  }
  inspect(item.route(), content="platform/mobile-service-probe")
  inspect(item.group_id, content="platform")
}
