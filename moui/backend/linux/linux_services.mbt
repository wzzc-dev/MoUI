///|
#borrow(url)
extern "C" fn linux_open_url_bytes(url : Bytes, url_len : Int) -> Int = "moui_linux_open_url"

///|
#borrow(title, filters, default_name)
extern "C" fn linux_file_dialog_bytes(
  kind : Int,
  title : Bytes,
  title_len : Int,
  filters : Bytes,
  filters_len : Int,
  default_name : Bytes,
  default_name_len : Int,
) -> Bytes = "moui_linux_file_dialog"

///|
#borrow(commands)
extern "C" fn linux_show_menu_bytes(commands : Bytes) -> Int = "moui_linux_show_menu"

///|
/// Clipboard image support (ReadImage / WriteImage).
/// Implementation in linux_service_host.c uses wl-clipboard (wl-paste/wl-copy)
/// with GTK fallback for broader compatibility.
#borrow(mime, data)
extern "C" fn linux_clipboard_write_image_bytes(
  mime : Bytes,
  data : Bytes,
) -> Int = "moui_linux_clipboard_write_image"

///|
extern "C" fn linux_clipboard_read_image_bytes() -> Bytes = "moui_linux_clipboard_read_image"

///|
#borrow(key)
extern "C" fn linux_settings_has_value(key : Bytes) -> Int = "moui_linux_settings_has_value"

///|
#borrow(key)
extern "C" fn linux_settings_read_bytes(key : Bytes) -> Bytes = "moui_linux_settings_read"

///|
#borrow(key, value)
extern "C" fn linux_settings_write_bytes(key : Bytes, value : Bytes) -> Int = "moui_linux_settings_write"

///|
#borrow(key)
extern "C" fn linux_settings_remove_bytes(key : Bytes) -> Int = "moui_linux_settings_remove"

///|
extern "C" fn linux_accessibility_high_contrast() -> Int = "moui_linux_accessibility_high_contrast"

///|
extern "C" fn linux_accessibility_reduce_motion() -> Int = "moui_linux_accessibility_reduce_motion"

///|
extern "C" fn linux_accessibility_text_scale() -> Double = "moui_linux_accessibility_text_scale"

///|
pub fn capability_matrix() -> LinuxBackendCapabilities {
  {
    window: true,
    renderer: true,
    titlebar: true,
    pointer: true,
    keyboard: true,
    text_input: true,
    ime: true,
    clipboard: true,
    drag_drop: true,
    accessibility: true,
    scale_factor: true,
  }
}

///|
pub fn service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::new(
    clipboard=true,
    file_dialogs=true,
    file_access=true,
    menus=true,
    open_url=true,
    system_theme=true,
    settings=true,
  )
}

///|
pub fn linux_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn linux_capability_summary(
  services? : @host.HostServiceCapabilities = service_capabilities(),
  web_view_available? : Bool = false,
  web_view_description? : String = "Native WebView is unavailable on this host.",
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=linux_input_capabilities(),
    label="Linux host",
    window_lifecycle=true,
    multi_window=true,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=true,
    async_services=false,
    native_accessibility_available=backend_info().accessibility.native_accessibility_bridge_available,
    web_view_available~,
    web_view_description~,
    description="Wayland host summary with renderer/window readiness, Linux clipboard/file dialog/text-file/open URL/menu services, text-input/IME requests, file drag/drop, and AT-SPI accessibility binding.",
  )
}

///|
pub fn readiness() -> LinuxBackendReadiness {
  {
    ready: true,
    blocked_by: [],
    next_steps: [
      "keep matching-host Linux Showcase and Markdown Editor first-frame observation current",
      "capture full IME and platform service runtime evidence on matching Wayland host",
    ],
  }
}

///|
pub fn backend_info() -> LinuxBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Linux Wayland window host with renderer providers",
    ),
    window_backend_available: true,
    renderer_available: true,
    capabilities: capability_matrix(),
    accessibility: linux_accessibility_bridge_info(),
    services: service_capabilities(),
    readiness: readiness(),
    description: "Linux backend uses wzzc-dev/window/linux for Wayland events and delegates concrete rendering to platform renderer provider packages.",
  }
}

///|
pub fn linux_accessibility_bridge_info() -> LinuxAccessibilityBridgeInfo {
  {
    kind: "at-spi",
    semantics_bridge_available: true,
    native_accessibility_bridge_available: false,
    action_dispatch_available: true,
    description: "Linux has a GDBus AT-SPI transport candidate with committed snapshot/delta publish, exact-generation action dispatch, and window-scoped cleanup; native readiness remains false until accessibility-bus Registry integration and real AT-SPI client evidence pass.",
  }
}

///|
/// Read desktop accessibility preferences through the existing Environment
/// channel. The host helper is conservative when no desktop setting is known.
pub fn linux_environment_with_accessibility_settings(
  environment : @core.Environment,
) -> @core.Environment {
  let updated = environment
    .with_accessibility_contrast(
      if linux_accessibility_high_contrast() != 0 {
        @core.AccessibilityContrast::High
      } else {
        @core.AccessibilityContrast::Standard
      },
    )
    .with_reduced_motion(linux_accessibility_reduce_motion() != 0)
  let text_scale = linux_accessibility_text_scale()
  if text_scale > 0.0 {
    updated.with_text_scale(text_scale)
  } else {
    updated
  }
}

///|
pub fn linux_accessibility_bridge(
  driver : @runtime.HostRuntimeDriver,
) -> @accesskit_bridge.AccessKitBridge {
  let runtime_bridge = @accesskit_bridge.AccessKitBridge::driver(
    diagnostic_name="at-spi",
    driver~,
  )
  let binding = LinuxATSPIBinding::new(dispatch=request => {
    runtime_bridge.perform_action(request)
  })
  @accesskit_bridge.AccessKitBridge::new(
    diagnostic_name="at-spi",
    publish=read => {
      ignore(binding.publish_semantics(read))
      @accesskit_bridge.accesskit_update_from_semantics_read(read)
    },
    perform=request => binding.perform_action(request),
  )
}

///|
fn dispatch_linux_menu(commands : Array[@core.ActionCommand]) -> Int {
  linux_show_menu_bytes(@host_services_desktop.encode_menu_commands(commands))
}

///|
pub fn linux_service_bridge(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_linux_clipboard,
  open_url? : (String) -> Bool = dispatch_linux_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_linux_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = @host_services_native.dispatch_binary_file,
  settings? : (@host.HostSettingsRequest) -> @host.HostServiceResponse = dispatch_linux_settings,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_linux_menu,
  list_directory? : (String) -> @host.HostServiceResponse = @host_services_native.dispatch_list_directory,
) -> @host.HostServiceBridge {
  @host_services_desktop.DesktopHostServices::new(
    capabilities=service_capabilities(),
    system_theme~,
    clipboard~,
    open_url~,
    file_dialog~,
    text_file~,
    binary_file~,
    settings~,
    show_menu=commands => {
      @host_services_desktop.menu_command_response_with_unavailable(
        commands,
        menu(commands),
      )
    },
    list_directory~,
  ).bridge()
}

///|
fn dispatch_linux_settings(
  request : @host.HostSettingsRequest,
) -> @host.HostServiceResponse {
  match request {
    Read(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if linux_settings_has_value(key_bytes) == 0 {
        @host.HostServiceResponse::SettingValue(None)
      } else {
        @host.HostServiceResponse::SettingValue(
          Some(
            @utf8.decode_lossy(
              linux_settings_read_bytes(key_bytes)[:],
              ignore_bom=false,
            ),
          ),
        )
      }
    }
    Write(key, value) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      let value_bytes = @utf8.encode(value[:], bom=false)
      if linux_settings_write_bytes(key_bytes, value_bytes) != 0 {
        @host.HostServiceResponse::SettingWritten
      } else {
        @host.HostServiceResponse::Unavailable("settings write failed")
      }
    }
    Remove(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if linux_settings_remove_bytes(key_bytes) != 0 {
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
    bridge=linux_service_bridge(),
    timer=Some(linux_timer_source()),
  )
}

///|
fn dispatch_linux_clipboard(
  request : @host.HostClipboardRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostClipboardRequest::ReadText =>
      match @window_linux.read_clipboard_text() {
        Some(text) => @host.HostServiceResponse::ClipboardText(text)
        None =>
          @host.HostServiceResponse::Unavailable(
            "clipboard does not contain text or Wayland selection is unavailable",
          )
      }
    @host.HostClipboardRequest::WriteText(text) =>
      if @window_linux.write_clipboard_text(text) {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable(
          "clipboard write failed or Wayland selection is unavailable",
        )
      }
    @host.HostClipboardRequest::ReadImage =>
      match linux_clipboard_read_image_bytes() {
        bytes if bytes.length() > 0 =>
          // The C implementation is expected to return a payload that can be
          // interpreted as a simple image (e.g., raw PNG bytes).
          // For a more robust solution, a structured format (mime + data) could be used.
          @host.HostServiceResponse::ClipboardImage(bytes)
        _ =>
          @host.HostServiceResponse::Unavailable(
            "clipboard image read failed or no image data available",
          )
      }
    @host.HostClipboardRequest::WriteImage(mime_type, image_bytes) => {
      let mime_encoded = @host_services_desktop.encode_host_string(mime_type)
      if linux_clipboard_write_image_bytes(mime_encoded, image_bytes) != 0 {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable(
          "clipboard image write failed or Wayland selection is unavailable",
        )
      }
    }
  }
}

///|
fn dispatch_linux_open_url(url : String) -> Bool {
  let bytes = @host_services_desktop.encode_host_string(url)
  linux_open_url_bytes(bytes, bytes.length()) != 0
}

///|
fn dispatch_linux_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  let title = @host_services_desktop.encode_host_string(options.title)
  let filters = @host_services_desktop.encode_host_filter_list(options.filters)
  let default_name = @host_services_desktop.encode_host_string(
    options.default_name.unwrap_or(""),
  )
  let raw_bytes = linux_file_dialog_bytes(
    @host_services_desktop.host_file_dialog_kind_code(options.kind),
    title,
    title.length(),
    filters,
    filters.length(),
    default_name,
    default_name.length(),
  )
  let selection = @host_services_desktop.decode_file_dialog_selection(
    raw_bytes,
    trim_paths=true,
  )
  if selection.length() == 0 {
    // No paths returned — portal desktop and zenity both failed silently.
    // This usually means neither dialog tool is available in the current
    // environment. Install zenity: sudo apt-get install zenity
    println(
      "linux file dialog: " +
      options.title +
      " returned empty selection (portal+zenity unavailable)",
    )
  }
  selection
}

///|
