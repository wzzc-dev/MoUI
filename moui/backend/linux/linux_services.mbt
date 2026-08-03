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
    native_accessibility_available=backend_info().accessibility.native_platform_bridge_available,
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
    kind: @runtime.NativeAccessibilityBridgeKind::ATSPI,
    semantics_bridge_available: true,
    native_platform_bridge_available: true,
    action_dispatch_available: true,
    description: "Linux exposes an AT-SPI accessibility binding over the shared semantics tree with snapshot publish, action dispatch, and cleanup diagnostics.",
  }
}

///|
pub fn linux_accessibility_bridge(
  runtime : @runtime.AppRuntime,
) -> @runtime.NativeAccessibilityBridge {
  let runtime_bridge = @runtime.NativeAccessibilityBridge::runtime(
    kind=@runtime.NativeAccessibilityBridgeKind::ATSPI,
    runtime~,
  )
  let binding = LinuxATSPIBinding::new(dispatch=request => {
    runtime_bridge.perform_action(request)
  })
  @runtime.NativeAccessibilityBridge::new(
    kind=@runtime.NativeAccessibilityBridgeKind::ATSPI,
    publish=read => {
      ignore(binding.publish_semantics(read))
      @runtime.accesskit_update_from_semantics_read(read)
    },
    perform=request => binding.perform_action(request),
  )
}

///|
fn dispatch_linux_menu(commands : Array[@core.ActionCommand]) -> Int {
  linux_show_menu_bytes(@platform_bridge.encode_menu_commands(commands))
}

///|
fn dispatch_linux_list_directory(path : String) -> @host.HostServiceResponse {
  let names_opt : Array[String]? = Some(@fs.read_dir(path)) catch { _ => None }
  let names = names_opt.unwrap_or([])
  let entries : Array[@host.HostDirectoryEntry] = []
  for name in names {
    if name.has_prefix(".") {
      continue
    }
    let child_path = path + "/" + name
    let is_dir_opt : Bool? = Some(@fs.is_dir(child_path)) catch { _ => None }
    let is_dir = is_dir_opt.unwrap_or(false)
    entries.push(
      @host.HostDirectoryEntry::new(name~, path=child_path, is_directory=is_dir),
    )
  }
  @host.HostServiceResponse::DirectoryListing(path, entries)
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
  list_directory? : (String) -> @host.HostServiceResponse = dispatch_linux_list_directory,
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
        @platform_bridge.menu_command_response_with_unavailable(
          commands,
          menu(commands),
        )
      @host.HostServiceRequest::SetApplicationMenu(_) =>
        @host.HostServiceResponse::Unavailable(
          "application menu bar service is unavailable",
        )
      @host.HostServiceRequest::ListDirectory(path) => list_directory(path)
      @host.HostServiceRequest::PlatformChannel(_) =>
        @host.HostServiceResponse::Unavailable(request.unavailable_message())
    }
  })
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
      let mime_encoded = @platform_bridge.encode_host_string(mime_type)
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
  let bytes = @platform_bridge.encode_host_string(url)
  linux_open_url_bytes(bytes, bytes.length()) != 0
}

///|
fn dispatch_linux_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  let title = @platform_bridge.encode_host_string(options.title)
  let filters = @platform_bridge.encode_host_filter_list(options.filters)
  let default_name = @platform_bridge.encode_host_string(
    options.default_name.unwrap_or(""),
  )
  let raw_bytes = linux_file_dialog_bytes(
    @platform_bridge.host_file_dialog_kind_code(options.kind),
    title,
    title.length(),
    filters,
    filters.length(),
    default_name,
    default_name.length(),
  )
  let selection = @platform_bridge.decode_file_dialog_selection(
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
