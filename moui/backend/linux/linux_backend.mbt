///|
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_ready : Bool
  capabilities : LinuxBackendCapabilities
  accessibility : LinuxAccessibilityBridgeInfo
  services : @host.HostServiceCapabilities
  readiness : LinuxBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxBackendCapabilities {
  window : Bool
  renderer : Bool
  titlebar : Bool
  pointer : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  drag_drop : Bool
  accessibility : Bool
  scale_factor : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxBackendReadiness {
  ready : Bool
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxAccessibilityBridgeInfo {
  kind : @host.NativeAccessibilityBridgeKind
  contract_ready : Bool
  native_binding_ready : Bool
  action_roundtrip_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct LinuxHostAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv exit_after_first_present : Bool
}

///|
pub struct LinuxRendererProvider {
  priv create_renderer : (@window_linux.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (@window_linux.Window, @host.HostSurfaceMetrics) -> Unit
}

///|
pub(all) struct LinuxClientDecorationState {
  active : Bool
  titlebar_height : Double
} derive(Eq, Debug, ToJson)

///|
struct LinuxApp {
  title : String
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : LinuxRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : LinuxWindowPlatformSlots
  image_repaint_tracker : @host.HostImageResourceRepaintTracker
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut exit_after_first_present : Bool
}

///|
priv struct LinuxWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_linux.Window
  renderer : @host.HostWindowRenderer
  mut decorations : LinuxClientDecorationState
}

///|
priv struct LinuxWindowPlatformSlots {
  mut slots : Array[LinuxWindowPlatformSlot]
}

///|
pub fn LinuxHostAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  exit_after_first_present? : Bool = false,
) -> LinuxHostAppOptions {
  { scene_resolver, exit_after_first_present }
}

///|
pub fn LinuxRendererProvider::new(
  create_renderer~ : (@window_linux.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (@window_linux.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
) -> LinuxRendererProvider {
  { create_renderer, sync_surface }
}

///|
pub fn LinuxClientDecorationState::new(
  active~ : Bool,
  titlebar_height? : Double = linux_client_titlebar_height,
) -> LinuxClientDecorationState {
  { active, titlebar_height: if active { titlebar_height } else { 0.0 } }
}

///|
let linux_client_titlebar_height : Double = 32.0

///|
pub fn capability_matrix() -> LinuxBackendCapabilities {
  {
    window: true,
    renderer: true,
    titlebar: true,
    pointer: true,
    keyboard: true,
    text_input: false,
    ime: false,
    clipboard: false,
    drag_drop: false,
    accessibility: false,
    scale_factor: false,
  }
}

///|
pub fn service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::new(system_theme=true)
}

///|
pub fn linux_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=false,
    ime=false,
    clipboard=false,
    drag_drop=false,
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
    text_input_ready=false,
    ime_ready=false,
    drag_drop_ready=false,
    async_services=false,
    native_accessibility_ready=backend_info().accessibility.native_binding_ready,
    description="Wayland host summary with renderer/window readiness and explicit gaps for clipboard, menus, file dialogs, text input, IME, drag/drop, and AT-SPI binding.",
  )
}

///|
pub fn readiness() -> LinuxBackendReadiness {
  {
    ready: true,
    blocked_by: [
      "Linux clipboard, menus, file dialogs, drag/drop, and AT-SPI bindings are not implemented yet",
      "Linux text input and IME requests are still reported as unsupported by the window backend",
      "Linux native fontconfig/HarfBuzz/FreeType provider remains a scaffold and composes with Moon Cosmic fallback",
    ],
    next_steps: [
      "map Linux clipboard, menus, file dialogs, drag/drop, and accessibility through host service contracts",
      "wire text input and IME through the Wayland backend when the window package exposes it",
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
    renderer_ready: true,
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
    contract_ready: true,
    native_binding_ready: false,
    action_roundtrip_ready: true,
    description: "Linux exposes an AT-SPI accessibility bridge contract over the shared semantics tree; real AT-SPI provider binding is still a backend follow-up.",
  }
}

///|
pub fn linux_accessibility_bridge(
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> @host.NativeAccessibilityBridge {
  @host.NativeAccessibilityBridge::semantics_action_bridge(
    kind=@host.NativeAccessibilityBridgeKind::ATSPI,
    root~,
    dispatch~,
  )
}

///|
pub fn linux_service_bridge(
  system_theme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(capabilities=service_capabilities(), handle=request => {
    match request {
      @host.HostServiceRequest::QuerySystemTheme =>
        @host.HostServiceResponse::SystemTheme(system_theme)
      @host.HostServiceRequest::Clipboard(_) =>
        @host.HostServiceResponse::Unavailable(
          "clipboard service is unavailable",
        )
      @host.HostServiceRequest::OpenUrl(_) =>
        @host.HostServiceResponse::Unavailable(
          "open URL service is unavailable",
        )
      @host.HostServiceRequest::FileDialog(_) =>
        @host.HostServiceResponse::Unavailable(
          "file dialog service is unavailable",
        )
      @host.HostServiceRequest::ShowMenu(_) =>
        @host.HostServiceResponse::Unavailable("menu service is unavailable")
    }
  })
}

///|
pub fn scaffold_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::unavailable()
}

///|
pub fn scaffold_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.SurfaceHostState {
  @host.SurfaceHostState::new(
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=logical_width, height=logical_height),
      scale_factor~,
    ),
    owns_surface=false,
    can_reconfigure=false,
  )
}

///|
pub fn scaffold_input_host() -> @host.InputHostState {
  @host.InputHostState::new(
    focused=false,
    contract=@host.HostInputContract::new(
      capabilities=@host.HostInputCapabilities::none(),
      coordinates=@host.HostCoordinatePolicy::logical(
        description="Linux input is emitted by the Wayland backend; the scaffold host exposes a no-input contract for tests.",
      ),
    ),
  )
}

///|
pub fn linux_client_decorated_commands(
  commands : Array[@core.DrawCommand],
  title~ : String,
  metrics~ : @host.HostSurfaceMetrics,
  decorations~ : LinuxClientDecorationState,
) -> Array[@core.DrawCommand] {
  if !decorations.active {
    commands
  } else {
    let titlebar = decorations.titlebar_height
    let width = metrics.logical_size.width
    let height = metrics.logical_size.height
    let output : Array[@core.DrawCommand] = []
    output.push(@core.DrawCommand::Clear(linux_first_clear_color(commands)))
    output.push(
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width~, height=titlebar),
        linux_titlebar_background_color(),
      ),
    )
    output.push(
      @core.DrawCommand::StrokeRect(
        @core.Rect::new(x=0.0, y=titlebar - 1.0, width~, height=1.0),
        linux_titlebar_border_color(),
        1.0,
      ),
    )
    output.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=title,
          frame=@core.Rect::new(
            x=14.0,
            y=5.0,
            width=(width - 150.0).max(24.0),
            height=22.0,
          ),
          font=@core.FontSpec::new(size=14.0, weight=700),
          color=linux_titlebar_text_color(),
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=2,
      color=linux_titlebar_minimize_color(),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=1,
      color=linux_titlebar_maximize_color(),
    )
    append_linux_titlebar_button(
      output,
      width~,
      index_from_right=0,
      color=linux_titlebar_close_color(),
    )
    let content_height = (height - titlebar).max(1.0)
    output.push(
      @core.DrawCommand::PushClip(
        @core.Rect::new(x=0.0, y=titlebar, width~, height=content_height),
      ),
    )
    output.push(
      @core.DrawCommand::PushTransform(
        @core.Transform2D::translation(dx=0.0, dy=titlebar),
      ),
    )
    for command in commands {
      match command {
        @core.DrawCommand::Clear(_) => ()
        _ => output.push(command)
      }
    }
    output.push(@core.DrawCommand::PopTransform)
    output.push(@core.DrawCommand::PopClip)
    output
  }
}

///|
pub fn linux_surface_metrics_for_content(
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @host.HostSurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @host.HostSurfaceMetrics::new(
      logical_size=@core.Size::new(
        width=metrics.logical_size.width,
        height=metrics.logical_size.height + logical_titlebar,
      ),
      physical_size=@core.Size::new(
        width=metrics.physical_size.width,
        height=metrics.physical_size.height + physical_titlebar,
      ),
      scale_factor=metrics.scale_factor,
    )
  }
}

///|
pub fn linux_content_metrics_for_surface(
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> @host.HostSurfaceMetrics {
  if !decorations.active {
    metrics
  } else {
    let logical_titlebar = decorations.titlebar_height
    let physical_titlebar = logical_titlebar * metrics.scale_factor
    @host.HostSurfaceMetrics::new(
      logical_size=@core.Size::new(
        width=metrics.logical_size.width,
        height=(metrics.logical_size.height - logical_titlebar).max(1.0),
      ),
      physical_size=@core.Size::new(
        width=metrics.physical_size.width,
        height=(metrics.physical_size.height - physical_titlebar).max(1.0),
      ),
      scale_factor=metrics.scale_factor,
    )
  }
}

///|
fn linux_request_surface_for_content(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  decorations : LinuxClientDecorationState,
) -> Unit {
  let surface_metrics = linux_surface_metrics_for_content(metrics, decorations)
  ignore(window.request_surface_size(host_metrics_to_dpi_size(surface_metrics)))
}

///|
fn linux_window_surface_metrics(
  window : @window_linux.Window,
) -> @host.HostSurfaceMetrics {
  @host.surface_metrics_from_physical(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
}

///|
fn linux_first_clear_color(commands : Array[@core.DrawCommand]) -> @core.Color {
  let mut clear = @core.Color::white()
  let mut found = false
  for command in commands {
    if !found {
      match command {
        @core.DrawCommand::Clear(color) => {
          clear = color
          found = true
        }
        _ => ()
      }
    }
  }
  clear
}

///|
fn linux_titlebar_background_color() -> @core.Color {
  @core.Color::rgba(r=0.96, g=0.97, b=0.98)
}

///|
fn linux_titlebar_border_color() -> @core.Color {
  @core.Color::rgba(r=0.80, g=0.83, b=0.88)
}

///|
fn linux_titlebar_text_color() -> @core.Color {
  @core.Color::rgba(r=0.06, g=0.07, b=0.09)
}

///|
fn linux_titlebar_close_color() -> @core.Color {
  @core.Color::rgba(r=0.88, g=0.35, b=0.35)
}

///|
fn linux_titlebar_maximize_color() -> @core.Color {
  @core.Color::rgba(r=0.31, g=0.72, b=0.42)
}

///|
fn linux_titlebar_minimize_color() -> @core.Color {
  @core.Color::rgba(r=0.90, g=0.72, b=0.30)
}

///|
fn append_linux_titlebar_button(
  commands : Array[@core.DrawCommand],
  width~ : Double,
  index_from_right~ : Int,
  color~ : @core.Color,
) -> Unit {
  let slot = 28.0
  let gap = 8.0
  let size = 12.0
  let left = width -
    gap -
    (index_from_right + 1).to_double() * slot -
    index_from_right.to_double() * gap +
    (slot - size) / 2.0
  commands.push(
    @core.DrawCommand::FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=left, y=10.0, width=size, height=size),
        radius=6.0,
      ),
      color,
    ),
  )
}

///|
fn linux_client_decoration_state(
  window : @window_linux.Window,
) -> LinuxClientDecorationState {
  LinuxClientDecorationState::new(active=window.uses_client_decorations())
}

///|
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : LinuxRendererProvider,
  options? : LinuxHostAppOptions = LinuxHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let event_loop = @window_linux.EventLoop::new()
  let services = linux_service_bridge(
    system_theme=linux_color_scheme_from_theme(event_loop.system_theme()),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = LinuxApp::{
    title,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    renderer_provider: provider,
    services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: LinuxWindowPlatformSlots::new(),
    image_repaint_tracker: @host.HostImageResourceRepaintTracker::new(),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    exit_after_first_present: options.exit_after_first_present,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.run_app(app)
}

///|
fn linux_color_scheme_from_theme(
  theme : @window_core.Theme?,
) -> @core.ColorScheme {
  match theme {
    Some(@window_core.Theme::Dark) => @core.ColorScheme::Dark
    _ => @core.ColorScheme::Light
  }
}

///|
pub fn window_event_to_core(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @core.AppEvent? {
  @host.window_event_to_core(event, last_pointer)
}

///|
pub fn window_event_to_core_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @core.AppEvent? {
  match window_event_to_host_with_modifiers(event, last_pointer, modifiers) {
    Some(host_event) => host_event.to_core()
    None => None
  }
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  @host.window_event_to_host(event, last_pointer)
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(event, last_pointer, modifiers)
}

///|
pub fn linux_adjust_host_event_for_client_decorations(
  event : @host.HostEvent,
  decorations : LinuxClientDecorationState,
) -> @host.HostEvent? {
  if !decorations.active {
    Some(event)
  } else {
    match event {
      @host.HostEvent::Pointer(pointer) => {
        let y = pointer.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.HostEvent::Pointer(
              @core.PointerEvent::new(
                position=@core.Point::new(x=pointer.position.x, y~),
                phase=pointer.phase,
                button=pointer.button,
                wheel_delta=pointer.wheel_delta,
                time_ms=pointer.time_ms,
              ),
            ),
          )
        }
      }
      @host.HostEvent::Scroll(scroll) => {
        let y = scroll.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.HostEvent::Scroll(
              @host.HostScrollEvent::new(
                position=@core.Point::new(x=scroll.position.x, y~),
                delta=scroll.delta,
                phase=scroll.phase,
              ),
            ),
          )
        }
      }
      @host.HostEvent::DragDrop(drop) =>
        match drop.position {
          Some(position) => {
            let y = position.y - decorations.titlebar_height
            let paths = drop.paths.copy()
            if y < 0.0 {
              None
            } else {
              Some(
                @host.HostEvent::DragDrop(
                  @core.DragDropEvent::new(
                    phase=drop.phase,
                    paths~,
                    position=Some(@core.Point::new(x=position.x, y~)),
                  ),
                ),
              )
            }
          }
          None => Some(event)
        }
      @host.HostEvent::Resized(metrics) =>
        Some(@host.HostEvent::Resized(metrics))
      _ => Some(event)
    }
  }
}

///|
fn LinuxWindowPlatformSlots::new() -> LinuxWindowPlatformSlots {
  { slots: [] }
}

///|
fn LinuxWindowPlatformSlots::insert(
  self : LinuxWindowPlatformSlots,
  slot : LinuxWindowPlatformSlot,
) -> Bool {
  match
    (self.lookup_host(slot.host_id), self.lookup_platform(slot.platform_id)) {
    (None, None) => {
      self.slots.push(slot)
      true
    }
    _ => false
  }
}

///|
fn LinuxWindowPlatformSlots::lookup_host(
  self : LinuxWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> LinuxWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn LinuxWindowPlatformSlots::lookup_platform(
  self : LinuxWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> LinuxWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn LinuxWindowPlatformSlots::remove_host(
  self : LinuxWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> LinuxWindowPlatformSlot? {
  let mut removed = None
  let kept = []
  for slot in self.slots {
    if slot.host_id == host_id {
      removed = Some(slot)
    } else {
      kept.push(slot)
    }
  }
  self.slots = kept
  removed
}

///|
pub impl @window_linux.ApplicationHandler for LinuxApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(runtime_size_to_window_surface_size(self.runtime.size()))
  let linux_attributes = @window_linux.WindowAttributesLinux::default().with_app_id(
    "dev.wzzc.moui.showcase",
  )
  let window : @window_linux.Window? = Some(
    event_loop.try_create_window_with_linux_attributes(
      attributes, linux_attributes,
    ),
  ) catch {
    err => {
      println("error creating Linux window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let initial_surface_metrics = linux_window_surface_metrics(window)
      let decorations = linux_client_decoration_state(window)
      let initial_metrics = linux_content_metrics_for_surface(
        initial_surface_metrics, decorations,
      )
      if decorations.active {
        linux_request_surface_for_content(window, initial_metrics, decorations)
      }
      let surface_metrics = linux_window_surface_metrics(window)
      let metrics = linux_content_metrics_for_surface(
        surface_metrics, decorations,
      )
      let window_id = self.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.renderer_provider.create_renderer)(window, surface_metrics) {
        Some(renderer) => {
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
          ignore(
            self.platform_slots.insert({
              host_id: window_id,
              platform_id: window.id(),
              window,
              renderer,
              decorations,
            }),
          )
          window.request_redraw()
          self.drain_window_requests(event_loop)
        }
        None => {
          self.rollback_window_record(window_id)
          window.drop()
          event_loop.exit()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @window_linux.ApplicationHandler for LinuxApp with fn window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match self.platform_windows.lookup_host(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(window_id, event)
      self.dispose_window(window_id)
      if self.runtime_slots.is_empty() {
        event_loop.exit()
      }
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      let mut dispatched = false
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          slot.decorations = linux_client_decoration_state(slot.window)
          let surface_metrics = linux_window_surface_metrics(slot.window)
          let metrics = linux_content_metrics_for_surface(
            surface_metrics,
            slot.decorations,
          )
          ignore(self.windows.resize(window_id, metrics))
          self.sync_runtime_slot(window_id)
          (self.renderer_provider.sync_surface)(slot.window, surface_metrics)
          slot.renderer.resize(surface_metrics)
          slot.window.request_redraw()
          self.dispatch_host_event(window_id, @host.HostEvent::Resized(metrics))
          dispatched = true
        }
        None => ()
      }
      if !dispatched {
        self.dispatch_window_event(window_id, event)
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      let mut dispatched = false
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          slot.decorations = linux_client_decoration_state(slot.window)
          let surface_metrics = linux_window_surface_metrics(slot.window)
          let metrics = linux_content_metrics_for_surface(
            surface_metrics,
            slot.decorations,
          )
          ignore(self.windows.resize(window_id, metrics))
          self.sync_runtime_slot(window_id)
          (self.renderer_provider.sync_surface)(slot.window, surface_metrics)
          slot.renderer.resize(surface_metrics)
          slot.window.request_redraw()
          self.dispatch_host_event(window_id, @host.HostEvent::Resized(metrics))
          dispatched = true
        }
        None => ()
      }
      if !dispatched {
        self.dispatch_window_event(window_id, event)
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::Ime(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::RedrawRequested =>
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxApp::dispatch_pointer_or_context_menu(
  self : LinuxApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if self.pointer_is_in_client_titlebar(window_id) {
      return ()
    }
    if @host.window_event_is_context_menu_trigger(event) {
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxApp::pointer_is_in_client_titlebar(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) =>
      slot.decorations.active &&
      self.last_pointer.y < slot.decorations.titlebar_height
    None => false
  }
}

///|
fn LinuxApp::redraw_window(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      platform_slot.window.pre_present_notify()
      runtime_slot.driver.begin_redraw()
      let surface_metrics = linux_window_surface_metrics(platform_slot.window)
      let commands = linux_client_decorated_commands(
        runtime_slot.driver.draw_commands(),
        title=runtime_slot.record.title,
        metrics=surface_metrics,
        decorations=platform_slot.decorations,
      )
      platform_slot.renderer.render(commands)
      runtime_slot.driver.finish_redraw()
      ignore(
        self.image_repaint_tracker.record_presented(
          window_id,
          platform_slot.renderer,
        ),
      )
      self.sync_text_input_session()
      if self.exit_after_first_present &&
        platform_slot.renderer.present_count() > 0 {
        println("Linux renderer presented first frame; exiting by request")
        self.exit_after_first_present = false
        self.dispose_window(window_id)
        true
      } else {
        false
      }
    }
    _ => false
  }
}

///|
fn LinuxApp::dispatch_window_event(
  self : LinuxApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
    ) {
    Some(host_event) => self.dispatch_host_event(window_id, host_event)
    None => ()
  }
}

///|
fn LinuxApp::dispatch_host_event(
  self : LinuxApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  let decorations = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.decorations
    None => LinuxClientDecorationState::new(active=false)
  }
  match
    linux_adjust_host_event_for_client_decorations(host_event, decorations) {
    Some(adjusted) => {
      self.apply_window_lifecycle(window_id, adjusted)
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match adjusted {
            @host.HostEvent::Keyboard(event) =>
              ignore(
                slot.driver.dispatch_keyboard_with_services(
                  event,
                  self.services,
                ),
              )
            _ => ignore(slot.driver.dispatch(adjusted))
          }
        None => ()
      }
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn LinuxApp::drain_window_requests(
  self : LinuxApp,
  event_loop : @window_linux.ActiveEventLoop,
) -> Unit {
  ignore(
    self.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn LinuxApp::apply_window_request(
  self : LinuxApp,
  event_loop : @window_linux.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(open_request) =>
      self.open_window(event_loop, open_request)
    @host.HostWindowRequest::FocusWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.focus_window()
      })
    @host.HostWindowRequest::CloseWindow(id) =>
      self.apply_platform_window_request(id, request, _window => {
        self.dispose_window(id)
        if self.runtime_slots.is_empty() {
          event_loop.exit()
        }
      })
    @host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, window => {
        match self.platform_slots.lookup_host(id) {
          Some(slot) => {
            linux_request_surface_for_content(window, metrics, slot.decorations)
            let surface_metrics = linux_window_surface_metrics(window)
            let content_metrics = linux_content_metrics_for_surface(
              surface_metrics,
              slot.decorations,
            )
            ignore(self.windows.resize(id, content_metrics))
            self.sync_runtime_slot(id)
            (self.renderer_provider.sync_surface)(window, surface_metrics)
            slot.renderer.resize(surface_metrics)
          }
          None => {
            ignore(
              window.request_surface_size(host_metrics_to_dpi_size(metrics)),
            )
            (self.renderer_provider.sync_surface)(window, metrics)
          }
        }
        window.request_redraw()
      })
    @host.HostWindowRequest::MinimizeWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(true)
      })
    @host.HostWindowRequest::ShowWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(false)
        window.set_visible(true)
      })
    @host.HostWindowRequest::SetPrimaryWindow(id) =>
      self.apply_platform_window_request(id, request, _window => ())
  }
}

///|
fn LinuxApp::apply_platform_window_request(
  self : LinuxApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_linux.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match self.platform_slots.lookup_host(id) {
    Some(slot) => {
      let result = self.runtime_slots.apply_request(self.windows, request)
      match result {
        @host.HostWindowRequestResult::WindowRejected(_) => ()
        _ => apply(slot.window)
      }
      result
    }
    None =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active Linux window",
      )
  }
}

///|
fn LinuxApp::open_window(
  self : LinuxApp,
  event_loop : @window_linux.ActiveEventLoop,
  request : @host.HostWindowOpenRequest,
) -> @host.HostWindowRequestResult {
  match self.windows.resolve_open_request(request, self.scene_resolver) {
    @host.HostWindowOpenResolution::OpenRejected(message) =>
      @host.HostWindowRequestResult::WindowRejected(message)
    @host.HostWindowOpenResolution::OpenResolved(resolved) =>
      self.create_resolved_window(event_loop, resolved)
  }
}

///|
fn LinuxApp::create_resolved_window(
  self : LinuxApp,
  event_loop : @window_linux.ActiveEventLoop,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let requested_surface_metrics = linux_surface_metrics_for_content(
    resolved.record.metrics,
    LinuxClientDecorationState::new(active=true),
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(host_metrics_to_dpi_size(requested_surface_metrics))
  let linux_attributes = @window_linux.WindowAttributesLinux::default().with_app_id(
    "dev.wzzc.moui.showcase",
  )
  let window : @window_linux.Window? = Some(
    event_loop.try_create_window_with_linux_attributes(
      attributes, linux_attributes,
    ),
  ) catch {
    err => {
      println("error creating Linux window: \{err}")
      None
    }
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Linux window",
      )
    }
  }
}

///|
fn LinuxApp::attach_resolved_window(
  self : LinuxApp,
  window : @window_linux.Window,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let initial_surface_metrics = linux_window_surface_metrics(window)
  let decorations = linux_client_decoration_state(window)
  let initial_metrics = linux_content_metrics_for_surface(
    initial_surface_metrics, decorations,
  )
  if decorations.active {
    linux_request_surface_for_content(window, initial_metrics, decorations)
  }
  let surface_metrics = linux_window_surface_metrics(window)
  let metrics = linux_content_metrics_for_surface(surface_metrics, decorations)
  match (self.renderer_provider.create_renderer)(window, surface_metrics) {
    Some(renderer) => {
      ignore(self.windows.resize(resolved.id, metrics))
      ignore(self.runtime_slots.sync_open_from_registry(self.windows))
      let record = match self.windows.lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @host.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(resolved.id)
      })
      driver.set_environment(
        self.services.environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      ignore(
        self.runtime_slots.insert(
          @host.HostWindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=resolved.id),
      )
      ignore(
        self.platform_slots.insert({
          host_id: resolved.id,
          platform_id: window.id(),
          window,
          renderer,
          decorations,
        }),
      )
      self.request_platform_redraw(resolved.id)
      @host.HostWindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Linux renderer",
      )
    }
  }
}

///|
fn LinuxApp::register_primary_runtime_slot(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(
    self.runtime_slots.insert_from_registry(
      self.windows,
      window_id,
      driver=self.driver,
    ),
  )
}

///|
fn LinuxApp::sync_runtime_slot(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
fn LinuxApp::sync_runtime_slots(self : LinuxApp) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
fn LinuxApp::apply_window_lifecycle(
  self : LinuxApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  ignore(
    self.runtime_slots.apply_host_event(self.windows, window_id, host_event),
  )
}

///|
fn LinuxApp::active_runtime_slot(
  self : LinuxApp,
) -> @host.HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
fn LinuxApp::sync_text_input_session(self : LinuxApp) -> Unit {
  match self.active_runtime_slot() {
    Some(runtime_slot) =>
      match self.platform_slots.lookup_host(runtime_slot.id) {
        Some(platform_slot) =>
          match
            self.text_input_session.sync(
              runtime_slot.driver.focused_text_input(),
            ) {
            @host.TextInputSessionAction::EnableIme(request)
            | @host.TextInputSessionAction::UpdateIme(request)
            | @host.TextInputSessionAction::DisableIme(request) =>
              platform_slot.window.request_ime_update(request) catch {
                _ => ()
              }
            @host.TextInputSessionAction::NoImeChange => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn LinuxApp::current_scale_factor(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn runtime_slot_needs_redraw(slot : @host.HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn LinuxApp::request_redraw(self : LinuxApp) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn LinuxApp::request_redraw_window_if_needed(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) => {
      let image_redraw_requested = self.request_image_resource_redraw_if_changed(
        window_id,
      )
      if runtime_slot_needs_redraw(slot) && !image_redraw_requested {
        self.request_platform_redraw(window_id)
      }
    }
    None => ()
  }
}

///|
fn LinuxApp::request_image_resource_redraw_if_changed(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      let result = self.image_repaint_tracker.request_redraw_if_changed(
        window_id,
        platform_slot.renderer,
        window_open=runtime_slot.record.phase !=
          @host.HostWindowLifecyclePhase::WindowClosed,
        request_redraw=id => self.request_platform_redraw(id),
      )
      result.status ==
      @host.HostImageResourceRepaintStatus::ImageRepaintRequested
    }
    (Some(platform_slot), None) => {
      ignore(
        self.image_repaint_tracker.request_redraw_if_changed(
          window_id,
          platform_slot.renderer,
          window_open=false,
          request_redraw=_id => (),
        ),
      )
      false
    }
    _ => false
  }
}

///|
fn LinuxApp::request_platform_redraw(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn LinuxApp::dispose_window(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  self.sync_runtime_slot(window_id)
  ignore(self.image_repaint_tracker.remove_window(window_id))
  ignore(self.runtime_slots.remove(window_id))
  ignore(self.platform_windows.remove_host(window_id))
  match self.platform_slots.remove_host(window_id) {
    Some(slot) => {
      slot.renderer.dispose()
      slot.window.drop()
    }
    None => ()
  }
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
fn LinuxApp::rollback_window_record(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
fn runtime_size_to_window_surface_size(size : @core.Size) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(size.width, size.height).into_size()
}

///|
fn host_metrics_to_dpi_size(metrics : @host.HostSurfaceMetrics) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
}
