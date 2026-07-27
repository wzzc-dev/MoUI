///|
extern "C" fn macos_clipboard_has_text() -> Int = "moui_macos_clipboard_has_text"

///|
extern "C" fn macos_clipboard_read_text_bytes() -> Bytes = "moui_macos_clipboard_read_text"

///|
#borrow(text)
extern "C" fn macos_clipboard_write_text_bytes(text : Bytes) -> Int = "moui_macos_clipboard_write_text"

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
    kind: @host.NativeAccessibilityBridgeKind::AppKit,
    semantics_bridge_available: true,
    native_platform_bridge_available: false,
    action_dispatch_available: true,
    description: "macOS exposes an AppKit accessibility bridge contract over the shared semantics tree; real NSAccessibility object binding is still a backend follow-up.",
  }
}

///|
pub fn macos_accessibility_bridge(
  runtime : @runtime.AppRuntime,
) -> @host.NativeAccessibilityBridge {
  @host.NativeAccessibilityBridge::runtime(
    kind=@host.NativeAccessibilityBridgeKind::AppKit,
    runtime~,
  )
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
    native_accessibility_available=backend_info().accessibility.native_platform_bridge_available,
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
pub fn macos_service_bridge(
  system_theme? : @core.ColorScheme = macos_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_macos_clipboard,
  open_url? : (String) -> Bool = dispatch_macos_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_macos_file_dialog,
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = dispatch_macos_text_file,
  binary_file? : (@host.HostBinaryFileRequest) -> @host.HostServiceResponse = dispatch_macos_binary_file,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_macos_menu,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
      menus=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
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
          menu_command_response(commands, menu(commands))
        @host.HostServiceRequest::SetApplicationMenu(menus) =>
          dispatch_macos_application_menu(menus)
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(system_theme)
        @host.HostServiceRequest::ListDirectory(path) =>
          dispatch_macos_list_directory(path)
        @host.HostServiceRequest::PlatformChannel(_) =>
          @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}

///|
fn dispatch_macos_application_menu(
  menus : Array[@host.HostApplicationMenu],
) -> @host.HostServiceResponse {
  let descriptors : Array[@window_macos.SystemMenuDescriptor] = []
  for menu in menus {
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
  @window_macos.set_system_menus(descriptors)
  @host.HostServiceResponse::ApplicationMenuInstalled
}

///|
fn dispatch_macos_list_directory(path : String) -> @host.HostServiceResponse {
  let names_opt : Array[String]? = Some(@fs.read_dir(path)) catch { _ => None }
  let names = names_opt.unwrap_or([])
  let entries : Array[@host.HostDirectoryEntry] = []
  for name in names {
    // Skip hidden files (starting with .)
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
fn dispatch_macos_text_file(
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
fn dispatch_macos_binary_file(
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
fn dispatch_macos_menu(commands : Array[@core.ActionCommand]) -> Int {
  macos_show_menu_bytes(encode_menu_commands(commands))
}

///|
fn dispatch_macos_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  decode_file_dialog_selection(
    macos_file_dialog_bytes(
      host_file_dialog_kind_code(options.kind),
      encode_host_string(options.title),
      encode_host_filter_list(options.filters),
      encode_host_string(options.default_name.unwrap_or("")),
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
