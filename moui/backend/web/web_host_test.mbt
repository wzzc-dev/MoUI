///|
test "web backend is window hosted" {
  let info = backend_info()
  inspect(info.uses_window_web_backend, content="true")
}

///|
test "canvas metrics promote dpr to host surface metrics" {
  let metrics = canvas_metrics(
    logical_width=200.0,
    logical_height=100.0,
    scale_factor=2.0,
  )
  assert_true(
    metrics.logical_size == @core.Size::new(width=200.0, height=100.0),
  )
  assert_true(
    metrics.physical_size == @core.Size::new(width=400.0, height=200.0),
  )
  inspect(metrics.scale_factor, content="2")
}

///|
test "web exposes host app info" {
  let info = web_host_info()
  assert_true(info.backend == @host.HostBackendKind::Web)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "canvas host creates surface and input contracts" {
  let surface = canvas_surface_host(
    logical_width=100.0,
    logical_height=50.0,
    scale_factor=1.5,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=100.0, height=50.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="true")
  let input = canvas_input_host()
  inspect(input.focused, content="false")
  inspect(input.capabilities().text_input, content="true")
  inspect(input.capabilities().scroll, content="true")
  inspect(input.capabilities().ime, content="true")
  inspect(input.capabilities().clipboard, content="true")
  inspect(input.capabilities().drag_drop, content="true")
  inspect(input.coordinate_policy().scale_factor_applied, content="true")
}

///|
test "web capability summary exposes known browser host services" {
  let summary = web_capability_summary()
  inspect(summary.backend.label(), content="Web")
  inspect(summary.label, content="Web multi-canvas host")
  inspect(summary.services.clipboard, content="true")
  inspect(summary.services.file_dialogs, content="true")
  inspect(summary.services.file_access, content="true")
  inspect(summary.services.open_url, content="true")
  inspect(summary.services.system_theme, content="true")
  inspect(summary.input.drag_drop, content="true")
  inspect(summary.input.ime, content="true")
  inspect(summary.ime_available, content="true")
  inspect(summary.drag_drop_available, content="true")
  inspect(summary.async_services, content="true")
  inspect(summary.native_accessibility_available, content="false")
  inspect(summary.has_required_app_basics(), content="true")
}

///|
test "web service bridge exposes open url and system theme contract" {
  let opened_url = Ref("")
  let bridge = web_service_bridge(system_theme=@core.ColorScheme::Dark, open_url=url => {
    opened_url.val = url
    true
  })
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL opened response")
  }
  inspect(opened_url.val, content="https://example.test")
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected clipboard to remain unavailable")
  }
}

///|
test "web service bridge reports unregistered platform channels unavailable" {
  let bridge = web_service_bridge()
  match
    bridge.dispatch(
      @host.HostServiceRequest::PlatformChannel(
        @host.PlatformChannelRequest::new(
          channel="web.missing",
          operation="probe",
        ),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: web.missing")
    _ => fail("expected unavailable Web platform channel")
  }
}

///|
test "web service bridge exposes clipboard write contract" {
  let clipboard = Ref("")
  let bridge = web_service_bridge(clipboard=true, clipboard_write=text => {
    clipboard.val = text
    true
  })
  inspect(bridge.capabilities().clipboard, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText("copied from web"),
      ),
    ) {
    @host.HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected clipboard write")
  }
  inspect(clipboard.val, content="copied from web")
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(
        message,
        content="clipboard read is unavailable on Web; paste is delivered by browser text input events",
      )
    _ => fail("expected Web clipboard read to remain unavailable")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::ReadText("note.md"),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="text file service is unavailable")
    _ => fail("expected Web text file access to remain unavailable")
  }
}

///|
test "web service bridge exposes browser-selected text-file reads when enabled" {
  let bridge = web_service_bridge(file_access=true)
  inspect(bridge.capabilities().file_access, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::ReadText("missing.md"),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(
        message,
        content="text file content is unavailable on Web until a browser file is selected",
      )
    _ => fail("expected missing Web text file cache to remain unavailable")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::WriteText("missing.md", "updated"),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="text file writing is asynchronous on Web")
    _ =>
      fail(
        "expected Web text-file writes without a queue to remain unavailable",
      )
  }
}

///|
test "web service bridge can defer async clipboard read, file dialogs, and writes" {
  let queue = @window_services.ServiceAsyncQueue::new()
  let bridge = web_service_bridge(
    clipboard_read=true,
    file_dialog=true,
    file_access=true,
    async_queue=Some(queue),
  )
  inspect(bridge.capabilities().clipboard, content="true")
  inspect(bridge.capabilities().file_dialogs, content="true")
  inspect(bridge.capabilities().file_access, content="true")
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="1")
    _ => fail("expected pending clipboard read")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::OpenFile,
          title="Open note",
        ),
      ),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="2")
    _ => fail("expected pending file dialog")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::ReadText("docs/architecture.md"),
      ),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="3")
    _ => fail("expected pending text-file read")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::WriteText("note.md", "updated"),
      ),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="4")
    _ => fail("expected pending text-file write")
  }
  inspect(queue.pending_count(), content="4")
  let pending = queue.drain_pending()
  match pending[0].request {
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText) =>
      ()
    _ => fail("expected clipboard read pending request")
  }
  match pending[1].request {
    @host.HostServiceRequest::FileDialog({ title, .. }) =>
      inspect(title, content="Open note")
    _ => fail("expected file dialog pending request")
  }
  match pending[2].request {
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path)
    ) => inspect(path, content="docs/architecture.md")
    _ => fail("expected text-file read pending request")
  }
  match pending[3].request {
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::WriteText(path, text)
    ) => {
      inspect(path, content="note.md")
      inspect(text, content="updated")
    }
    _ => fail("expected text-file write pending request")
  }
}

///|
test "web service bridge reports failed clipboard write" {
  let bridge = web_service_bridge(clipboard=true, clipboard_write=_text => false)
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText("blocked"),
      ),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard write failed")
    _ => fail("expected failed clipboard write")
  }
}

///|
test "web service bridge reports failed open url" {
  let bridge = web_service_bridge(open_url=_url => false)
  match bridge.dispatch(@host.HostServiceRequest::OpenUrl("not-a-url")) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL failed")
    _ => fail("expected failed open URL response")
  }
}

///|
test "canvas host constraints document pointer and resize assumptions" {
  let constraints = canvas_host_constraints()
  inspect(constraints.requires_focusable_canvas, content="true")
  inspect(constraints.disallow_css_transform, content="true")
  inspect(constraints.disallow_canvas_border_padding, content="true")
  inspect(constraints.coordinates_are_logical_pixels, content="true")
}

///|
test "animation frame maps to redraw requested host event" {
  match request_animation_frame_event() {
    @host.Event::RedrawRequested => ()
    _ => fail("expected redraw requested")
  }
}

///|
fn find_aria_node(nodes : Array[AriaNode], role : String) -> AriaNode? {
  for node in nodes {
    if node.role == role {
      return Some(node)
    }
  }
  None
}

///|
test "web accessibility maps semantics to aria nodes" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(
      @views.checkbox(
        "Done",
        checked=true,
        on_change=_value => (),
        font=@core.FontSpec::new(),
        foreground=@core.Color::black(),
        check_color=@core.Color::blue(),
        box_size=20.0,
        height=32.0,
      ) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  let aria = match runtime.read_semantics() {
    Ok(read) =>
      match aria_update_from_semantics_read(read) {
        Some(update) =>
          match find_aria_node(update.nodes, "checkbox") {
            Some(node) => node
            None => abort("expected checkbox ARIA node")
          }
        None => abort("expected full ARIA update")
      }
    Err(_) => abort("expected committed semantics")
  }
  inspect(aria.role, content="checkbox")
  inspect(aria.label, content="Done")
  assert_true(aria.checked == Some("true"))
  inspect(aria.disabled, content="false")
  assert_true(aria.actions.any(action => action == "activate"))
}

///|
test "web accessibility maps landmarks heading level and link url" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(
      @views.text("Docs", width=120.0, height=32.0)
      .semantics_role(@core.SemanticsRole::Heading)
      .semantics_level(2)
      .semantics_url("https://example.test/docs") : @core.View[Unit]),
    size=@core.Size::new(width=140.0, height=40.0),
  )
  let aria = match runtime.read_semantics() {
    Ok(read) =>
      match aria_update_from_semantics_read(read) {
        Some(update) =>
          match find_aria_node(update.nodes, "heading") {
            Some(node) => node
            None => abort("expected heading ARIA node")
          }
        None => abort("expected full ARIA update")
      }
    Err(_) => abort("expected committed semantics")
  }
  inspect(aria.role, content="heading")
  assert_true(aria.level == Some(2))
  inspect(aria.url, content="https://example.test/docs")
  assert_true(aria.node_id.value() > 0UL)
}
