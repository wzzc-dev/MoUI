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
) -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=logical_width, height=logical_height),
    scale_factor~,
  )
}

///|
pub fn web_host_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Web,
    description="window/web canvas surface + wasm-gc browser host",
  )
}

///|
pub fn canvas_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @window_input.SurfaceState {
  @window_input.SurfaceState::new(
    metrics=canvas_metrics(logical_width~, logical_height~, scale_factor~),
    owns_surface=false,
    can_reconfigure=true,
  )
}

///|
pub fn canvas_input_host() -> @window_input.InputState {
  @window_input.InputState::new(
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
    file_access=true,
    open_url=true,
    system_theme=true,
    settings=true,
  ),
  async_services? : Bool = true,
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=web_host_info(),
    services~,
    input=canvas_input_host().capabilities(),
    label="Web multi-canvas host",
    window_lifecycle=true,
    multi_window=true,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=true,
    async_services~,
    native_accessibility_available=false,
    description="Browser multi-canvas host with async clipboard/file dialogs, logical pointer coordinates, and app-level file drops; it does not manage browser popup windows or tabs.",
  )
}

///|
fn async_dispatch(
  async_queue : @window_services.ServiceAsyncQueue?,
  request : @host.HostServiceRequest,
  unavailable_msg : String,
) -> @host.HostServiceResponse {
  match async_queue {
    Some(queue) => queue.submit(request)
    None => @host.HostServiceResponse::Unavailable(unavailable_msg)
  }
}

///|
pub fn web_service_bridge(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
  open_url? : (String) -> Bool = _url => false,
  clipboard? : Bool = false,
  clipboard_read? : Bool = false,
  clipboard_write? : (String) -> Bool = _text => false,
  file_dialog? : Bool = false,
  file_access? : Bool = false,
  settings_available? : Bool = false,
  settings? : (@host.HostSettingsRequest) -> @host.HostServiceResponse = request => {
    @host.HostServiceResponse::Unavailable(
      @host.HostServiceRequest::Settings(request).unavailable_message(),
    )
  },
  async_queue? : @window_services.ServiceAsyncQueue? = None,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=clipboard || clipboard_read,
      file_dialogs=file_dialog,
      file_access~,
      open_url=true,
      system_theme=true,
      settings=settings_available,
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
        @host.HostServiceRequest::Settings(settings_request) =>
          settings(settings_request)
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
          async_dispatch(
            async_queue, request, "clipboard read is unavailable on Web; paste is delivered by browser text input events",
          )
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::ReadImage
        ) =>
          async_dispatch(
            async_queue, request, "clipboard image read is unavailable on Web",
          )
        @host.HostServiceRequest::Clipboard(
          @host.HostClipboardRequest::WriteImage(_, _)
        ) =>
          async_dispatch(
            async_queue, request, "clipboard image write is unavailable on Web",
          )
        @host.HostServiceRequest::FileDialog(_) =>
          async_dispatch(
            async_queue, request, "file dialog service is asynchronous on Web",
          )
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) =>
          match web_cached_text_file(path) {
            Some(text) => @host.HostServiceResponse::TextFileContent(path, text)
            None =>
              match async_queue {
                Some(queue) => {
                  let response = queue.submit(
                    @host.HostServiceRequest::TextFile(
                      @host.HostTextFileRequest::ReadText(path),
                    ),
                  )
                  match response {
                    @host.HostServiceResponse::Pending(id) =>
                      web_remember_text_file_read(id.value, path)
                    _ => ()
                  }
                  response
                }
                None =>
                  @host.HostServiceResponse::Unavailable(
                    "text file content is unavailable on Web until a browser file is selected",
                  )
              }
          }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::WriteText(_, _)
        ) =>
          match request {
            @host.HostServiceRequest::TextFile(
              @host.HostTextFileRequest::WriteText(path, text)
            ) =>
              match async_queue {
                Some(queue) => {
                  let response = queue.submit(request)
                  match response {
                    @host.HostServiceResponse::Pending(id) =>
                      web_remember_text_file_write(id.value, path, text)
                    _ => ()
                  }
                  response
                }
                None =>
                  @host.HostServiceResponse::Unavailable(
                    "text file writing is asynchronous on Web",
                  )
              }
            _ =>
              @host.HostServiceResponse::Unavailable(
                "text file writing is unavailable on Web",
              )
          }
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(_)
        ) =>
          @host.HostServiceResponse::Unavailable(
            "binary file content is unavailable on Web until binary browser file reads are wired",
          )
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(_, _)
        ) =>
          @host.HostServiceResponse::Unavailable(
            "binary file writing is unavailable on Web until binary browser downloads are wired",
          )
        @host.HostServiceRequest::PlatformChannel(_) =>
          @host.HostServiceResponse::Unavailable(request.unavailable_message())
        _ =>
          @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}

///|
pub fn web_app_services(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @services.AppServices {
  let async_queue = web_async_host_service_queue()
  @window_services.app_services(
    bridge=web_service_bridge(
      system_theme~,
      open_url=dispatch_web_open_url,
      clipboard=true,
      clipboard_read=true,
      clipboard_write=dispatch_web_clipboard_write_text,
      file_dialog=true,
      file_access=true,
      settings_available=true,
      settings=dispatch_web_settings,
      async_queue=Some(async_queue),
    ),
    async_queue=Some(async_queue),
  )
}

///|
/// Construct the app-facing Web environment. The returned route source must be
/// passed to `WebAppOptions` so browser history events reach the same Program.
pub fn app_environment(
  routes? : @services.RouteSource = @services.RouteSource::new(),
) -> @services.AppEnvironment {
  @services.AppEnvironment::new(
    services=web_app_services(),
    timer=Some(web_timer_source()),
    routes=Some(routes),
  )
}

///|
/// Read the browser's current local civil time. This is intentionally separate
/// from `web_timer_source()`: the timer provides monotonic scheduling while the
/// wall clock provides a user-visible local date and time snapshot.
pub fn web_wall_clock() -> @runtime.HostWallClock {
  @runtime.HostWallClock::new(
    web_wall_clock_year(),
    web_wall_clock_month(),
    web_wall_clock_day(),
    web_wall_clock_weekday(),
    web_wall_clock_hour(),
    web_wall_clock_minute(),
    second=web_wall_clock_second(),
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
fn dispatch_web_settings(
  request : @host.HostSettingsRequest,
) -> @host.HostServiceResponse {
  match request {
    Read(key) =>
      if web_settings_has_value(web_host_string(key)) {
        @host.HostServiceResponse::SettingValue(
          Some(
            web_host_string_to_string(web_settings_read(web_host_string(key))),
          ),
        )
      } else {
        @host.HostServiceResponse::SettingValue(None)
      }
    Write(key, value) =>
      if web_settings_write(web_host_string(key), web_host_string(value)) {
        @host.HostServiceResponse::SettingWritten
      } else {
        @host.HostServiceResponse::Unavailable("settings write failed")
      }
    Remove(key) =>
      if web_settings_remove(web_host_string(key)) {
        @host.HostServiceResponse::SettingRemoved
      } else {
        @host.HostServiceResponse::Unavailable("settings remove failed")
      }
  }
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
fn web_settings_read(key : WebHostString) -> WebHostString = "window_web" "settings_read"

///|
fn web_settings_has_value(key : WebHostString) -> Bool = "window_web" "settings_has_value"

///|
fn web_settings_write(key : WebHostString, value : WebHostString) -> Bool = "window_web" "settings_write"

///|
fn web_settings_remove(key : WebHostString) -> Bool = "window_web" "settings_remove"

///|
fn web_accessibility_contrast() -> Int = "window_web" "accessibility_contrast"

///|
fn web_reduced_motion() -> Int = "window_web" "reduced_motion"

///|
fn web_text_scale() -> Double = "window_web" "text_scale"

///|
extern "wasm" fn web_wall_clock_year() -> Int = "window_web" "wall_clock_year"

///|
extern "wasm" fn web_wall_clock_month() -> Int = "window_web" "wall_clock_month"

///|
extern "wasm" fn web_wall_clock_day() -> Int = "window_web" "wall_clock_day"

///|
extern "wasm" fn web_wall_clock_weekday() -> Int = "window_web" "wall_clock_weekday"

///|
extern "wasm" fn web_wall_clock_hour() -> Int = "window_web" "wall_clock_hour"

///|
extern "wasm" fn web_wall_clock_minute() -> Int = "window_web" "wall_clock_minute"

///|
extern "wasm" fn web_wall_clock_second() -> Int = "window_web" "wall_clock_second"

///|
fn web_async_clipboard_read_text(request_id : Int) -> Unit = "window_web" "clipboard_read_text_async"

//|

///|
fn web_async_clipboard_read_image(request_id : Int) -> Unit = "window_web" "clipboard_read_image_async"

//|

///|
#borrow(data)
fn web_clipboard_write_image(data : WebHostString) -> Bool = "window_web" "clipboard_write_image"

///|
fn web_async_text_file_read(request_id : Int, path : WebHostString) -> Unit = "window_web" "text_file_read_async"

///|
fn web_async_file_dialog_open(
  request_id : Int,
  kind : Int,
  title : WebHostString,
  filters : WebHostString,
  default_name : WebHostString,
) -> Unit = "window_web" "file_dialog_open_async"

///|
fn web_async_text_file_write(
  request_id : Int,
  path : WebHostString,
  text : WebHostString,
) -> Unit = "window_web" "text_file_write_async"

///|
pub fn request_animation_frame_event() -> @host.Event {
  @host.Event::RedrawRequested
}
