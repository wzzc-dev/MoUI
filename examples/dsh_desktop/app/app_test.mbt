///|
test "dsh desktop emits native placement for the local Harness surface" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="dsh-desktop-surface")
  inspect(frame.platform_views[0].property_or("url", ""), content=default_url)
  assert_true(frame.overlay_bounds is None)
  assert_true(
    frame.clear_color == @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  )
}

///|
test "dsh desktop falls back without a native WebView" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::unavailable()),
    width=1280.0,
    height=820.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="0")
}

///|
test "dsh desktop tracks WebView lifecycle without duplicating Web state" {
  let initial = Model::new(capability=WebViewCapability::available())
  let loaded = update(
    initial,
    Msg::WebViewEvent(
      @webview_host.WebViewEvent::NavigationFinished(default_url),
    ),
  )
  inspect(loaded.status, content="ready")
  inspect(loaded.url, content=default_url)
}

///|
test "dsh desktop runs the native chrome hook after navigation" {
  let loaded_url = Ref("")
  let runtime = test_runtime(
    program(capability=WebViewCapability::available(), on_navigation_finished=url => {
      loaded_url.val = url
    }),
    width=1280.0,
    height=820.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "dsh-desktop-surface",
      @core.PlatformViewEvent::Named(
        name="navigation-finished",
        value=default_url,
        detail="",
        flag=false,
      ),
    ),
  )
  inspect(loaded_url.val, content=default_url)
}

///|
test "dsh desktop waits for settings before placing the WebView" {
  let pending_settings = @services.SettingsServices::new(read=_key => {
    @services.ServiceTask::new(key="pending:settings", start=_complete => None)
  })
  let environment = @services.AppEnvironment::new(
    services=@services.AppServices::new(settings=pending_settings),
  )
  let runtime = test_runtime(
    program(capability=WebViewCapability::available(), environment~),
    width=1280.0,
    height=820.0,
  )
  inspect(runtime.draw_frame().platform_views.length(), content="0")
}

///|
test "dsh desktop loads a valid persisted request URL" {
  let persisted = "https://dsh.example.test/"
  let settings = @services.SettingsServices::new(read=_key => {
    @services.ServiceTask::succeed(key="settings:read", value=Some(persisted))
  })
  let environment = @services.AppEnvironment::new(
    services=@services.AppServices::new(settings~),
  )
  let runtime = test_runtime(
    program(capability=WebViewCapability::available(), environment~),
    width=1280.0,
    height=820.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].property_or("url", ""), content=persisted)
}

///|
test "dsh desktop rejects invalid persisted and edited URLs" {
  let initial = Model::new(capability=WebViewCapability::available())
  let loaded = update(
    initial,
    SettingsLoaded(@services.ServiceTaskResult::Success(Some("file:///tmp"))),
  )
  inspect(loaded.url, content=default_url)
  let opened = update(loaded, OpenSettings)
  let edited = update(opened, RequestUrlChanged("ftp://example.test"))
  let rejected = update(edited, SaveSettings)
  assert_true(rejected.settings_presented)
  assert_false(rejected.settings_saving)
  assert_true(rejected.settings_error != "")
  assert_true(normalize_request_url(" https://example.test/path ") is Some(_))
  assert_true(normalize_request_url("http://") is None)
}

///|
test "dsh desktop applies successful settings and preserves failures" {
  let loaded = update(
    Model::new(capability=WebViewCapability::available()),
    SettingsLoaded(@services.ServiceTaskResult::Success(None)),
  )
  let opened = update(loaded, OpenSettings)
  let saving = update(
    update(opened, RequestUrlChanged("https://next.example.test")),
    SaveSettings,
  )
  assert_true(saving.settings_saving)
  let failed = update(
    saving,
    SettingsSaved(
      "https://next.example.test",
      @services.ServiceTaskResult::Failure(
        @services.ServiceError::new(code="write", message="write failed"),
      ),
    ),
  )
  assert_true(failed.settings_presented)
  inspect(failed.settings_error, content="write failed")
  let saved = update(
    saving,
    SettingsSaved(
      "https://next.example.test",
      @services.ServiceTaskResult::Success(()),
    ),
  )
  assert_false(saved.settings_presented)
  inspect(saved.url, content="https://next.example.test")
  inspect(saved.configured_url, content="https://next.example.test")
  let cancelled = update(saving, CancelSettings)
  let stale = update(
    cancelled,
    SettingsSaved(
      "https://next.example.test",
      @services.ServiceTaskResult::Success(()),
    ),
  )
  inspect(stale.url, content=default_url)
}

///|
test "settings command opens a full-window transparent native overlay" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  let command = settings_action_command()
  inspect(command.display_label(), content="Settings\u{2026}")
  assert_true(runtime.dispatch_action_command(command))
  let frame = runtime.draw_frame()
  assert_true(frame.overlay_bounds is Some(_))
  assert_true(
    frame.clear_color == @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  )
  assert_true(frame.platform_views.length() == 1)
}

///|
test "dsh desktop exposes standard Edit key equivalents" {
  let menus = application_menus()
  let menu = menus[1]
  inspect(menu.title, content="Edit")
  let commands = menu.items.filter_map(item => {
    match item {
      @services.ApplicationMenuItem::MenuCommand(command) => Some(command)
      @services.ApplicationMenuItem::MenuSeparator => None
    }
  })
  inspect(commands.length(), content="6")
  assert_true(
    commands.any(command => {
      if command.intent != @core.CommandIntent::SelectAll {
        false
      } else {
        match command.shortcut {
          Some(shortcut) => shortcut.key == "a" && shortcut.modifiers.meta
          None => false
        }
      }
    }),
  )
  assert_true(
    commands.any(command => {
      if command.intent != @core.CommandIntent::Paste {
        false
      } else {
        match command.shortcut {
          Some(shortcut) => shortcut.key == "v" && shortcut.modifiers.meta
          None => false
        }
      }
    }),
  )
}

///|
test "settings dialog accepts pointer editing cancel and save" {
  let settings = @services.SettingsServices::new(
    read=_key => @services.ServiceTask::succeed(key="settings:read", value=None),
    write=(_key, _value) => {
      @services.ServiceTask::succeed(key="settings:write", value=())
    },
  )
  let environment = @services.AppEnvironment::new(
    services=@services.AppServices::new(settings~),
  )
  let runtime = test_runtime(
    program(capability=WebViewCapability::available(), environment~),
    width=1280.0,
    height=820.0,
  )
  let command = settings_action_command()
  assert_true(runtime.dispatch_action_command(command))
  ignore(runtime.draw_frame())
  let field = test_semantics_node(runtime, role=@core.SemanticsRole::TextField)
  test_click_node(runtime, field)
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("x")),
  )
  ignore(runtime.draw_frame())
  let edited = test_semantics_node(runtime, role=@core.SemanticsRole::TextField)
  assert_true(edited.value.contains("x"))
  test_click_node(
    runtime,
    test_semantics_node(
      runtime,
      role=@core.SemanticsRole::Button,
      label=Some("Cancel"),
    ),
  )
  assert_true(runtime.draw_frame().overlay_bounds is None)

  assert_true(runtime.dispatch_action_command(command))
  ignore(runtime.draw_frame())
  let next_url = "https://next.example.test"
  let next_field = test_semantics_node(
    runtime,
    role=@core.SemanticsRole::TextField,
  )
  ignore(
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::ByNodeId(next_field.node_id),
      action: @core.SemanticsAction::SetText(next_url),
      precondition: @runtime.SemanticsGenerationPrecondition::Latest,
    }),
  )
  ignore(runtime.draw_frame())
  test_click_node(
    runtime,
    test_semantics_node(
      runtime,
      role=@core.SemanticsRole::Button,
      label=Some("Save"),
    ),
  )
  let saved_frame = runtime.draw_frame()
  assert_true(saved_frame.overlay_bounds is None)
  inspect(
    saved_frame.platform_views[0].property_or("url", ""),
    content=next_url,
  )
}

///|
fn test_semantics_node(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  label? : String? = None,
) -> @core.SemanticsNode {
  let nodes = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => snapshot.nodes()
    _ => abort("expected a full semantics snapshot")
  }
  for node in nodes {
    if node.role == role && (label is None || label == Some(node.label)) {
      return node
    }
  }
  abort("expected semantics node")
}

///|
fn test_click_node(
  runtime : @runtime.AppRuntime,
  node : @core.SemanticsNode,
) -> Unit {
  let position = @core.Point::new(
    x=node.frame.origin.x + node.frame.size.width / 2.0,
    y=node.frame.origin.y + node.frame.size.height / 2.0,
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
    ),
  )
  ignore(runtime.draw_frame())
}

///|
fn test_runtime(
  program : @moui.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}
