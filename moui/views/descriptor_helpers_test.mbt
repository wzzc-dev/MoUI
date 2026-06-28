///|
enum DescriptorHelperMsg {
  Open
  Close
  Select(String)
}

///|
test "descriptor helper functions mirror typed constructors" {
  let action = action_item(id="open", label="Open", message=Open)
  assert_eq(action.id, "open")
  assert_eq(action.label, "Open")
  assert_true(action.enabled)
  guard action.message is Open else { fail("expected open message") }
  let disabled_action = action_item(
    id="close",
    label="Close",
    message=Close,
    enabled=false,
  )
  assert_false(disabled_action.enabled)
  guard disabled_action.message is Close else { fail("expected close message") }
  let menu = menu_item(id="file", label="File", message=Select("file"))
  assert_eq(menu.id, "file")
  let section = section_nav_item(
    id="data",
    label="Data",
    summary="Tables",
    message=Select("data"),
  )
  assert_eq(section.summary, "Tables")
  let sidebar = sidebar_item(id="home", label="Home", message=Select("home"))
  assert_eq(sidebar.label, "Home")
  let breadcrumb = breadcrumb_item(
    id="details",
    label="Details",
    message=Some(Select("details")),
  )
  guard breadcrumb.message is Some(Select("details")) else {
    fail("expected breadcrumb message")
  }
  let list_item = selectable_list_item(
    id="atlas",
    title="Project Atlas",
    subtitle="Healthy",
    detail="Mira",
    message=Select("atlas"),
  )
  assert_eq(list_item.detail, "Mira")
}

///|
test "command menu section helper preserves command groups" {
  let command = @core.ActionCommand::new(
    label="Open",
    intent=@core.CommandIntent::Activate,
  )
  let section = command_menu_section(title="File", commands=[command])
  assert_eq(section.title, "File")
  assert_eq(section.commands.length(), 1)
}
