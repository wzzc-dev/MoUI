///|
test "markdown editor app emits primary wysiwyg commands" {
  let app = MarkdownEditorApp::new()
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Editor notes", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Editor notes", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "• ", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor page decoration keeps editor interactive" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  inspect(app.document(), content="Hi")
}

///|
test "markdown editor controlled runtime rebuilds after input" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Program path")),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Program path", .. })
    }),
  )
  assert_true(app.dirty())
}

///|
fn markdown_editor_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_text_font_size(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Double? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, font: { size, .. }, .. }) =>
        if value == text {
          return Some(size)
        }
      _ => ()
    }
  }
  None
}

///|
fn markdown_editor_clipboard_services(
  read_text~ : String,
  written~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(read_text)
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteText(text)
        ) => {
          written.val = text
          @host.HostServiceResponse::ClipboardWritten
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_file_dialog_services(
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(options) => {
          seen_kind.val = options.kind
          seen_title.val = options.title
          seen_default_name.val = match options.default_name {
            Some(name) => name
            None => ""
          }
          @host.HostServiceResponse::FileDialogSelection(
            if selected_path == "" {
              []
            } else {
              [selected_path]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, "")
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_document_services(
  read_text~ : String,
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => @host.HostServiceResponse::ClipboardText(read_text)
        @host.HostServiceRequest::FileDialog(options) => {
          seen_kind.val = options.kind
          seen_title.val = options.title
          seen_default_name.val = match options.default_name {
            Some(name) => name
            None => ""
          }
          @host.HostServiceResponse::FileDialogSelection(
            if selected_path == "" {
              []
            } else {
              [selected_path]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, read_text)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_link_services(
  opened~ : Ref[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(open_url=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::OpenUrl(url) => {
          opened.val = url
          @host.HostServiceResponse::UrlOpened
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn markdown_editor_async_clipboard_read_services(
  queue : @host.HostServiceAsyncQueue,
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~, async_queue=Some(queue))
}

///|
fn markdown_editor_async_file_dialog_services(
  queue : @host.HostServiceAsyncQueue,
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) => queue.submit(request)
        @host.HostServiceRequest::TextFile(_) => queue.submit(request)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~, async_queue=Some(queue))
}
