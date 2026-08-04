///|
fn markdown_editor_clipboard_services(
  read_text~ : String,
  written~ : Ref[String],
) -> @services.AppServices {
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
  @host.app_services(bridge~)
}

///|
fn markdown_editor_file_dialog_services(
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @services.AppServices {
  let selected = selected_path
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
            if selected == "" {
              []
            } else {
              [selected]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, "")
        @host.HostServiceRequest::ListDirectory(_path) =>
          @host.HostServiceResponse::DirectoryListing(_path, [
            @host.HostDirectoryEntry::new(
              name="README.md",
              path=_path + "/README.md",
              is_directory=false,
            ),
            @host.HostDirectoryEntry::new(
              name="notes",
              path=_path + "/notes",
              is_directory=true,
            ),
          ])
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.app_services(bridge~)
}

///|
fn markdown_editor_document_services(
  read_text~ : String,
  selected_path~ : String,
  seen_kind~ : Ref[@host.HostFileDialogKind],
  seen_title~ : Ref[String],
  seen_default_name~ : Ref[String],
) -> @services.AppServices {
  let selected = selected_path
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
            if selected == "" {
              []
            } else {
              [selected]
            },
          )
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => @host.HostServiceResponse::TextFileContent(path, read_text)
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(path, _text)
        ) => @host.HostServiceResponse::TextFileWritten(path)
        @host.HostServiceRequest::ListDirectory(_path) =>
          @host.HostServiceResponse::DirectoryListing(_path, [])
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.app_services(bridge~)
}

///|
fn markdown_editor_link_services(
  opened~ : Ref[String],
) -> @services.AppServices {
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
  @host.app_services(bridge~)
}

///|
fn markdown_editor_async_clipboard_read_services(
  queue : @host.HostServiceAsyncQueue,
) -> @services.AppServices {
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
  @host.app_services(bridge~, async_queue=Some(queue))
}

///|
fn markdown_editor_async_file_dialog_services(
  queue : @host.HostServiceAsyncQueue,
) -> @services.AppServices {
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
  @host.app_services(bridge~, async_queue=Some(queue))
}
