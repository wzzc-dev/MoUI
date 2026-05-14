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
  renderer : @webgpu.WebGpuRenderer
  mut redraw_requested : Bool
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
  let app = { runtime, renderer, redraw_requested: false, redraw_count: 0 }
  runtime.set_redraw_callback(() => app.request_redraw())
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
  )
}

///|
pub fn WebApp::resize(
  self : WebApp,
  width : Double,
  height : Double,
) -> WebEventResult {
  self.renderer.resize(@core.Size::new(width~, height~))
  self.runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width~, height~)),
  )
  self.request_redraw()
  event_result(self)
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
  self.runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase~,
        button~,
      ),
    ),
  )
  if self.runtime.needs_redraw() {
    self.request_redraw()
  }
  event_result(self)
}

///|
fn WebApp::request_redraw(self : WebApp) -> Unit {
  if !self.redraw_requested {
    self.redraw_requested = true
    request_animation_frame(() => self.render_now())
  }
}

///|
fn WebApp::render_now(self : WebApp) -> Unit {
  self.redraw_requested = false
  self.renderer.render(self.runtime.draw_commands(), self.runtime.size())
  self.runtime.dispatch_event(
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit),
  )
  self.redraw_count = self.redraw_count + 1
}

///|
fn event_result(app : WebApp) -> WebEventResult {
  {
    needs_rebuild: app.runtime.needs_rebuild(),
    needs_redraw: app.runtime.needs_redraw(),
    redraw_requested: app.redraw_requested,
  }
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
) -> Unit =
  #|(context, onResize, onPointerMove, onPointerDown, onPointerUp, onPointerCancel) => {
  #|  const canvas = context.canvas;
  #|  if (!canvas) return;
  #|  const point = (event) => {
  #|    const rect = canvas.getBoundingClientRect();
  #|    return [event.clientX - rect.left, event.clientY - rect.top];
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
  #|    canvas.setPointerCapture?.(event.pointerId);
  #|    const [x, y] = point(event);
  #|    onPointerDown(x, y, event.button ?? 0);
  #|  });
  #|  canvas.addEventListener("pointerup", (event) => {
  #|    const [x, y] = point(event);
  #|    onPointerUp(x, y, event.button ?? 0);
  #|  });
  #|  canvas.addEventListener("pointercancel", () => onPointerCancel());
  #|}
