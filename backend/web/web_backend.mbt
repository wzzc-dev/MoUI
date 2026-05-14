///|
pub(all) struct WebBackendInfo {
  uses_dom_events : Bool
  uses_webgpu_surface : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
#external
pub type WebBootContext

///|
pub(all) struct WebApp {
  runtime : @backend.AppRuntime
  driver : @host.HostRuntimeDriver
  renderer : @webgpu.WebGpuRenderer
  mut redraw_count : Int
}

///|
pub(all) struct WebEventResult {
  needs_rebuild : Bool
  needs_redraw : Bool
  redraw_requested : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn default_web_backend_info() -> WebBackendInfo {
  {
    uses_dom_events: true,
    uses_webgpu_surface: true,
    description: "Reserved Web backend boundary for DOM events and WebGPU renderer",
  }
}

///|
pub fn runtime_for_canvas(
  root~ : @core.ViewNode,
  width~ : Double,
  height~ : Double,
) -> @backend.AppRuntime {
  @backend.AppRuntime::new(root~, size=@core.Size::new(width~, height~))
}

///|
pub fn component_runtime_for_canvas(
  root~ : @core.Component,
  width~ : Double,
  height~ : Double,
) -> @backend.AppRuntime {
  @backend.AppRuntime::new_component(
    root~,
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn WebBootContext::renderer(
  self : WebBootContext,
) -> @webgpu.WebGpuRenderer {
  boot_context_renderer(self)
}

///|
pub fn WebBootContext::width(self : WebBootContext) -> Double {
  boot_context_width(self)
}

///|
pub fn WebBootContext::height(self : WebBootContext) -> Double {
  boot_context_height(self)
}

///|
pub fn WebApp::new(
  runtime~ : @backend.AppRuntime,
  renderer~ : @webgpu.WebGpuRenderer,
) -> WebApp {
  let app = {
    runtime,
    driver: @host.HostRuntimeDriver::new(
      runtime~,
      schedule_redraw=() => (),
    ),
    renderer,
    redraw_count: 0,
  }
  app.driver.set_redraw_scheduler(() => app.schedule_redraw())
  app
}

///|
pub fn WebApp::start(self : WebApp) -> Unit {
  self.render_now()
}

///|
pub fn WebApp::attach_dom_events(
  self : WebApp,
  context : WebBootContext,
) -> Unit {
  bind_dom_events(
    context,
    () => ignore(self.resize(context.width(), context.height())),
    (x, y) => ignore(self.pointer_move(x, y)),
    (x, y, button) => ignore(self.pointer_down(x, y, button~)),
    (x, y, button) => ignore(self.pointer_up(x, y, button~)),
    () => ignore(self.pointer_cancel()),
    (key, text, pressed, repeat, shift, control, alt, meta) =>
      ignore(
        self.keyboard(
          key,
          text~,
          pressed~,
          repeat~,
          modifiers=@core.KeyModifiers::new(shift~, control~, alt~, meta~),
        ),
      ),
  )
}

///|
pub fn WebApp::resize(
  self : WebApp,
  width : Double,
  height : Double,
) -> WebEventResult {
  self.renderer.resize(@core.Size::new(width~, height~))
  let result = self.driver.dispatch(
    @host.HostEvent::Resized(
      @host.HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width~, height~),
      ),
    ),
  )
  web_event_result(result)
}

///|
pub fn WebApp::pointer_move(
  self : WebApp,
  x : Double,
  y : Double,
) -> WebEventResult {
  self.dispatch_pointer(x, y, @core.PointerPhase::Move, button=0)
}

///|
pub fn WebApp::pointer_down(
  self : WebApp,
  x : Double,
  y : Double,
  button? : Int = 0,
) -> WebEventResult {
  self.dispatch_pointer(x, y, @core.PointerPhase::Down, button~)
}

///|
pub fn WebApp::pointer_up(
  self : WebApp,
  x : Double,
  y : Double,
  button? : Int = 0,
) -> WebEventResult {
  self.dispatch_pointer(x, y, @core.PointerPhase::Up, button~)
}

///|
pub fn WebApp::pointer_cancel(self : WebApp) -> WebEventResult {
  self.dispatch_pointer(-1.0, -1.0, @core.PointerPhase::Cancel, button=0)
}

///|
pub fn WebApp::keyboard(
  self : WebApp,
  key : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> WebEventResult {
  let result = self.driver.dispatch(
    @host.HostEvent::Keyboard(
      @core.KeyboardEvent::new(
        key~,
        text~,
        pressed~,
        repeat~,
        modifiers~,
      ),
    ),
  )
  web_event_result(result)
}

///|
pub fn WebApp::redraw(self : WebApp) -> Unit {
  self.render_now()
}

///|
pub fn WebApp::dispose(self : WebApp) -> Unit {
  self.renderer.dispose()
}

///|
fn WebApp::dispatch_pointer(
  self : WebApp,
  x : Double,
  y : Double,
  phase : @core.PointerPhase,
  button~ : Int,
) -> WebEventResult {
  let position = @core.Point::new(x~, y~)
  let result = match phase {
    @core.PointerPhase::Move =>
      self.driver.dispatch(@host.HostEvent::PointerMoved(position))
    _ =>
      self.driver.dispatch(
        @host.HostEvent::PointerButton(position, phase, button),
      )
  }
  web_event_result(result)
}

///|
fn WebApp::schedule_redraw(self : WebApp) -> Unit {
  request_animation_frame(() => self.render_now())
}

///|
fn WebApp::render_now(self : WebApp) -> Unit {
  self.driver.begin_redraw()
  self.renderer.render(self.driver.draw_commands(), self.driver.size())
  self.driver.finish_redraw()
  self.redraw_count = self.redraw_count + 1
}

///|
fn web_event_result(result : @host.HostEventResult) -> WebEventResult {
  {
    needs_rebuild: result.needs_rebuild,
    needs_redraw: result.needs_redraw,
    redraw_requested: result.redraw_requested,
  }
}

///|
pub fn WebApp::host_dispatch(
  self : WebApp,
  event : @host.HostEvent,
) -> WebEventResult {
  web_event_result(self.driver.dispatch(event))
}

///|
pub fn WebApp::text_input(
  self : WebApp,
  text : String,
) -> WebEventResult {
  web_event_result(self.driver.dispatch(@host.HostEvent::TextInput(text)))
}

///|
pub fn WebApp::surface_metrics(
  self : WebApp,
) -> @host.HostSurfaceMetrics {
  @host.HostSurfaceMetrics::from_logical(size=self.runtime.size())
}

///|
pub fn WebApp::driver(self : WebApp) -> @host.HostRuntimeDriver {
  self.driver
}

///|
pub fn web_keyboard_event(
  key~ : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> @host.HostEvent {
  @host.HostEvent::Keyboard(
    @core.KeyboardEvent::new(
      key~,
      text~,
      pressed~,
      repeat~,
      modifiers~,
    ),
  )
}

///|
extern "js" fn request_animation_frame(callback : () -> Unit) -> Unit =
  #|(callback) => {
  #|  const raf = globalThis.requestAnimationFrame ?? ((cb) => setTimeout(cb, 16));
  #|  raf(() => callback());
  #|}

///|
extern "js" fn boot_context_renderer(
  context : WebBootContext,
) -> @webgpu.WebGpuRenderer =
  #|(context) => context.renderer

///|
extern "js" fn boot_context_width(context : WebBootContext) -> Double =
  #|(context) => {
  #|  if (typeof context.width === "function") return context.width();
  #|  return context.canvas?.clientWidth ?? context.canvas?.width ?? 0;
  #|}

///|
extern "js" fn boot_context_height(context : WebBootContext) -> Double =
  #|(context) => {
  #|  if (typeof context.height === "function") return context.height();
  #|  return context.canvas?.clientHeight ?? context.canvas?.height ?? 0;
  #|}

///|
extern "js" fn bind_dom_events(
  context : WebBootContext,
  on_resize : () -> Unit,
  on_pointer_move : (Double, Double) -> Unit,
  on_pointer_down : (Double, Double, Int) -> Unit,
  on_pointer_up : (Double, Double, Int) -> Unit,
  on_pointer_cancel : () -> Unit,
  on_keyboard : (
    String,
    String?,
    Bool,
    Bool,
    Bool,
    Bool,
    Bool,
    Bool
  ) -> Unit,
) -> Unit =
  #|(context, onResize, onPointerMove, onPointerDown, onPointerUp, onPointerCancel, onKeyboard) => {
  #|  const canvas = context.canvas;
  #|  if (!canvas) return;
  #|  if (!canvas.hasAttribute("tabindex")) canvas.tabIndex = 0;
  #|  const point = (event) => {
  #|    const rect = canvas.getBoundingClientRect();
  #|    return [event.clientX - rect.left, event.clientY - rect.top];
  #|  };
  #|  const textForKeyEvent = (event) => {
  #|    if (event.ctrlKey || event.metaKey || event.altKey) return undefined;
  #|    return event.key && event.key.length === 1 ? event.key : undefined;
  #|  };
  #|  const emitKeyboard = (event, pressed) => {
  #|    const text = pressed ? textForKeyEvent(event) : undefined;
  #|    onKeyboard(
  #|      event.key ?? "",
  #|      text,
  #|      pressed,
  #|      event.repeat === true,
  #|      event.shiftKey === true,
  #|      event.ctrlKey === true,
  #|      event.altKey === true,
  #|      event.metaKey === true,
  #|    );
  #|    if (pressed && (text !== undefined || event.key === "Backspace" || event.key === "Enter" || event.key === "Tab")) {
  #|      event.preventDefault();
  #|    }
  #|  };
  #|  const resize = () => onResize();
  #|  globalThis.addEventListener?.("resize", resize);
  #|  if (globalThis.ResizeObserver) {
  #|    const observer = new ResizeObserver(resize);
  #|    observer.observe(canvas);
  #|    context.resizeObserver = observer;
  #|  }
  #|  canvas.addEventListener("pointermove", (event) => {
  #|    const [x, y] = point(event);
  #|    onPointerMove(x, y);
  #|  });
  #|  canvas.addEventListener("pointerdown", (event) => {
  #|    canvas.focus?.();
  #|    canvas.setPointerCapture?.(event.pointerId);
  #|    const [x, y] = point(event);
  #|    onPointerDown(x, y, event.button ?? 0);
  #|  });
  #|  canvas.addEventListener("pointerup", (event) => {
  #|    const [x, y] = point(event);
  #|    onPointerUp(x, y, event.button ?? 0);
  #|  });
  #|  canvas.addEventListener("pointercancel", () => onPointerCancel());
  #|  canvas.addEventListener("keydown", (event) => emitKeyboard(event, true));
  #|  canvas.addEventListener("keyup", (event) => emitKeyboard(event, false));
  #|}
