///|
pub(all) struct HostSurfaceMetrics {
  logical_size : @core.Size
  physical_size : @core.Size
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostCoordinateSpace {
  LogicalPixels
  PhysicalPixels
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostCoordinatePolicy {
  input_space : HostCoordinateSpace
  surface_space : HostCoordinateSpace
  scale_factor_applied : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostBackendKind {
  Native
  Web
  Test
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostAppInfo {
  backend : HostBackendKind
  uses_shared_event_model : Bool
  uses_shared_surface_model : Bool
  uses_shared_input_model : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostInputCapabilities {
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  focus : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceCapabilities {
  clipboard : Bool
  menus : Bool
  file_dialogs : Bool
  open_url : Bool
  system_theme : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostClipboardRequest {
  ReadText
  WriteText(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostFileDialogKind {
  OpenFile
  SaveFile
  PickDirectory
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFileDialogOptions {
  kind : HostFileDialogKind
  title : String
  filters : Array[String]
  default_name : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceRequest {
  Clipboard(HostClipboardRequest)
  ShowMenu(Array[@core.ActionCommand])
  FileDialog(HostFileDialogOptions)
  OpenUrl(String)
  QuerySystemTheme
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostServiceResponse {
  Unavailable(String)
  ClipboardText(String)
  ClipboardWritten
  MenuCommand(@core.CommandIntent)
  FileDialogSelection(Array[String])
  UrlOpened
  SystemTheme(@core.ColorScheme)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceBridge {
  capabilities : HostServiceCapabilities
  handle : (HostServiceRequest) -> HostServiceResponse
}

///|
pub(all) struct HostInputContract {
  capabilities : HostInputCapabilities
  coordinates : HostCoordinatePolicy
} derive(Eq, Debug, ToJson)

///|
pub(all) struct InputHostState {
  mut focused : Bool
  mut modifiers : @core.KeyModifiers
  contract : HostInputContract
}

///|
pub(all) struct SurfaceHostState {
  mut metrics : HostSurfaceMetrics
  owns_surface : Bool
  can_reconfigure : Bool
}

///|
pub(all) enum HostScrollPhase {
  Started
  Moved
  Ended
  Cancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostScrollDelta {
  Lines(@core.Point)
  Pixels(@core.Point)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostScrollEvent {
  position : @core.Point
  delta : HostScrollDelta
  phase : HostScrollPhase
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFocusEvent {
  focused : Bool
  pointer_cancel_position : @core.Point?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostEvent {
  Resized(HostSurfaceMetrics)
  Pointer(@core.PointerEvent)
  Scroll(HostScrollEvent)
  Focus(HostFocusEvent)
  Keyboard(@core.KeyboardEvent)
  TextInput(@core.TextInputEvent)
  Command(@core.CommandIntent)
  RedrawRequested
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostEventResult {
  needs_rebuild : Bool
  needs_redraw : Bool
  redraw_requested : Bool
  close_requested : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RedrawScheduler {
  mut redraw_requested : Bool
  mut schedule : () -> Unit
}

///|
pub(all) struct HostRuntimeDriver {
  runtime : @core.AppRuntime
  scheduler : RedrawScheduler
  mut close_requested : Bool
}

///|
pub fn HostSurfaceMetrics::new(
  logical_size~ : @core.Size,
  physical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  { logical_size, physical_size, scale_factor }
}

///|
pub fn HostSurfaceMetrics::from_logical(
  size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> HostSurfaceMetrics {
  {
    logical_size: size,
    physical_size: @core.Size::new(
      width=size.width * scale_factor,
      height=size.height * scale_factor,
    ),
    scale_factor,
  }
}

///|
pub fn HostCoordinatePolicy::logical(
  description? : String = "Host input and surface metrics use logical pixels after DPR scaling.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::LogicalPixels,
    surface_space: HostCoordinateSpace::LogicalPixels,
    scale_factor_applied: true,
    description,
  }
}

///|
pub fn HostCoordinatePolicy::physical(
  description? : String = "Host input and surface metrics use physical pixels.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::PhysicalPixels,
    surface_space: HostCoordinateSpace::PhysicalPixels,
    scale_factor_applied: false,
    description,
  }
}

///|
pub fn HostAppInfo::new(
  backend~ : HostBackendKind,
  description? : String = "",
  uses_shared_event_model? : Bool = true,
  uses_shared_surface_model? : Bool = true,
  uses_shared_input_model? : Bool = true,
) -> HostAppInfo {
  {
    backend,
    uses_shared_event_model,
    uses_shared_surface_model,
    uses_shared_input_model,
    description,
  }
}

///|
pub fn HostInputCapabilities::new(
  pointer? : Bool = true,
  scroll? : Bool = true,
  keyboard? : Bool = true,
  focus? : Bool = true,
  text_input? : Bool = true,
  ime? : Bool = false,
  clipboard? : Bool = false,
) -> HostInputCapabilities {
  { pointer, scroll, keyboard, focus, text_input, ime, clipboard }
}

///|
pub fn HostInputCapabilities::none() -> HostInputCapabilities {
  {
    pointer: false,
    scroll: false,
    keyboard: false,
    focus: false,
    text_input: false,
    ime: false,
    clipboard: false,
  }
}

///|
pub fn HostServiceCapabilities::none() -> HostServiceCapabilities {
  {
    clipboard: false,
    menus: false,
    file_dialogs: false,
    open_url: false,
    system_theme: false,
  }
}

///|
pub fn HostServiceCapabilities::new(
  clipboard? : Bool = false,
  menus? : Bool = false,
  file_dialogs? : Bool = false,
  open_url? : Bool = false,
  system_theme? : Bool = false,
) -> HostServiceCapabilities {
  { clipboard, menus, file_dialogs, open_url, system_theme }
}

///|
pub fn HostFileDialogOptions::new(
  kind~ : HostFileDialogKind,
  title? : String = "",
  filters? : Array[String] = [],
  default_name? : String? = None,
) -> HostFileDialogOptions {
  { kind, title, filters, default_name }
}

///|
pub fn HostServiceBridge::new(
  capabilities~ : HostServiceCapabilities,
  handle~ : (HostServiceRequest) -> HostServiceResponse,
) -> HostServiceBridge {
  { capabilities, handle }
}

///|
pub fn HostServiceBridge::unavailable() -> HostServiceBridge {
  HostServiceBridge::new(
    capabilities=HostServiceCapabilities::none(),
    handle=request => HostServiceResponse::Unavailable(
      request.unavailable_message(),
    ),
  )
}

///|
pub fn HostServiceBridge::dispatch(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> HostServiceResponse {
  if self.can_handle(request) {
    (self.handle)(request)
  } else {
    HostServiceResponse::Unavailable(request.unavailable_message())
  }
}

///|
pub fn HostServiceBridge::can_handle(
  self : HostServiceBridge,
  request : HostServiceRequest,
) -> Bool {
  match request {
    Clipboard(_) => self.capabilities.clipboard
    ShowMenu(_) => self.capabilities.menus
    FileDialog(_) => self.capabilities.file_dialogs
    OpenUrl(_) => self.capabilities.open_url
    QuerySystemTheme => self.capabilities.system_theme
  }
}

///|
pub fn HostServiceRequest::unavailable_message(
  self : HostServiceRequest,
) -> String {
  match self {
    Clipboard(_) => "clipboard service is unavailable"
    ShowMenu(_) => "menu service is unavailable"
    FileDialog(_) => "file dialog service is unavailable"
    OpenUrl(_) => "open URL service is unavailable"
    QuerySystemTheme => "system theme service is unavailable"
  }
}

///|
pub fn HostInputContract::new(
  capabilities? : HostInputCapabilities = HostInputCapabilities::new(),
  coordinates? : HostCoordinatePolicy = HostCoordinatePolicy::logical(),
) -> HostInputContract {
  { capabilities, coordinates }
}

///|
pub fn InputHostState::new(
  focused? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
  contract? : HostInputContract = HostInputContract::new(),
) -> InputHostState {
  { focused, modifiers, contract }
}

///|
pub fn InputHostState::focus(self : InputHostState) -> Unit {
  self.focused = true
}

///|
pub fn InputHostState::blur(self : InputHostState) -> Unit {
  self.focused = false
}

///|
pub fn InputHostState::set_modifiers(
  self : InputHostState,
  modifiers : @core.KeyModifiers,
) -> Unit {
  self.modifiers = modifiers
}

///|
pub fn InputHostState::capabilities(
  self : InputHostState,
) -> HostInputCapabilities {
  self.contract.capabilities
}

///|
pub fn InputHostState::coordinate_policy(
  self : InputHostState,
) -> HostCoordinatePolicy {
  self.contract.coordinates
}

///|
pub fn InputHostState::focus_event(
  self : InputHostState,
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostEvent? {
  if self.contract.capabilities.focus {
    self.focused = focused
    Some(
      HostEvent::Focus(HostFocusEvent::new(focused~, pointer_cancel_position~)),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::keyboard_event(
  self : InputHostState,
  key~ : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
) -> HostEvent? {
  if self.contract.capabilities.keyboard {
    Some(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key~,
          text~,
          pressed~,
          repeat~,
          modifiers=self.modifiers,
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::text_event(
  self : InputHostState,
  event : @core.TextInputEvent,
) -> HostEvent? {
  if self.focused && self.contract.capabilities.text_input {
    Some(HostEvent::TextInput(event))
  } else {
    None
  }
}

///|
pub fn InputHostState::insert_text(
  self : InputHostState,
  text : String,
) -> HostEvent? {
  self.text_event(@core.TextInputEvent::InsertText(text))
}

///|
pub fn SurfaceHostState::new(
  metrics~ : HostSurfaceMetrics,
  owns_surface? : Bool = false,
  can_reconfigure? : Bool = true,
) -> SurfaceHostState {
  { metrics, owns_surface, can_reconfigure }
}

///|
pub fn SurfaceHostState::resize(
  self : SurfaceHostState,
  metrics : HostSurfaceMetrics,
) -> HostEvent {
  self.metrics = metrics
  HostEvent::Resized(metrics)
}

///|
pub fn HostScrollEvent::new(
  position~ : @core.Point,
  delta~ : HostScrollDelta,
  phase? : HostScrollPhase = HostScrollPhase::Moved,
) -> HostScrollEvent {
  { position, delta, phase }
}

///|
pub fn HostScrollDelta::to_logical_pixels(
  self : HostScrollDelta,
  line_extent? : Double = 40.0,
) -> @core.Point {
  match self {
    Pixels(delta) => delta
    Lines(delta) =>
      @core.Point::new(x=delta.x * line_extent, y=delta.y * line_extent)
  }
}

///|
pub fn HostScrollEvent::to_pointer_event(
  self : HostScrollEvent,
) -> @core.PointerEvent {
  @core.PointerEvent::new(
    position=self.position,
    phase=@core.PointerPhase::Move,
    wheel_delta=self.delta.to_logical_pixels(),
  )
}

///|
pub fn HostFocusEvent::new(
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostFocusEvent {
  { focused, pointer_cancel_position }
}

///|
pub fn HostFocusEvent::to_core(self : HostFocusEvent) -> @core.AppEvent? {
  match (self.focused, self.pointer_cancel_position) {
    (false, Some(position)) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase=@core.PointerPhase::Cancel),
        ),
      )
    _ => None
  }
}

///|
pub fn SurfaceHostState::logical_size(self : SurfaceHostState) -> @core.Size {
  self.metrics.logical_size
}

///|
pub fn RedrawScheduler::new(schedule~ : () -> Unit) -> RedrawScheduler {
  { redraw_requested: false, schedule }
}

///|
pub fn RedrawScheduler::request(self : RedrawScheduler) -> Unit {
  if !self.redraw_requested {
    self.redraw_requested = true
    (self.schedule)()
  }
}

///|
pub fn RedrawScheduler::begin_redraw(self : RedrawScheduler) -> Unit {
  self.redraw_requested = false
}

///|
pub fn RedrawScheduler::set_schedule(
  self : RedrawScheduler,
  schedule : () -> Unit,
) -> Unit {
  self.schedule = schedule
}

///|
pub fn RedrawScheduler::is_redraw_requested(self : RedrawScheduler) -> Bool {
  self.redraw_requested
}

///|
pub fn HostRuntimeDriver::new(
  runtime~ : @core.AppRuntime,
  schedule_redraw~ : () -> Unit,
) -> HostRuntimeDriver {
  let driver = {
    runtime,
    scheduler: RedrawScheduler::new(schedule=schedule_redraw),
    close_requested: false,
  }
  runtime.set_redraw_callback(() => driver.request_redraw())
  driver
}

///|
pub fn HostRuntimeDriver::dispatch(
  self : HostRuntimeDriver,
  event : HostEvent,
) -> HostEventResult {
  match event {
    Resized(metrics) => {
      self.runtime.dispatch_event(@core.AppEvent::Resize(metrics.logical_size))
      self.request_redraw()
    }
    Pointer(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Pointer(event))
      self.request_redraw_if_needed()
    }
    Scroll(event) => {
      self.runtime.dispatch_event(
        @core.AppEvent::Pointer(event.to_pointer_event()),
      )
      self.request_redraw_if_needed()
    }
    Focus(event) =>
      match event.to_core() {
        Some(core_event) => {
          self.runtime.dispatch_event(core_event)
          self.request_redraw_if_needed()
        }
        None => ()
      }
    Keyboard(event) => {
      self.runtime.dispatch_event(@core.AppEvent::Keyboard(event))
      self.request_redraw_if_needed()
    }
    TextInput(event) => {
      self.runtime.dispatch_event(@core.AppEvent::TextInput(event))
      self.request_redraw_if_needed()
    }
    Command(intent) => {
      if self.runtime.dispatch_command(intent) {
        self.request_redraw_if_needed()
      }
    }
    RedrawRequested => {
      self.begin_redraw()
      self.finish_redraw()
    }
    CloseRequested => {
      self.close_requested = true
      self.runtime.dispatch_event(@core.AppEvent::CloseRequested)
    }
  }
  self.event_result()
}

///|
pub fn HostRuntimeDriver::request_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.request()
}

///|
pub fn HostRuntimeDriver::set_redraw_scheduler(
  self : HostRuntimeDriver,
  schedule_redraw : () -> Unit,
) -> Unit {
  self.scheduler.set_schedule(schedule_redraw)
}

///|
pub fn HostRuntimeDriver::request_redraw_if_needed(
  self : HostRuntimeDriver,
) -> Unit {
  if self.runtime.needs_redraw() {
    self.request_redraw()
  }
}

///|
pub fn HostRuntimeDriver::begin_redraw(self : HostRuntimeDriver) -> Unit {
  self.scheduler.begin_redraw()
}

///|
pub fn HostRuntimeDriver::finish_redraw(self : HostRuntimeDriver) -> Unit {
  self.runtime.dispatch_event(
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
  )
}

///|
pub fn HostRuntimeDriver::draw_commands(
  self : HostRuntimeDriver,
) -> Array[@core.DrawCommand] {
  self.runtime.draw_commands()
}

///|
pub fn HostRuntimeDriver::size(self : HostRuntimeDriver) -> @core.Size {
  self.runtime.size()
}

///|
pub fn HostRuntimeDriver::event_result(
  self : HostRuntimeDriver,
) -> HostEventResult {
  {
    needs_rebuild: self.runtime.needs_rebuild(),
    needs_redraw: self.runtime.needs_redraw(),
    redraw_requested: self.scheduler.is_redraw_requested(),
    close_requested: self.close_requested,
  }
}

///|
pub fn HostEvent::to_core(self : HostEvent) -> @core.AppEvent? {
  match self {
    Resized(metrics) => Some(@core.AppEvent::Resize(metrics.logical_size))
    Pointer(event) => Some(@core.AppEvent::Pointer(event))
    Scroll(event) => Some(@core.AppEvent::Pointer(event.to_pointer_event()))
    Focus(event) => event.to_core()
    Keyboard(event) => Some(@core.AppEvent::Keyboard(event))
    TextInput(event) => Some(@core.AppEvent::TextInput(event))
    Command(_) => None
    RedrawRequested =>
      Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    CloseRequested => Some(@core.AppEvent::CloseRequested)
  }
}
