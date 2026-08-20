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
  assert_true(
    frame.platform_views[0].property_or("background-color", "").contains(
      "1",
    ),
  )
  inspect(frame.platform_views[0].property_or("color-scheme", ""), content="light")
  assert_true(
    frame.commands.any(command => {
      match command {
        @core.DrawCommand::FillRoundedRect(_, color) =>
          color == @core.Color::rgba(r=0.302, g=0.420, b=0.996, a=1.0)
        @core.DrawCommand::FillRoundedRectBrush(_, @core.Brush::Solid(color)) =>
          color == @core.Color::rgba(r=0.302, g=0.420, b=0.996, a=1.0)
        _ => false
      }
    }),
  )
  match frame.overlay_bounds {
    Some(bounds) => {
      // The marker must carry the button's absolute window position through
      // to native WebView hit testing, not its local 0,0 origin.
      assert_true(bounds.origin.x > 1200.0)
      assert_true(bounds.origin.y <= 1.0)
    }
    None => fail("expected floating button overlay bounds")
  }
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
test "dsh desktop switches between Harness and Chat roots" {
  let initial = Model::new(capability=WebViewCapability::available())
  let ready = update(
    update(initial, SettingsLoaded(@services.ServiceTaskResult::Success(None))),
    ChatSettingsLoaded(@services.ServiceTaskResult::Success(None)),
  )
  assert_true(ready.active_site == Site::Harness)
  let chat = update(ready, SwitchSite)
  assert_true(chat.active_site == Site::Chat)
  inspect(chat.url, content=default_chat_url)
  let harness = update(chat, SwitchSite)
  assert_true(harness.active_site == Site::Harness)
  inspect(harness.url, content=default_url)
}

///|
test "dsh desktop resolves system dark and light theme modes" {
  let model = Model::new(capability=WebViewCapability::available())
  assert_true(model.theme_mode == ThemeMode::System)
  assert_true(
    ThemeMode::System.resolve_scheme(@state.ColorScheme::Dark) ==
      @state.ColorScheme::Dark,
  )
  assert_true(
    ThemeMode::Dark.resolve_scheme(@state.ColorScheme::Light) ==
      @state.ColorScheme::Dark,
  )
  assert_true(
    ThemeMode::Light.resolve_scheme(@state.ColorScheme::Dark) ==
      @state.ColorScheme::Light,
  )
  assert_true(ThemeMode::Dark.resolve_theme(@state.ColorScheme::Light).scheme == @state.ColorScheme::Dark)
  assert_true(ThemeMode::Light.resolve_theme(@state.ColorScheme::Dark).scheme == @state.ColorScheme::Light)
  assert_true(
    @webview_host.web_view_color_wire_value(
      @core.Color::rgba(r=0.1, g=0.2, b=0.3, a=1.0),
    ).contains("0.1,0.2,0.3,1"),
  )
}

///|
test "dsh desktop loads and edits the persisted theme mode" {
  let initial = Model::new(capability=WebViewCapability::available())
  let loaded = update(
    initial,
    ThemeModeLoaded(@services.ServiceTaskResult::Success(Some("dark"))),
  )
  assert_true(loaded.theme_mode == ThemeMode::Dark)
  assert_true(loaded.theme_mode_input == ThemeMode::Dark)
  let opened = update(loaded, OpenSettings)
  let edited = update(opened, ThemeModeChanged("light"))
  assert_true(edited.theme_mode == ThemeMode::Dark)
  assert_true(edited.theme_mode_input == ThemeMode::Light)
  let saving = update(edited, SaveSettings)
  assert_true(saving.settings_saving)
  inspect(saving.settings_writes_pending, content="3")
}

///|
test "dsh desktop sends explicit dark appearance to a light-system WebView" {
  let settings = @services.SettingsServices::new(read=key => {
    @services.ServiceTask::succeed(
      key="settings:read",
      value=if key == theme_mode_settings_key { Some("dark") } else { None },
    )
  })
  let appearance = @services.AppearanceServices::new(system_color_scheme=() => {
    @services.ServiceTask::succeed(
      key="appearance:system-color-scheme",
      value=@state.ColorScheme::Light,
    )
  })
  let environment = @services.AppEnvironment::new(
    services=@services.AppServices::new(settings~, appearance~),
  )
  let runtime = test_runtime(
    program(capability=WebViewCapability::available(), environment~),
    width=1280.0,
    height=820.0,
  )
  let placement = runtime.draw_frame().platform_views[0]
  inspect(placement.property_or("color-scheme", ""), content="dark")
  assert_false(placement.property_or("background-color", "").has_prefix("1,"))
}


///|
test "dsh desktop secondary floating tap opens settings" {
  let model = update(
    Model::new(capability=WebViewCapability::available()),
    FloatingSecondaryTap,
  )
  assert_true(model.settings_presented)
}

///|
test "dsh desktop floating button receives primary pointer input" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  ignore(runtime.draw_frame())
  let button = test_semantics_node(
    runtime,
    role=@core.SemanticsRole::Button,
    label=Some("Switch Chat/DSH site"),
  )
  inspect(button.frame.size.width, content="52")
  inspect(button.frame.size.height, content="52")
  inspect(button.frame.origin.x, content="1228")
  let before_click = runtime.draw_frame()
  let before_bounds = match before_click.overlay_bounds {
    Some(bounds) => bounds
    None => abort("expected floating button overlay bounds")
  }
  test_click_node(runtime, button)
  let switched_frame = runtime.draw_frame()
  inspect(
    switched_frame.platform_views[0].property_or("url", ""),
    content=default_chat_url,
  )
  match switched_frame.overlay_bounds {
    Some(bounds) => assert_true(bounds.origin.x > 1200.0)
    None => fail("expected floating button overlay")
  }
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "dsh-desktop-surface",
      @core.PlatformViewEvent::Named(
        name="navigation-finished",
        value=default_chat_url,
        detail="",
        flag=false,
      ),
    ),
  )
  // A click must release the drag recognizer. A later hover move must not
  // move the button or leave the native WebView exclusion rectangle behind.
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=button.frame.origin.x + button.frame.size.width + 24.0,
          y=button.frame.origin.y + button.frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  let after_move = runtime.draw_frame()
  match after_move.overlay_bounds {
    Some(bounds) => assert_true(bounds == before_bounds)
    None => fail("expected floating button overlay bounds after hover")
  }
  let snapshot = runtime.read_semantics()
  ignore(snapshot)
}

///|
test "dsh desktop floating button keeps a free position away from edges" {
  let model = Model::new(capability=WebViewCapability::available())
  let moved = update(
    model,
    FloatingDragged({
      phase: @core.DragGesturePhase::Started,
      start: @core.Point::new(x=0.0, y=0.0),
      position: @core.Point::new(x=900.0, y=180.0),
      delta: @core.Point::new(x=-120.0, y=40.0),
      translation: @core.Point::new(x=-120.0, y=40.0),
    }),
  )
  let free = update(
    moved,
    FloatingDragged({
      phase: @core.DragGesturePhase::Changed,
      start: @core.Point::new(x=0.0, y=0.0),
      position: @core.Point::new(x=700.0, y=220.0),
      delta: @core.Point::new(x=-200.0, y=40.0),
      translation: @core.Point::new(x=-320.0, y=80.0),
    }),
  )
  let settled = update(
    free,
    FloatingDragged({
      phase: @core.DragGesturePhase::Ended,
      start: @core.Point::new(x=0.0, y=0.0),
      position: @core.Point::new(x=700.0, y=220.0),
      delta: @core.Point::new(x=0.0, y=0.0),
      translation: @core.Point::new(x=-320.0, y=80.0),
    }),
  )
  assert_false(settled.floating_left)
  assert_false(settled.floating_collapsed)
  inspect(settled.floating_x, content="-320")
  inspect(settled.floating_y, content="80")
}

///|
test "dsh desktop floating button docks and leaves a visible edge tab" {
  let model = Model::new(capability=WebViewCapability::available())
  let moved = update(
    model,
    FloatingDragged({
      phase: @core.DragGesturePhase::Started,
      start: @core.Point::new(x=1220.0, y=100.0),
      position: @core.Point::new(x=800.0, y=120.0),
      delta: @core.Point::new(x=-420.0, y=20.0),
      translation: @core.Point::new(x=-420.0, y=20.0),
    }),
  )
  let docked = update(
    moved,
    FloatingDragged({
      phase: @core.DragGesturePhase::Ended,
      start: @core.Point::new(x=1220.0, y=100.0),
      position: @core.Point::new(x=6.0, y=120.0),
      delta: @core.Point::new(x=0.0, y=0.0),
      translation: @core.Point::new(x=-1214.0, y=20.0),
    }),
  )
  assert_true(docked.floating_left)
  assert_true(docked.floating_collapsed)
  inspect(docked.floating_x, content="0")
  let expanded = update(docked, FloatingSecondaryTap)
  assert_false(expanded.floating_collapsed)
  assert_true(expanded.settings_presented)
}

///|
test "dsh desktop drag keeps the native overlay at the free position" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  ignore(runtime.draw_frame())
  let button = test_semantics_node(
    runtime,
    role=@core.SemanticsRole::Button,
    label=Some("Switch Chat/DSH site"),
  )
  let start = @core.Point::new(
    x=button.frame.origin.x + button.frame.size.width / 2.0,
    y=button.frame.origin.y + button.frame.size.height / 2.0,
  )
  let finish = @core.Point::new(x=start.x - 320.0, y=start.y + 180.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=start, phase=@core.PointerPhase::Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=finish, phase=@core.PointerPhase::Move),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=finish, phase=@core.PointerPhase::Up),
    ),
  )
  ignore(runtime.draw_frame())
  let after = test_semantics_node(
    runtime,
    role=@core.SemanticsRole::Button,
    label=Some("Switch Chat/DSH site"),
  )
  inspect(after.frame.origin.x, content="908")
  inspect(after.frame.origin.y, content="180")
  match runtime.draw_frame().overlay_bounds {
    Some(bounds) => {
      inspect(bounds.origin.x, content="907")
      inspect(bounds.origin.y, content="179")
    }
    None => fail("expected free floating overlay bounds")
  }
}

///|
test "dsh desktop can dock from either side using the viewport" {
  let model = Model::new(capability=WebViewCapability::available())
  let left_docked = update(
    model,
    FloatingDraggedInViewport(
      {
        phase: @core.DragGesturePhase::Ended,
        start: @core.Point::new(x=26.0, y=120.0),
        position: @core.Point::new(x=4.0, y=120.0),
        delta: @core.Point::new(x=0.0, y=0.0),
        translation: @core.Point::new(x=-22.0, y=0.0),
      },
      1280.0,
      820.0,
    ),
  )
  let left_moved = update(
    left_docked,
    FloatingDraggedInViewport(
      {
        phase: @core.DragGesturePhase::Started,
        start: @core.Point::new(x=8.0, y=120.0),
        position: @core.Point::new(x=464.0, y=120.0),
        delta: @core.Point::new(x=456.0, y=0.0),
        translation: @core.Point::new(x=456.0, y=0.0),
      },
      1280.0,
      820.0,
    ),
  )
  let left_free = update(
    left_moved,
    FloatingDraggedInViewport(
      {
        phase: @core.DragGesturePhase::Ended,
        start: @core.Point::new(x=8.0, y=120.0),
        position: @core.Point::new(x=464.0, y=120.0),
        delta: @core.Point::new(x=0.0, y=0.0),
        translation: @core.Point::new(x=456.0, y=0.0),
      },
      1280.0,
      820.0,
    ),
  )
  let right_docked = update(
    left_free,
    FloatingDraggedInViewport(
      {
        phase: @core.DragGesturePhase::Ended,
        start: @core.Point::new(x=446.0, y=120.0),
        position: @core.Point::new(x=1276.0, y=120.0),
        delta: @core.Point::new(x=0.0, y=0.0),
        translation: @core.Point::new(x=830.0, y=0.0),
      },
      1280.0,
      820.0,
    ),
  )
  assert_false(right_docked.floating_left)
  assert_true(right_docked.floating_collapsed)
  let right_free = update(
    right_docked,
    FloatingDraggedInViewport(
      {
        phase: @core.DragGesturePhase::Started,
        start: @core.Point::new(x=1276.0, y=120.0),
        position: @core.Point::new(x=1076.0, y=120.0),
        delta: @core.Point::new(x=-200.0, y=0.0),
        translation: @core.Point::new(x=-200.0, y=0.0),
      },
      1280.0,
      820.0,
    ),
  )
  assert_false(right_free.floating_collapsed)
  inspect(right_docked.floating_x, content="0")
  inspect(right_free.floating_x, content="-164")
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
test "dsh desktop menu bar exposes site switch and floating toggle" {
  let menus = application_menus()
  let view_menu = menus[2]
  inspect(view_menu.title, content="View")
  let commands = view_menu.items.filter_map(item => {
    match item {
      @services.ApplicationMenuItem::MenuCommand(command) => Some(command)
      @services.ApplicationMenuItem::MenuSeparator => None
    }
  })
  inspect(commands.length(), content="2")
  assert_true(
    commands.any(command => command.intent == @core.CommandIntent::SwitchSite),
  )
  assert_true(
    commands.any(command => command.intent == @core.CommandIntent::ToggleFloating),
  )
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  ignore(runtime.draw_frame())
  // Switch Site reuses the same command identity as the floating button.
  assert_true(runtime.dispatch_action_command(switch_site_action_command()))
  let switched = runtime.draw_frame()
  inspect(
    switched.platform_views[0].property_or("url", ""),
    content=default_chat_url,
  )
  runtime.dispatch_event(
    @core.AppEvent::PlatformView(
      "dsh-desktop-surface",
      @core.PlatformViewEvent::Named(
        name="navigation-finished",
        value=default_chat_url,
        detail="",
        flag=false,
      ),
    ),
  )
  // Toggle Floating removes the button overlay without touching the WebView.
  assert_true(runtime.dispatch_action_command(toggle_floating_action_command()))
  let hidden = runtime.draw_frame()
  assert_true(hidden.overlay_bounds is None)
  assert_true(hidden.platform_views.length() == 1)
  assert_true(runtime.dispatch_action_command(toggle_floating_action_command()))
  let shown = runtime.draw_frame()
  assert_true(shown.overlay_bounds is Some(_))
}

///|
test "dsh desktop toggle floating button shows and hides the overlay" {
  let runtime = test_runtime(
    program(capability=WebViewCapability::available()),
    width=1280.0,
    height=820.0,
  )
  let initial = runtime.draw_frame()
  assert_true(initial.overlay_bounds is Some(_))
  let hidden = update(
    Model::new(capability=WebViewCapability::available()),
    ToggleFloating,
  )
  assert_false(hidden.floating_enabled)
  let visible = update(hidden, ToggleFloating)
  assert_true(visible.floating_enabled)
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
  assert_true(runtime.draw_frame().overlay_bounds is Some(_))

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
  assert_true(saved_frame.overlay_bounds is Some(_))
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
