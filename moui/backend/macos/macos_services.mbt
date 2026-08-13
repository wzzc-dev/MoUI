///|
extern "C" fn macos_clipboard_has_text() -> Int = "moui_macos_clipboard_has_text"

///|
extern "C" fn macos_clipboard_read_text_bytes() -> Bytes = "moui_macos_clipboard_read_text"

///|
#borrow(text)
extern "C" fn macos_clipboard_write_text_bytes(text : Bytes) -> Int = "moui_macos_clipboard_write_text"

///|
/// 写入剪贴板文本(macOS NSPasteboard)。返回是否写入成功。
/// 宿主级便捷 API:供平台入口/示例直接复制文本,无需经过服务适配层。
pub fn macos_clipboard_write_text(text : String) -> Bool {
  macos_clipboard_write_text_bytes(@utf8.encode(text, bom=false)) != 0
}

///|
/// 读取剪贴板文本;剪贴板无文本时返回 None。
pub fn macos_clipboard_read_text() -> String? {
  if macos_clipboard_has_text() != 0 {
    Some(
      @utf8.decode_lossy(macos_clipboard_read_text_bytes()[:], ignore_bom=false),
    )
  } else {
    None
  }
}

//|

///|
extern "C" fn macos_clipboard_has_image() -> Int = "moui_macos_clipboard_has_image"

//|

///|
extern "C" fn macos_clipboard_read_image_bytes() -> Bytes = "moui_macos_clipboard_read_image"

//|

///|
#borrow(data)
extern "C" fn macos_clipboard_write_image_bytes(data : Bytes) -> Int = "moui_macos_clipboard_write_image"

///|
#borrow(url)
extern "C" fn macos_open_url_bytes(url : Bytes) -> Int = "moui_macos_open_url"

///|
extern "C" fn macos_system_theme_is_dark() -> Int = "moui_macos_system_theme_is_dark"

///|
extern "C" fn macos_accessibility_increase_contrast() -> Int = "moui_macos_accessibility_increase_contrast"

///|
extern "C" fn macos_accessibility_reduce_motion() -> Int = "moui_macos_accessibility_reduce_motion"

///|
#borrow(key)
extern "C" fn macos_settings_has_value(key : Bytes) -> Int = "moui_macos_settings_has_value"

///|
#borrow(key)
extern "C" fn macos_settings_read_bytes(key : Bytes) -> Bytes = "moui_macos_settings_read"

///|
#borrow(key, value)
extern "C" fn macos_settings_write_bytes(key : Bytes, value : Bytes) -> Int = "moui_macos_settings_write"

///|
#borrow(key)
extern "C" fn macos_settings_remove_bytes(key : Bytes) -> Int = "moui_macos_settings_remove"

///|
#borrow(title, filters, default_name)
extern "C" fn macos_file_dialog_bytes(
  kind : Int,
  title : Bytes,
  filters : Bytes,
  default_name : Bytes,
) -> Bytes = "moui_macos_file_dialog"

///|
#borrow(commands)
extern "C" fn macos_show_menu_bytes(commands : Bytes) -> Int = "moui_macos_show_menu"

///|
#borrow(payload, call_closure)
#owned(callback)
extern "C" fn macos_install_application_menu_items(
  payload : Bytes,
  call_closure : FuncRef[((Int) -> Unit, Int) -> Unit],
  callback : (Int) -> Unit,
) -> Int = "moui_macos_install_application_menu_items"

///|
#borrow(payload, call_closure, callback)
extern "C" fn macos_bind_menu_bar_items(
  payload : Bytes,
  call_closure : FuncRef[((Int) -> Unit, Int) -> Unit],
  callback : (Int) -> Unit,
) -> Int = "moui_macos_bind_menu_bar_items"

///|
extern "C" fn macos_dispatch_first_responder_edit_action(action : Int) -> Int = "moui_macos_dispatch_first_responder_edit_action"

///|
extern "C" fn macos_install_application_menu_key_equivalent_monitor() -> Int = "moui_macos_install_application_menu_key_equivalent_monitor"

///|

///|
pub fn backend_info() -> MacosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="macOS AppKit window host with renderer providers",
    ),
    renderer_available: true,
    accessibility: macos_accessibility_bridge_info(),
    description: "macOS backend uses wzzc-dev/window/macos for AppKit events and delegates concrete rendering to platform renderer provider packages.",
  }
}

///|
pub fn macos_accessibility_bridge_info() -> MacosAccessibilityBridgeInfo {
  {
    kind: "appkit",
    semantics_bridge_available: true,
    native_accessibility_bridge_available: false,
    action_dispatch_available: true,
    description: "macOS attaches NSAccessibility objects to the AppKit content view and routes actions through exact generations; availability stays false until the external AX L2 probe passes.",
  }
}

///|
pub fn macos_accessibility_bridge(
  driver : @runtime.HostRuntimeDriver,
) -> @accesskit_bridge.AccessKitBridge {
  @accesskit_bridge.AccessKitBridge::driver(diagnostic_name="appkit", driver~)
}

///|
pub fn macos_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=true,
    clipboard=true,
    drag_drop=true,
  )
}

///|
pub fn macos_capability_summary(
  services? : @host.HostServiceCapabilities = macos_service_bridge().capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=macos_input_capabilities(),
    label="macOS host",
    window_lifecycle=true,
    multi_window=true,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=true,
    async_services=false,
    native_accessibility_available=backend_info().accessibility.native_accessibility_bridge_available,
    web_view_available=true,
    web_view_description="macOS WKWebView native embedding is available.",
    description="AppKit host with clipboard, file dialog, URL, system theme, native context menu, text input, and file-drop contracts.",
  )
}

///|
pub fn macos_system_theme() -> @core.ColorScheme {
  if macos_system_theme_is_dark() != 0 {
    @core.ColorScheme::Dark
  } else {
    @core.ColorScheme::Light
  }
}

///|
fn macos_environment_with_accessibility_settings(
  environment : @core.Environment,
) -> @core.Environment {
  let contrast = if macos_accessibility_increase_contrast() != 0 {
    @core.AccessibilityContrast::High
  } else {
    @core.AccessibilityContrast::Standard
  }
  environment
  .with_accessibility_contrast(contrast)
  .with_reduced_motion(macos_accessibility_reduce_motion() != 0)
}

///|
pub fn macos_service_bridge(
  system_theme? : @core.ColorScheme = macos_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_macos_clipboard,
  open_url? : (String) -> Bool = dispatch_macos_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_macos_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_binary_file,
  settings? : (@host.HostSettingsRequest) -> @host.HostServiceResponse = dispatch_macos_settings,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_macos_menu,
) -> @host.HostServiceBridge {
  @host_services_desktop.DesktopHostServices::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
      menus=true,
      open_url=true,
      system_theme=true,
      settings=true,
    ),
    system_theme~,
    clipboard~,
    open_url~,
    file_dialog~,
    text_file~,
    binary_file~,
    settings~,
    show_menu=commands => {
      @host_services_desktop.menu_command_response(commands, menu(commands))
    },
    set_application_menu=dispatch_macos_application_menu,
  ).bridge()
}

///|
fn dispatch_macos_settings(
  request : @host.HostSettingsRequest,
) -> @host.HostServiceResponse {
  match request {
    Read(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if macos_settings_has_value(key_bytes) == 0 {
        @host.HostServiceResponse::SettingValue(None)
      } else {
        @host.HostServiceResponse::SettingValue(
          Some(
            @utf8.decode_lossy(
              macos_settings_read_bytes(key_bytes)[:],
              ignore_bom=false,
            ),
          ),
        )
      }
    }
    Write(key, value) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      let value_bytes = @utf8.encode(value[:], bom=false)
      if macos_settings_write_bytes(key_bytes, value_bytes) != 0 {
        @host.HostServiceResponse::SettingWritten
      } else {
        @host.HostServiceResponse::Unavailable("settings write failed")
      }
    }
    Remove(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if macos_settings_remove_bytes(key_bytes) != 0 {
        @host.HostServiceResponse::SettingRemoved
      } else {
        @host.HostServiceResponse::Unavailable("settings remove failed")
      }
    }
  }
}

///|
pub fn app_environment() -> @services.AppEnvironment {
  @window_services.app_environment(
    bridge=macos_service_bridge(),
    timer=Some(macos_timer_source()),
  )
}

///|
/// Build the callback installed through `MacosHostAppOptions::on_ready`.
/// AppKit replaces menus installed before launch completion, so the backend
/// owns both that timing rule and the native shortcut conversion.
pub fn application_menu_on_ready(
  menus : Array[@services.ApplicationMenu],
  runtime : @runtime.AppRuntime,
) -> () -> Unit {
  () => {
    let commands = macos_application_menu_commands(menus)
    let dispatch = fn(action_id : Int) {
      match commands.get(action_id - 1) {
        Some(command) => dispatch_macos_application_command(runtime, command)
        None => ()
      }
    }
    @window_macos.set_system_menu_action_handler(dispatch)
    @window_macos.set_system_menus(macos_application_menu_descriptors(menus))
    ignore(
      bind_macos_menu_bar_items(
        macos_application_menu_bar_items(menus),
        dispatch,
      ),
    )
    ignore(
      install_macos_application_menu_items(
        macos_application_menu_items(menus),
        dispatch,
      ),
    )
    ignore(macos_install_application_menu_key_equivalent_monitor())
  }
}

///|
fn dispatch_macos_application_command(
  runtime : @runtime.AppRuntime,
  command : @core.ActionCommand,
) -> Unit {
  let focused_text = runtime.focused_text_input().focused
  if !focused_text && dispatch_macos_native_edit_command(command.intent) {
    return ()
  }
  if focused_text {
    match command.intent {
      @core.CommandIntent::Copy | @core.CommandIntent::Cut => {
        let result = runtime.dispatch_focused_text_command(command.intent)
        match result.clipboard_text {
          Some(text) => ignore(macos_clipboard_write_text(text))
          None => ()
        }
        return ()
      }
      @core.CommandIntent::Paste => {
        match macos_clipboard_read_text() {
          Some(text) =>
            ignore(
              runtime.dispatch_focused_text_command(
                @core.CommandIntent::Paste,
                paste_text=Some(text),
              ),
            )
          None => ()
        }
        return ()
      }
      @core.CommandIntent::Undo
      | @core.CommandIntent::Redo
      | @core.CommandIntent::SelectAll => {
        ignore(runtime.dispatch_command(command.intent))
        return ()
      }
      _ => ()
    }
  }
  ignore(runtime.dispatch_action_command(command))
}

///|
fn dispatch_macos_native_edit_command(intent : @core.CommandIntent) -> Bool {
  let action = match intent {
    @core.CommandIntent::Copy => Some(0)
    @core.CommandIntent::Cut => Some(1)
    @core.CommandIntent::Paste => Some(2)
    @core.CommandIntent::Undo => Some(3)
    @core.CommandIntent::Redo => Some(4)
    @core.CommandIntent::SelectAll => Some(5)
    _ => None
  }
  match action {
    Some(code) => macos_dispatch_first_responder_edit_action(code) != 0
    None => false
  }
}

///|
fn macos_application_menu_commands(
  menus : Array[@services.ApplicationMenu],
) -> Array[@core.ActionCommand] {
  let commands : Array[@core.ActionCommand] = []
  for menu in menus {
    for item in menu.items {
      match item {
        @services.ApplicationMenuItem::MenuCommand(command) =>
          commands.push(command)
        @services.ApplicationMenuItem::MenuSeparator => ()
      }
    }
  }
  commands
}

///|
fn macos_application_menu_descriptors(
  menus : Array[@services.ApplicationMenu],
) -> Array[@window_macos.SystemMenuDescriptor] {
  let descriptors : Array[@window_macos.SystemMenuDescriptor] = []
  let next_action_id = Ref(1)
  for menu in menus {
    let in_menu_bar = menu.placement
      is @services.ApplicationMenuPlacement::MenuBar
    let items : Array[@window_macos.SystemMenuItemDescriptor] = []
    for item in menu.items {
      match item {
        @services.ApplicationMenuItem::MenuSeparator =>
          if in_menu_bar {
            items.push(
              @window_macos.SystemMenuItemDescriptor::new(
                title="",
                action_id=0,
                key_equivalent="",
                key_modifier_mask=-1,
                separator=true,
              ),
            )
          }
        @services.ApplicationMenuItem::MenuCommand(command) => {
          let action_id = next_action_id.val
          next_action_id.val = action_id + 1
          if in_menu_bar {
            let (key, modifiers) = macos_application_menu_shortcut(command)
            items.push(
              @window_macos.SystemMenuItemDescriptor::new(
                title=command.display_label(),
                action_id~,
                key_equivalent=key,
                key_modifier_mask=modifiers,
                separator=false,
              ),
            )
          }
        }
      }
    }
    if in_menu_bar {
      descriptors.push(
        @window_macos.SystemMenuDescriptor::new(title=menu.title, items~),
      )
    }
  }
  descriptors
}

///|
fn macos_application_menu_items(
  menus : Array[@services.ApplicationMenu],
) -> Array[@host.HostApplicationMenuItem] {
  let result : Array[@host.HostApplicationMenuItem] = []
  let next_action_id = Ref(1)
  for menu in menus {
    let in_application_menu = menu.placement
      is @services.ApplicationMenuPlacement::ApplicationMenu
    for item in menu.items {
      match item {
        @services.ApplicationMenuItem::MenuSeparator =>
          if in_application_menu {
            result.push(@host.HostApplicationMenuItem::separator())
          }
        @services.ApplicationMenuItem::MenuCommand(command) => {
          let action_id = next_action_id.val
          next_action_id.val = action_id + 1
          if in_application_menu {
            let (key, modifiers) = macos_application_menu_shortcut(command)
            result.push(
              @host.HostApplicationMenuItem::new(
                title=command.display_label(),
                action_id~,
                key_equivalent=key,
                key_modifier_mask=modifiers,
                enabled=command.enabled,
              ),
            )
          }
        }
      }
    }
  }
  result
}

///|
fn macos_application_menu_bar_items(
  menus : Array[@services.ApplicationMenu],
) -> Array[@host.HostApplicationMenu] {
  let result : Array[@host.HostApplicationMenu] = []
  let next_action_id = Ref(1)
  for menu in menus {
    let items : Array[@host.HostApplicationMenuItem] = []
    for item in menu.items {
      match item {
        @services.ApplicationMenuItem::MenuSeparator =>
          if menu.placement is @services.ApplicationMenuPlacement::MenuBar {
            items.push(@host.HostApplicationMenuItem::separator())
          }
        @services.ApplicationMenuItem::MenuCommand(command) => {
          let action_id = next_action_id.val
          next_action_id.val = action_id + 1
          if menu.placement is @services.ApplicationMenuPlacement::MenuBar {
            let (key, modifiers) = macos_application_menu_shortcut(command)
            items.push(
              @host.HostApplicationMenuItem::new(
                title=command.display_label(),
                action_id~,
                key_equivalent=key,
                key_modifier_mask=modifiers,
                enabled=command.enabled,
              ),
            )
          }
        }
      }
    }
    if menu.placement is @services.ApplicationMenuPlacement::MenuBar {
      result.push(
        @host.HostApplicationMenu::new(
          title=menu.title,
          items~,
          placement=@host.HostApplicationMenuPlacement::MenuBar,
        ),
      )
    }
  }
  result
}

///|
fn bind_macos_menu_bar_items(
  menus : Array[@host.HostApplicationMenu],
  dispatch : (Int) -> Unit,
) -> Bool {
  let text = (menus.to_json() : Json).stringify()
  macos_bind_menu_bar_items(
    @utf8.encode(text[:], bom=false),
    fn(callback, action_id) { callback(action_id) },
    dispatch,
  ) !=
  0
}

///|
fn install_macos_application_menu_items(
  items : Array[@host.HostApplicationMenuItem],
  dispatch : (Int) -> Unit,
) -> Bool {
  let text = (items.to_json() : Json).stringify()
  macos_install_application_menu_items(
    @utf8.encode(text[:], bom=false),
    fn(callback, action_id) { callback(action_id) },
    dispatch,
  ) !=
  0
}

///|
fn macos_application_menu_shortcut(
  command : @core.ActionCommand,
) -> (String, Int) {
  match command.shortcut {
    Some(shortcut) => {
      let mut mask = 0
      if shortcut.modifiers.shift {
        mask = mask + 131_072
      }
      if shortcut.modifiers.control {
        mask = mask + 262_144
      }
      if shortcut.modifiers.alt {
        mask = mask + 524_288
      }
      if shortcut.modifiers.meta {
        mask = mask + 1_048_576
      }
      (shortcut.key, mask)
    }
    None => ("", -1)
  }
}

///|
fn dispatch_macos_application_menu(
  menus : Array[@host.HostApplicationMenu],
) -> @host.HostServiceResponse {
  let descriptors : Array[@window_macos.SystemMenuDescriptor] = []
  let application_items : Array[@host.HostApplicationMenuItem] = []
  for menu in menus {
    match menu.placement {
      @host.HostApplicationMenuPlacement::MenuBar => {
        let items : Array[@window_macos.SystemMenuItemDescriptor] = []
        for item in menu.items {
          items.push(
            @window_macos.SystemMenuItemDescriptor::new(
              title=item.title,
              action_id=item.action_id,
              key_equivalent=item.key_equivalent,
              key_modifier_mask=item.key_modifier_mask,
              separator=item.separator,
            ),
          )
        }
        descriptors.push(
          @window_macos.SystemMenuDescriptor::new(title=menu.title, items~),
        )
      }
      @host.HostApplicationMenuPlacement::ApplicationMenu =>
        application_items.append(menu.items)
    }
  }
  @window_macos.set_system_menus(descriptors)
  ignore(install_macos_application_menu_items(application_items, _ => ()))
  @host.HostServiceResponse::ApplicationMenuInstalled
}

///|
fn dispatch_macos_menu(commands : Array[@core.ActionCommand]) -> Int {
  macos_show_menu_bytes(@host_services_desktop.encode_menu_commands(commands))
}

///|
fn dispatch_macos_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  @host_services_desktop.decode_file_dialog_selection(
    macos_file_dialog_bytes(
      @host_services_desktop.host_file_dialog_kind_code(options.kind),
      @host_services_desktop.encode_host_string(options.title),
      @host_services_desktop.encode_host_filter_list(options.filters),
      @host_services_desktop.encode_host_string(
        options.default_name.unwrap_or(""),
      ),
    ),
  )
}

///|
fn dispatch_macos_open_url(url : String) -> Bool {
  let bytes = @utf8.encode(url[:], bom=false)
  macos_open_url_bytes(bytes) != 0
}

///|
fn dispatch_macos_clipboard(
  request : @host.HostClipboardRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostClipboardRequest::ReadText =>
      if macos_clipboard_has_text() != 0 {
        @host.HostServiceResponse::ClipboardText(
          @utf8.decode_lossy(
            macos_clipboard_read_text_bytes()[:],
            ignore_bom=false,
          ),
        )
      } else {
        @host.HostServiceResponse::Unavailable(
          "clipboard does not contain text",
        )
      }
    @host.HostClipboardRequest::WriteText(text) => {
      let bytes = @utf8.encode(text[:], bom=false)
      if macos_clipboard_write_text_bytes(bytes) != 0 {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable("clipboard write failed")
      }
    }
    @host.HostClipboardRequest::ReadImage =>
      if macos_clipboard_has_image() != 0 {
        @host.HostServiceResponse::ClipboardImage(
          macos_clipboard_read_image_bytes(),
        )
      } else {
        @host.HostServiceResponse::Unavailable(
          "clipboard does not contain image",
        )
      }
    @host.HostClipboardRequest::WriteImage(_mime, bytes) =>
      if macos_clipboard_write_image_bytes(bytes) != 0 {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable("clipboard image write failed")
      }
  }
}
