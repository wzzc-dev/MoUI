///|
pub(all) struct WinitWebWasmBackendInfo {
  host_info : @host.HostAppInfo
  uses_window_web_backend : Bool
  has_wgpu_wasm_renderer : Bool
  keeps_js_webgpu_fallback : Bool
  renderer_info : @render.RendererBackendInfo
  surface_contract : @render.WgpuSurfaceContract
  description : String
} derive(Eq, Debug, ToJson)

///|
struct WinitWebWasmApp {
  title : String
  mut window : @web.Window?
  runtime : @backend.AppRuntime
  driver : @host.HostRuntimeDriver
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn backend_info() -> WinitWebWasmBackendInfo {
  let adapter = @wgpu_web.adapter_info()
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::WebWasm,
      description="canonical Milky2018/window web host on wasm-gc",
    ),
    uses_window_web_backend: true,
    has_wgpu_wasm_renderer: adapter.renderer.status ==
    @render.RendererCapabilityStatus::Ready,
    keeps_js_webgpu_fallback: true,
    renderer_info: adapter.renderer,
    surface_contract: adapter.surface_contract,
    description: "Canonical wasm host path: window/web owns canvas events on wasm-gc; browser WebGPU rendering stays behind render/wgpu_web until JS FFI or WIT bindings are ready.",
  }
}

///|
pub fn renderer_backend_info() -> @render.RendererBackendInfo {
  @wgpu_web.backend_info()
}

///|
pub fn wasm_renderer_ready() -> Bool {
  @wgpu_web.adapter_contract_ready()
}

///|
pub fn canvas_surface_contract() -> @render.WgpuSurfaceContract {
  @wgpu_web.canvas_surface_contract()
}

///|
pub fn run_counter_demo(title : String, runtime : @backend.AppRuntime) -> Unit {
  let event_loop = @web.EventLoop::new()
  event_loop.set_control_flow(@window_core.ControlFlow::Poll)
  let app = WinitWebWasmApp::{
    title,
    window: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.spawn_app(app)
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  window_event_to_host_with_modifiers(
    event,
    last_pointer,
    @core.KeyModifiers::none(),
  )
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @host.HostEvent? {
  match event {
    @window_core.WindowEvent::SurfaceResized(size) =>
      Some(
        @host.HostEvent::Resized(
          @host.HostSurfaceMetrics::new(
            logical_size=physical_size_to_core(size),
            physical_size=physical_size_to_core(size),
          ),
        ),
      )
    @window_core.WindowEvent::ScaleFactorChanged(scale, writer) =>
      Some(
        @host.HostEvent::Resized(
          @host.HostSurfaceMetrics::new(
            logical_size=physical_size_to_core(writer.surface_size()),
            physical_size=physical_size_to_core(writer.surface_size()),
            scale_factor=scale,
          ),
        ),
      )
    @window_core.WindowEvent::PointerMoved(_, position, _, _) =>
      Some(@host.HostEvent::PointerMoved(physical_position_to_core(position)))
    @window_core.WindowEvent::PointerButton(_, state, position, _, source) =>
      match source.mouse_button() {
        Some(@window_core.MouseButton::Left) =>
          Some(
            @host.HostEvent::PointerButton(
              physical_position_to_core(position),
              element_state_to_pointer_phase(state),
              0,
            ),
          )
        _ =>
          Some(
            @host.HostEvent::PointerButton(
              last_pointer,
              @core.PointerPhase::Cancel,
              0,
            ),
          )
      }
    @window_core.WindowEvent::CloseRequested =>
      Some(@host.HostEvent::CloseRequested)
    @window_core.WindowEvent::RedrawRequested =>
      Some(@host.HostEvent::RedrawRequested)
    @window_core.WindowEvent::KeyboardInput(_, key_event, is_synthetic) =>
      if is_synthetic {
        None
      } else {
        Some(
          @host.HostEvent::Keyboard(
            keyboard_event_to_core(key_event, modifiers),
          ),
        )
      }
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit(text)) =>
      Some(@host.HostEvent::TextInput(text))
    @window_core.WindowEvent::Focused(focused) =>
      if focused {
        None
      } else {
        Some(
          @host.HostEvent::PointerButton(
            last_pointer,
            @core.PointerPhase::Cancel,
            0,
          ),
        )
      }
    _ => None
  }
}

///|
pub impl @web.ApplicationHandler for WinitWebWasmApp with can_create_surfaces(
  self,
  event_loop,
) {
  let initial_size = @dpi.PhysicalSize::new(
    size_dim_to_int(self.runtime.size().width),
    size_dim_to_int(self.runtime.size().height),
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(initial_size.into_size())
  let window : @web.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("error creating Web/Wasm window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let size = physical_size_to_core(window.surface_size())
      ignore(
        self.driver.dispatch(
          @host.HostEvent::Resized(
            @host.HostSurfaceMetrics::new(
              logical_size=size,
              physical_size=size,
              scale_factor=window.scale_factor(),
            ),
          ),
        ),
      )
      self.window = Some(window)
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @web.ApplicationHandler for WinitWebWasmApp with window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(event)
      match self.window {
        Some(window) => window.drop()
        None => ()
      }
      self.window = None
      event_loop.exit()
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = physical_position_to_core(position)
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = physical_position_to_core(position)
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = modifiers_to_core(modifiers)
    @window_core.WindowEvent::RedrawRequested => {
      self.driver.begin_redraw()
      self.driver.finish_redraw()
    }
    _ => self.dispatch_window_event(event)
  }
}

///|
fn WinitWebWasmApp::dispatch_window_event(
  self : WinitWebWasmApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
    ) {
    Some(host_event) => ignore(self.driver.dispatch(host_event))
    None => ()
  }
}

///|
fn WinitWebWasmApp::request_redraw(self : WinitWebWasmApp) -> Unit {
  if self.runtime.needs_redraw() {
    match self.window {
      Some(window) => window.request_redraw()
      None => ()
    }
  }
}

///|
fn physical_size_to_core(size : @dpi.PhysicalSize) -> @core.Size {
  @core.Size::new(
    width=size.width().to_double(),
    height=size.height().to_double(),
  )
}

///|
fn physical_position_to_core(
  position : @dpi.PhysicalPositionF64,
) -> @core.Point {
  @core.Point::new(x=position.x(), y=position.y())
}

///|
fn element_state_to_pointer_phase(
  state : @window_core.ElementState,
) -> @core.PointerPhase {
  match state {
    @window_core.ElementState::Pressed => @core.PointerPhase::Down
    @window_core.ElementState::Released => @core.PointerPhase::Up
  }
}

///|
fn element_state_pressed(state : @window_core.ElementState) -> Bool {
  match state {
    @window_core.ElementState::Pressed => true
    @window_core.ElementState::Released => false
  }
}

///|
fn keyboard_event_to_core(
  event : @window_core.KeyEvent,
  modifiers : @core.KeyModifiers,
) -> @core.KeyboardEvent {
  @core.KeyboardEvent::new(
    key=key_event_name(event),
    text=key_event_text(event),
    pressed=element_state_pressed(event.state()),
    repeat=event.repeat(),
    modifiers~,
  )
}

///|
fn key_event_text(event : @window_core.KeyEvent) -> String? {
  match event.text() {
    Some(text) => if text == "" { None } else { Some(text) }
    None => None
  }
}

///|
fn key_event_name(event : @window_core.KeyEvent) -> String {
  match event.logical_key() {
    @window_core.Key::Character(text) => text
    @window_core.Key::Named(named) => named_key_name(named)
    @window_core.Key::Dead(_) => "Dead"
    @window_core.Key::Unidentified(_) => "Unidentified"
  }
}

///|
fn named_key_name(key : @window_core.NamedKey) -> String {
  match key {
    @window_core.NamedKey::Enter => "Enter"
    @window_core.NamedKey::Tab => "Tab"
    @window_core.NamedKey::Backspace => "Backspace"
    @window_core.NamedKey::Escape => "Escape"
    @window_core.NamedKey::Delete => "Delete"
    @window_core.NamedKey::ArrowLeft => "ArrowLeft"
    @window_core.NamedKey::ArrowRight => "ArrowRight"
    @window_core.NamedKey::ArrowUp => "ArrowUp"
    @window_core.NamedKey::ArrowDown => "ArrowDown"
    _ => "\{key}"
  }
}

///|
fn modifiers_to_core(modifiers : @window_core.Modifiers) -> @core.KeyModifiers {
  @core.KeyModifiers::new(
    shift=modifiers.shift_key(),
    control=modifiers.control_key(),
    alt=modifiers.alt_key(),
    meta=modifiers.meta_key(),
  )
}

///|
fn size_dim_to_int(value : Double) -> Int {
  if value < 1.0 {
    1
  } else {
    value.to_int()
  }
}

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @web.web_dispatch_event_by_id(kind, raw_id, arg0, arg1, argd, text_id)
}
