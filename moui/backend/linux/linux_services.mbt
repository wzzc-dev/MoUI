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
    native_accessibility_available=backend_info().accessibility.native_platform_bridge_available,
    web_view=linux_webview_capabilities(),
    description="Wayland host summary with renderer/window readiness, Linux clipboard/file dialog/text-file/open URL/menu services, text-input/IME requests, file drag/drop, and AT-SPI accessibility binding.",
  )
}

///|
pub fn readiness() -> LinuxBackendReadiness {
  {
    ready: true,
    blocked_by: [
      "Linux native fontconfig/HarfBuzz/FreeType provider remains a scaffold and composes with Moon Cosmic fallback",
      "Linux Preview Ready runtime status still requires matching-host Wayland/Skia observation artifacts",
    ],
    next_steps: [
      "record matching-host Linux Showcase and Markdown Editor Skia first-frame observation",
      "replace the fontconfig native text stub with a real fontconfig + HarfBuzz + FreeType provider",
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
    kind: @host.NativeAccessibilityBridgeKind::ATSPI,
    semantics_bridge_available: true,
    native_platform_bridge_available: true,
    action_dispatch_available: true,
    description: "Linux exposes an AT-SPI accessibility binding over the shared semantics tree with snapshot publish, action dispatch, and cleanup diagnostics.",
  }
}

///|
pub fn linux_accessibility_bridge(
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> @host.NativeAccessibilityBridge {
  let binding = LinuxATSPIBinding::new(root~, dispatch~)
  ignore(binding.publish_semantics(root))
  @host.NativeAccessibilityBridge::new(
    kind=@host.NativeAccessibilityBridgeKind::ATSPI,
    snapshot=node => {
      ignore(binding.publish_semantics(node))
      @host.accesskit_tree_update_from_semantics(node)
    },
    perform=request => binding.perform_action(request),
  )
}

///|
pub fn linux_service_bridge(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_linux_clipboard,
  open_url? : (String) -> Bool = dispatch_linux_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_linux_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = dispatch_linux_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = dispatch_linux_binary_file,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_linux_menu,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(capabilities=service_capabilities(), handle=request => {
    match request {
      @host.HostServiceRequest::QuerySystemTheme =>
        @host.HostServiceResponse::SystemTheme(system_theme)
      @host.HostServiceRequest::Clipboard(clipboard_request) =>
        clipboard(clipboard_request)
      @host.HostServiceRequest::OpenUrl(url) =>
        if open_url(url) {
          @host.HostServiceResponse::UrlOpened
        } else {
          @host.HostServiceResponse::Unavailable("open URL failed")
        }
      @host.HostServiceRequest::FileDialog(options) =>
        @host.HostServiceResponse::FileDialogSelection(file_dialog(options))
      @host.HostServiceRequest::TextFile(text_file_request) =>
        text_file(text_file_request)
      @host.HostServiceRequest::BinaryFile(binary_file_request) =>
        binary_file(binary_file_request)
      @host.HostServiceRequest::ShowMenu(commands) =>
        linux_menu_command_response(commands, menu(commands))
    }
  })
}

///|
fn dispatch_linux_menu(commands : Array[@core.ActionCommand]) -> Int {
  linux_show_menu_bytes(encode_menu_commands(commands))
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
  }
}

///|
fn dispatch_linux_open_url(url : String) -> Bool {
  let bytes = encode_host_string(url)
  linux_open_url_bytes(bytes, bytes.length()) != 0
}

///|
fn dispatch_linux_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  let title = encode_host_string(options.title)
  let filters = encode_host_filter_list(options.filters)
  let default_name = encode_host_string(options.default_name.unwrap_or(""))
  decode_file_dialog_selection(
    linux_file_dialog_bytes(
      host_file_dialog_kind_code(options.kind),
      title,
      title.length(),
      filters,
      filters.length(),
      default_name,
      default_name.length(),
    ),
  )
}

///|
fn dispatch_linux_text_file(
  request : @host.HostTextFileRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostTextFileRequest::ReadText(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return @host.HostServiceResponse::Unavailable("file read failed")
        }
        @host.HostServiceResponse::TextFileContent(
          path,
          @utf8.decode_lossy(bytes[:], ignore_bom=true),
        )
      } else {
        @host.HostServiceResponse::Unavailable("file does not exist")
      }
    @host.HostTextFileRequest::WriteText(path, text) => {
      let bytes = @utf8.encode(text[:], bom=false)
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return @host.HostServiceResponse::Unavailable("file write failed")
      }
      @host.HostServiceResponse::TextFileWritten(path)
    }
  }
}

///|
fn dispatch_linux_binary_file(
  request : @host.HostBinaryFileRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostBinaryFileRequest::ReadBytes(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return @host.HostServiceResponse::Unavailable("file read failed")
        }
        @host.HostServiceResponse::BinaryFileContent(path, bytes)
      } else {
        @host.HostServiceResponse::Unavailable("file does not exist")
      }
    @host.HostBinaryFileRequest::WriteBytes(path, bytes) => {
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return @host.HostServiceResponse::Unavailable("file write failed")
      }
      @host.HostServiceResponse::BinaryFileWritten(path)
    }
  }
}

///|
fn host_file_dialog_kind_code(kind : @host.HostFileDialogKind) -> Int {
  match kind {
    @host.HostFileDialogKind::OpenFile => 0
    @host.HostFileDialogKind::SaveFile => 1
    @host.HostFileDialogKind::PickDirectory => 2
  }
}

///|
fn encode_host_string(value : String) -> Bytes {
  @utf8.encode(value[:], bom=false)
}

///|
fn encode_host_filter_list(filters : Array[String]) -> Bytes {
  encode_host_string(filters.join("\n"))
}

///|
fn decode_file_dialog_selection(bytes : Bytes) -> Array[String] {
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=false)
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = path_view.trim().to_owned()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}

///|
