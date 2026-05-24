///|
pub(all) struct CanvasHostConstraints {
  requires_focusable_canvas : Bool
  disallow_css_transform : Bool
  disallow_canvas_border_padding : Bool
  coordinates_are_logical_pixels : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
#external
priv type WebHostString

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
        ime=false,
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
fn web_begin_create_string() -> Int = "window_web" "begin_create_string"

///|
fn web_string_append_char(handle : Int, code_point : Int) -> Unit = "window_web" "string_append_char"

///|
fn web_finish_create_string(handle : Int) -> WebHostString = "window_web" "finish_create_string"

///|
fn web_open_url(url : WebHostString) -> Bool = "window_web" "open_url"

///|
fn web_clipboard_write_text(text : WebHostString) -> Bool = "window_web" "clipboard_write_text"

///|
pub fn request_animation_frame_event() -> @host.HostEvent {
  @host.HostEvent::RedrawRequested
}
