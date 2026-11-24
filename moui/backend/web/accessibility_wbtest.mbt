///|
test "web aria roles name the new semantics roles" {
  inspect(aria_role(@core.TabList), content="tablist")
  inspect(aria_role(@core.Toolbar), content="toolbar")
  inspect(aria_role(@core.MenuItem), content="menuitem")
}
