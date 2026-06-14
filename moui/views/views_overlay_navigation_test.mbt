///|
test "navigation shell components compose sidebar breadcrumb split and wizard" {
  let nav_items = [
    @views.SidebarItem::new(id="home", label="Home", message=()),
    @views.SidebarItem::new(id="settings", label="Settings", message=()),
  ]
  let section_items = [
    @views.SectionNavItem::new(
      id="builder",
      label="Builder",
      summary="App setup",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="runtime",
      label="Runtime",
      summary="Renderer and host state",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="billing",
      label="Billing",
      summary="Disabled section",
      message=(),
      enabled=false,
    ),
  ]
  let crumbs = [
    @views.BreadcrumbItem::new(id="root", label="Root", message=Some(())),
    @views.BreadcrumbItem::new(id="current", label="Current"),
  ]
  let steps = [
    @views.WizardStep::new(
      id="first",
      title="First",
      content=@views.text("First content", width=180.0),
    ),
    @views.WizardStep::new(
      id="second",
      title="Second",
      content=@views.text("Second content", width=180.0),
      enabled=false,
    ),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.route_header("Settings", subtitle="Manage workspace preferences", actions=[
      @views.MenuItem::new(id="save", label="Save", message=()),
      @views.MenuItem::new(
        id="export",
        label="Export",
        message=(),
        enabled=false,
      ),
    ]),
    @views.breadcrumb(crumbs),
    @views.section_nav(
      "Product Areas",
      section_items,
      selected="runtime",
      orientation=@core.Axis::Vertical,
      width=220.0,
    ),
    @views.split_view(
      primary=@views.sidebar("Sections", nav_items, selected="settings"),
      detail=@views.master_detail(
        master=@views.text("Master", width=120.0),
        detail=@views.text("Detail", width=160.0),
        master_width=120.0,
        detail_width=160.0,
        height=80.0,
      ),
      primary_width=220.0,
      detail_width=300.0,
      height=180.0,
    ),
    @views.wizard(steps, current="first", on_select=_route => ()),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=620.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Manage workspace preferences"))
  assert_true(has_text(commands, "Save"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Current"))
  assert_true(has_text(commands, "Product Areas"))
  assert_true(has_text(commands, "Builder"))
  assert_true(has_text(commands, "Renderer and host state"))
  assert_true(has_text(commands, "Disabled section"))
  assert_true(has_text(commands, "Sections"))
  assert_true(has_text(commands, "Home"))
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Master"))
  assert_true(has_text(commands, "Detail"))
  assert_true(has_text(commands, "First"))
  assert_true(has_text(commands, "Second"))
  assert_true(has_text(commands, "First content"))
  guard find_semantics_label(
      runtime.semantics(),
      "Runtime, Renderer and host state",
    )
    is Some(runtime_section) else {
    fail("expected selected section navigation item semantics")
  }
  assert_true(runtime_section.role == @core.SemanticsRole::ListItem)
  assert_true(runtime_section.state.selected)
  guard find_semantics_label(runtime.semantics(), "Billing, Disabled section")
    is Some(disabled_section) else {
    fail("expected disabled section navigation item semantics")
  }
  assert_true(disabled_section.state.disabled)
}
