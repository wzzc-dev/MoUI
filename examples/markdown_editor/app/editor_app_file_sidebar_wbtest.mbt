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
  inspect(
    @debug.to_string(app.expanded_tree_paths()),
    content="[\"/tmp/project\"]",
  )
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
  app.dispatch_message_for_test(
    services,
    SelectTreePath("/tmp/project/README.md"),
  )
  inspect(app.transfer_status_label_for_test(), content="Opened README.md")
}

///|
test "markdown editor file sidebar renders optional directory tree" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Files", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Journal.md", .. })
    }),
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
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  app.pick_working_directory_for_test(@backend_common.app_services(bridge~))
  let expanded = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    expanded.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Files", .. })
    }),
  )
  assert_true(
    expanded.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
}

///|
test "markdown editor file sidebar pins empty folder prompt to top" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Files") is Some(files_frame) else {
    fail("expected files sidebar title")
  }
  assert_true(files_frame.origin.y < 80.0)
}

///|
test "markdown editor files and outline sidebars fit narrow window" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n## Section")
  app.set_file_sidebar_visible(true)
  app.set_outline_visible(true)
  let window_width = 980.0
  let commands = app.runtime(width=window_width, height=640.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Outline") is Some(outline_frame) else {
    fail("expected outline sidebar title")
  }
  guard markdown_editor_text_frame(commands, "H1 Title") is Some(heading_frame) else {
    fail("expected outline heading")
  }
  assert_true(outline_frame.origin.x + outline_frame.size.width <= window_width)
  assert_true(heading_frame.origin.x + heading_frame.size.width <= window_width)
}

///|
test "markdown editor file tree lazily expands subdirectories" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let read_path = Ref("")
  let listed_paths : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) => {
          listed_paths.push(path)
          if path == "/tmp/project" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="notes",
                path="/tmp/project/notes",
                is_directory=true,
              ),
            ])
          } else if path == "/tmp/project/notes" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="daily.md",
                path="/tmp/project/notes/daily.md",
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [])
          }
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => {
          read_path.val = path
          @host.HostServiceResponse::TextFileContent(path, "# Daily")
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  inspect(listed_paths.length(), content="1")
  inspect(listed_paths[0], content="/tmp/project")

  app.dispatch_message_for_test(services, SelectTreePath("/tmp/project/notes"))
  inspect(listed_paths.length(), content="2")
  inspect(listed_paths[1], content="/tmp/project/notes")
  inspect(read_path.val, content="")
  inspect(app.transfer_status_label_for_test(), content="")
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "daily.md", .. })
    }),
  )

  app.dispatch_message_for_test(
    services,
    SelectTreePath("/tmp/project/notes/daily.md"),
  )
  inspect(read_path.val, content="/tmp/project/notes/daily.md")
  inspect(app.transfer_status_label_for_test(), content="Opened daily.md")
}

///|
test "markdown editor file tree sorts folders before files by name" {
  let sorted = markdown_editor_sorted_directory_entries([
    @services.DirectoryEntry::{
      name: "zeta.md",
      path: "/tmp/project/zeta.md",
      is_directory: false,
    },
    @services.DirectoryEntry::{
      name: "drafts",
      path: "/tmp/project/drafts",
      is_directory: true,
    },
    @services.DirectoryEntry::{
      name: "Alpha.md",
      path: "/tmp/project/Alpha.md",
      is_directory: false,
    },
    @services.DirectoryEntry::{
      name: "Archive",
      path: "/tmp/project/Archive",
      is_directory: true,
    },
  ])
  inspect(sorted.length(), content="4")
  inspect(sorted[0].name, content="Archive")
  inspect(sorted[1].name, content="drafts")
  inspect(sorted[2].name, content="Alpha.md")
  inspect(sorted[3].name, content="zeta.md")
}

///|
test "markdown editor file tree refresh reloads picked folder" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let version = Ref(0)
  let listed_paths : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) => {
          listed_paths.push(path)
          if version.val == 0 {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="old.md",
                path="/tmp/project/old.md",
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="new.md",
                path="/tmp/project/new.md",
              ),
            ])
          }
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  let initial = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    initial.any(command => {
      command is @core.DrawCommand::DrawText({ text: "old.md", .. })
    }),
  )
  assert_true(
    initial.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Refresh folder", .. })
    }),
  )

  version.val = 1
  app.dispatch_message_for_test(services, RefreshFileTree)
  inspect(listed_paths.length(), content="2")
  inspect(listed_paths[1], content="/tmp/project")
  let refreshed = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    refreshed.any(command => {
      command is @core.DrawCommand::DrawText({ text: "new.md", .. })
    }),
  )
  assert_false(
    refreshed.any(command => {
      command is @core.DrawCommand::DrawText({ text: "old.md", .. })
    }),
  )
}

///|
test "markdown editor file sidebar filters tree and recent files" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  app.load_document_for_test("# Daily", path="/tmp/project/notes/daily.md")
  app.load_document_for_test("# Ideas", path="/tmp/project/ideas.md")
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) =>
          if path == "/tmp/project" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="README.md",
                path="/tmp/project/README.md",
              ),
              @host.HostDirectoryEntry::new(
                name="notes",
                path="/tmp/project/notes",
                is_directory=true,
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="daily.md",
                path="/tmp/project/notes/daily.md",
              ),
            ])
          }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  app.dispatch_message_for_test(services, SelectTreePath("/tmp/project/notes"))

  ignore(app.update(UpdateFileFilterQuery("daily")))
  let filtered = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "daily.md", .. })
    }),
  )
  assert_false(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
  let filtered_recent = markdown_editor_filter_file_paths(
    app.recent_document_paths(),
    "daily",
  )
  inspect(filtered_recent.length(), content="1")
  inspect(filtered_recent[0], content="/tmp/project/notes/daily.md")

  ignore(app.update(UpdateFileFilterQuery("missing")))
  let missing = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    missing.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No matching files", .. })
    }),
  )
  assert_true(
    missing.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "No matching recent files", .. })
    }),
  )

  ignore(app.update(UpdateFileFilterQuery("")))
  let cleared = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    cleared.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
  assert_true(
    cleared.any(command => {
      command is @core.DrawCommand::DrawText({ text: "ideas.md", .. })
    }),
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

///|
test "markdown editor file tree starts expanded" {
  let app = MarkdownEditorApp::new()
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="true")
}

//|

///|
test "markdown editor toggle file tree fold hides tree" {
  let app = MarkdownEditorApp::new()
  ignore(app.update(ToggleFileTree))
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="false")
  ignore(app.update(ToggleFileTree))
  inspect(@debug.to_string(app.file_tree_expanded.get()), content="true")
}
