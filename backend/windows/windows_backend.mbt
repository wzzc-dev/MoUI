///|
struct WindowsApp {
  title : String
  mut window : @win.Window?
  mut renderer : @native_wgpu.RendererHandle?
  runtime : @backend.AppRuntime
  mut last_pointer : @core.Point
}

///|
pub fn run_counter_demo(title : String, runtime : @backend.AppRuntime) -> Unit {
  let event_loop = @win.EventLoop::new()
  event_loop.run_app(WindowsApp::{
    title,
    window: None,
    renderer: None,
    runtime,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
  })
}

///|
pub fn window_event_to_core(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @core.AppEvent? {
  match event {
    @window_core.WindowEvent::SurfaceResized(size) =>
      Some(@core.AppEvent::Resize(physical_size_to_core(size)))
    @window_core.WindowEvent::PointerMoved(_, position, _, _) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(
            position=physical_position_to_core(position),
            phase=@core.PointerPhase::Move,
          ),
        ),
      )
    @window_core.WindowEvent::PointerButton(_, state, position, _, source) =>
      match source.mouse_button() {
        Some(@window_core.MouseButton::Left) =>
          Some(
            @core.AppEvent::Pointer(
              @core.PointerEvent::new(
                position=physical_position_to_core(position),
                phase=element_state_to_pointer_phase(state),
              ),
            ),
          )
        _ =>
          Some(
            @core.AppEvent::Pointer(
              @core.PointerEvent::new(
                position=last_pointer,
                phase=@core.PointerPhase::Cancel,
              ),
            ),
          )
      }
    @window_core.WindowEvent::CloseRequested =>
      Some(@core.AppEvent::CloseRequested)
    @window_core.WindowEvent::RedrawRequested =>
      Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    _ => None
  }
}

///|
pub impl @win.ApplicationHandler for WindowsApp with can_create_surfaces(
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
  let window : @win.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("error creating Windows window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let size = physical_size_to_core(window.surface_size())
      self.runtime.dispatch_event(@core.AppEvent::Resize(size))
      let renderer : @native_wgpu.RendererHandle? = Some(
        @native_wgpu.RendererHandle::create_for_windows_hwnd(
          size,
          window.window_handle(),
        ),
      ) catch {
        _ => {
          println("error creating Windows WGPU renderer")
          event_loop.exit()
          None
        }
      }
      self.renderer = renderer
      self.window = Some(window)
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @win.ApplicationHandler for WindowsApp with window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispose()
      event_loop.exit()
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(event)
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          renderer.resize(self.runtime.size())
          window.request_redraw()
        }
        _ => ()
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = physical_position_to_core(position)
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = physical_position_to_core(position)
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::RedrawRequested =>
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          window.pre_present_notify()
          renderer.render(self.runtime.draw_commands())
          self.runtime.dispatch_event(
            @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
          )
        }
        _ => ()
      }
    _ => self.dispatch_window_event(event)
  }
}

///|
fn WindowsApp::dispatch_window_event(
  self : WindowsApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match window_event_to_core(event, self.last_pointer) {
    Some(core_event) => self.runtime.dispatch_event(core_event)
    None => ()
  }
}

///|
fn WindowsApp::request_redraw(self : WindowsApp) -> Unit {
  if self.runtime.needs_redraw() {
    match self.window {
      Some(window) => window.request_redraw()
      None => ()
    }
  }
}

///|
fn WindowsApp::dispose(self : WindowsApp) -> Unit {
  match self.renderer {
    Some(renderer) => renderer.dispose()
    None => ()
  }
  match self.window {
    Some(window) => window.drop()
    None => ()
  }
  self.renderer = None
  self.window = None
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
fn size_dim_to_int(value : Double) -> Int {
  if value < 1.0 {
    1
  } else {
    value.to_int()
  }
}
