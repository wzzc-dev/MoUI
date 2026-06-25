///|

///|
test "markdown editor working directory starts empty" {
  let app = MarkdownEditorApp::new()
  inspect(app.working_directory(), content="")
  inspect(@debug.to_string(app.expanded_tree_paths()), content="[]")
}

///|
test "markdown editor pick working directory stores chosen folder" {
  let app = MarkdownEditorApp::new()
  let services = markdown_editor_file_dialog_services(
    selected_path="/tmp/project",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  inspect(app.working_directory(), content="/tmp/project")
  inspect(@debug.to_string(app.expanded_tree_paths()), content="[\"/tmp/project\"]")
  inspect(app.transfer_status_label_for_test(), content="")
}

///|
test "markdown editor pick working directory preserves recent files" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Note", path="/tmp/project/Note.md")
  let services = markdown_editor_file_dialog_services(
    selected_path="/tmp/project",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  inspect(app.working_directory(), content="/tmp/project")
  inspect(app.document_path(), content="/tmp/project/Note.md")
  inspect(app.recent_document_paths().length(), content="1")
  inspect(app.recent_document_paths()[0], content="/tmp/project/Note.md")
}

///|
test "markdown editor tree path opens recent markdown file" {
  let app = MarkdownEditorApp::new()
  let services = markdown_editor_file_dialog_services(
    selected_path="",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  ignore(app.update_with_services(
    SelectTreePath("/tmp/project/README.md"),
    services,
  ))
  inspect(app.transfer_status_label_for_test(), content="Opening file")
}

///|
test "markdown editor file sidebar renders optional directory tree" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawText({ text: "Files", .. })),
  )
  assert_false(
    commands.any(command => command is @core.DrawCommand::DrawText({ text: "Journal.md", .. })),
  )
  app.load_document_for_test("# Note", path="/tmp/project/Note.md")
  // Inline mock that returns realistic directory entries for the tree test
  let entries = [
    @host.HostDirectoryEntry::new(
      name="README.md",
      path="/tmp/project/README.md",
    ),
    @host.HostDirectoryEntry::new(
      name="Journal.md",
      path="/tmp/project/Journal.md",
    ),
  ]
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(_) =>
          @host.HostServiceResponse::DirectoryListing("/tmp/project", entries)
        _ =>
          @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  app.pick_working_directory_for_test(@host.HostAppServices::new(bridge~))
  let expanded = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    expanded.any(command => command is @core.DrawCommand::DrawText({ text: "Files", .. })),
  )
  assert_true(
    expanded.any(command => command is @core.DrawCommand::DrawText({ text: "README.md", .. })),
  )
}

///|
test "markdown editor tree toggle preserves expansion order" {
  let app = MarkdownEditorApp::new()
  ignore(app.update(ToggleTreePath("b")))
  ignore(app.update(ToggleTreePath("a")))
  inspect(app.expanded_tree_paths().length(), content="2")
  inspect(app.expanded_tree_paths()[0], content="b")
  inspect(app.expanded_tree_paths()[1], content="a")
  ignore(app.update(ToggleTreePath("a")))
  inspect(app.expanded_tree_paths().length(), content="1")
  inspect(app.expanded_tree_paths()[0], content="b")
}

//|
test "markdown editor file tree starts expanded" {
  let app = MarkdownEditorApp::new()
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="true")
}

//|
test "markdown editor toggle file tree fold hides tree" {
  let app = MarkdownEditorApp::new()
  ignore(app.update(ToggleFileTree))
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="false")
  ignore(app.update(ToggleFileTree))
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="true")
}
