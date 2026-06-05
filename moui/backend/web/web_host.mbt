///|
pub(all) struct CanvasHostConstraints {
  requires_focusable_canvas : Bool
  disallow_css_transform : Bool
  disallow_canvas_border_padding : Bool
  coordinates_are_logical_pixels : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
enum WebAsyncHostServiceKind {
  ClipboardReadText
  FileDialogOpenFile
  FileDialogSaveFile
  FileDialogPickDirectory
} derive(Eq, Debug, ToJson)

///|
struct WebAsyncHostServiceRequest {
  id : @host.HostServiceRequestId
  kind : WebAsyncHostServiceKind
  title : String
  filters : Array[String]
  default_name : String
} derive(Eq, Debug, ToJson)

///|
#external
priv type WebHostString

///|
let web_active_async_queue : Ref[@host.HostServiceAsyncQueue?] = Ref(None)

///|
pub fn canvas_host_constraints() -> CanvasHostConstraints {
  {
    requires_focusable_canvas: true,
    disallow_css_transform: true,
    disallow_canvas_border_padding: true,
    coordinates_are_logical_pixels: true,
    description: "The web host owns canvas focus, DPR mapping, and raw pointer coordinates; CSS transforms, borders, and padding are avoided to keep resize and input coordinates stable.",
  }
}

///|
pub fn canvas_metrics(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.HostSurfaceMetrics {
  @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=logical_width, height=logical_height),
    scale_factor~,
  )
}

///|
pub fn web_host_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Web,
    description="window/web canvas + wasm-gc browser WebGPU host",
  )
}

///|
pub fn canvas_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.SurfaceHostState {
  @host.SurfaceHostState::new(
    metrics=canvas_metrics(logical_width~, logical_height~, scale_factor~),
    owns_surface=false,
    can_reconfigure=true,
  )
}

///|
pub fn canvas_input_host() -> @host.InputHostState {
  @host.InputHostState::new(
    focused=false,
    contract=@host.HostInputContract::new(
      capabilities=@host.HostInputCapabilities::new(
        pointer=true,
        scroll=true,
        keyboard=true,
        focus=true,
        text_input=true,
        ime=true,
        clipboard=true,
        drag_drop=true,
      ),
      coordinates=@host.HostCoordinatePolicy::logical(
        description="Web canvas host reports logical event coordinates after DPR mapping.",
      ),
    ),
  )
}

///|
pub fn web_capability_summary(
  services? : @host.HostServiceCapabilities = @host.HostServiceCapabilities::new(
    clipboard=true,
    file_dialogs=true,
    open_url=true,
    system_theme=true,
  ),
  async_services? : Bool = true,
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=web_host_info(),
    services~,
    input=canvas_input_host().capabilities(),
    label="Web host",
    window_lifecycle=true,
    multi_window=true,
    text_input_ready=true,
    ime_ready=true,
    drag_drop_ready=true,
    async_services~,
    native_accessibility_ready=false,
    description="Browser canvas host with WebGPU imports, async clipboard/file dialogs, logical pointer coordinates, and app-level file drops.",
  )
}

///|
pub fn web_service_bridge(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
  open_url? : (String) -> Bool = _url => false,
  clipboard? : Bool = false,
  clipboard_read? : Bool = false,
  clipboard_write? : (String) -> Bool = _text => false,
  file_dialog? : Bool = false,
  async_queue? : @host.HostServiceAsyncQueue? = None,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=clipboard || clipboard_read,
      file_dialogs=file_dialog,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::OpenUrl(url) =>
          if open_url(url) {
            @host.HostServiceResponse::UrlOpened
          } else {
            @host.HostServiceResponse::Unavailable("open URL failed")
          }
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(system_theme)
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteText(text)
        ) =>
          if clipboard_write(text) {
            @host.HostServiceResponse::ClipboardWritten
          } else {
            @host.HostServiceResponse::Unavailable("clipboard write failed")
          }
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadText
        ) =>
          match async_queue {
            Some(queue) =>
              queue.submit(
                @host.HostServiceRequest::Clipboard(
                  @host.HostClipboardRequest::ReadText,
                ),
              )
            None =>
              @host.HostServiceResponse::Unavailable(
                "clipboard read is unavailable on Web; paste is delivered by browser text input events",
              )
          }
        @host.HostServiceRequest::FileDialog(options) =>
          match async_queue {
            Some(queue) =>
              queue.submit(@host.HostServiceRequest::FileDialog(options))
            None =>
              @host.HostServiceResponse::Unavailable(
                "file dialog service is asynchronous on Web",
              )
          }
        _ =>
          @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}

///|
fn WebAsyncHostServiceKind::browser_code(self : WebAsyncHostServiceKind) -> Int {
  match self {
    ClipboardReadText => -1
    FileDialogOpenFile => 0
    FileDialogSaveFile => 1
    FileDialogPickDirectory => 2
  }
}

///|
fn WebAsyncHostServiceRequest::from_pending(
  pending : @host.HostPendingServiceRequest,
) -> WebAsyncHostServiceRequest? {
  match pending.request {
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText) =>
      Some({
        id: pending.id,
        kind: WebAsyncHostServiceKind::ClipboardReadText,
        title: "",
        filters: [],
        default_name: "",
      })
    @host.HostServiceRequest::FileDialog(options) =>
      Some({
        id: pending.id,
        kind: match options.kind {
          @host.HostFileDialogKind::OpenFile =>
            WebAsyncHostServiceKind::FileDialogOpenFile
          @host.HostFileDialogKind::SaveFile =>
            WebAsyncHostServiceKind::FileDialogSaveFile
          @host.HostFileDialogKind::PickDirectory =>
            WebAsyncHostServiceKind::FileDialogPickDirectory
        },
        title: options.title,
        filters: options.filters,
        default_name: match options.default_name {
          Some(name) => name
          None => ""
        },
      })
    _ => None
  }
}

///|
fn drain_web_async_host_service_requests(
  queue : @host.HostServiceAsyncQueue,
) -> Array[WebAsyncHostServiceRequest] {
  let requests : Array[WebAsyncHostServiceRequest] = []
  for pending in queue.drain_pending() {
    match WebAsyncHostServiceRequest::from_pending(pending) {
      Some(request) => requests.push(request)
      None =>
        ignore(queue.reject(pending.id, pending.request.unavailable_message()))
    }
  }
  requests
}

///|
fn dispatch_web_async_host_service_request(
  request : WebAsyncHostServiceRequest,
) -> Unit {
  match request.kind {
    ClipboardReadText => web_async_clipboard_read_text(request.id.value)
    FileDialogOpenFile | FileDialogSaveFile | FileDialogPickDirectory =>
      web_async_file_dialog_open(
        request.id.value,
        request.kind.browser_code(),
        web_host_string(request.title),
        web_host_string(request.filters.join("\n")),
        web_host_string(request.default_name),
      )
  }
}

///|
fn set_web_async_host_service_queue(
  queue : @host.HostServiceAsyncQueue?,
) -> Unit {
  web_active_async_queue.val = queue
}

///|
fn web_complete_async_clipboard_read_text(
  request_id : Int,
  ok : Bool,
  text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        queue.complete(id, @host.HostServiceResponse::ClipboardText(text))
      } else {
        queue.reject(
          id,
          web_async_failure_reason(text, "clipboard read is unavailable on Web"),
        )
      }
    }
    None => false
  }
}

///|
fn web_complete_async_file_dialog_selection_text(
  request_id : Int,
  ok : Bool,
  selection_text : String,
) -> Bool {
  match web_active_async_queue.val {
    Some(queue) => {
      let id = @host.HostServiceRequestId::new(request_id)
      if ok {
        queue.complete(
          id,
          @host.HostServiceResponse::FileDialogSelection(
            decode_web_file_dialog_selection(selection_text),
          ),
        )
      } else {
        queue.reject(
          id,
          web_async_failure_reason(
            selection_text, "file dialog is unavailable on Web",
          ),
        )
      }
    }
    None => false
  }
}

///|
pub fn web_complete_async_clipboard_read(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_clipboard_read_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
pub fn web_complete_async_file_dialog(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  ignore(
    web_complete_async_file_dialog_selection_text(
      request_id,
      ok,
      web_host_string_from_id(text_id),
    ),
  )
}

///|
fn decode_web_file_dialog_selection(text : String) -> Array[String] {
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = path_view.to_owned()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}

///|
fn web_async_failure_reason(message : String, fallback : String) -> String {
  if message == "" {
    fallback
  } else {
    message
  }
}

///|
fn dispatch_web_open_url(url : String) -> Bool {
  web_open_url(web_host_string(url))
}

///|
fn dispatch_web_clipboard_write_text(text : String) -> Bool {
  web_clipboard_write_text(web_host_string(text))
}

///|
fn web_host_string(value : String) -> WebHostString {
  let handle = web_begin_create_string()
  for ch in value {
    web_string_append_char(handle, ch.to_int())
  }
  web_finish_create_string(handle)
}

///|
fn web_host_string_from_id(id : Int) -> String {
  web_host_string_to_string(web_begin_read_string(id))
}

///|
fn web_host_string_to_string(handle : WebHostString) -> String {
  let buf = StringBuilder::new()
  while true {
    let ch = web_string_read_char(handle)
    if ch == -1 {
      break
    }
    buf.write_char(ch.unsafe_to_char())
  }
  web_finish_read_string(handle)
  buf.to_string()
}

///|
fn web_begin_create_string() -> Int = "window_web" "begin_create_string"

///|
fn web_string_append_char(handle : Int, code_point : Int) -> Unit = "window_web" "string_append_char"

///|
fn web_finish_create_string(handle : Int) -> WebHostString = "window_web" "finish_create_string"

///|
fn web_begin_read_string(id : Int) -> WebHostString = "window_web" "begin_read_string"

///|
fn web_string_read_char(handle : WebHostString) -> Int = "window_web" "string_read_char"

///|
fn web_finish_read_string(handle : WebHostString) -> Unit = "window_web" "finish_read_string"

///|
fn web_open_url(url : WebHostString) -> Bool = "window_web" "open_url"

///|
fn web_clipboard_write_text(text : WebHostString) -> Bool = "window_web" "clipboard_write_text"

///|
fn web_async_clipboard_read_text(request_id : Int) -> Unit = "window_web" "clipboard_read_text_async"

///|
fn web_async_file_dialog_open(
  request_id : Int,
  kind : Int,
  title : WebHostString,
  filters : WebHostString,
  default_name : WebHostString,
) -> Unit = "window_web" "file_dialog_open_async"

///|
pub fn request_animation_frame_event() -> @host.HostEvent {
  @host.HostEvent::RedrawRequested
}
