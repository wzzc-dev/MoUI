///|
#external
pub type WebGpuRenderer

///|
pub(all) struct RenderBridgeTrace {
  mut calls : Array[String]
} derive(Debug, ToJson)

///|
pub fn RenderBridgeTrace::new() -> RenderBridgeTrace {
  { calls: [] }
}

///|
pub fn RenderBridgeTrace::push(self : RenderBridgeTrace, call : String) -> Unit {
  self.calls.push(call)
}

///|
pub fn WebGpuRenderer::resize(self : WebGpuRenderer, size : @core.Size) -> Unit {
  js_webgpu_resize(self, size.width, size.height)
}

///|
pub fn WebGpuRenderer::render(
  self : WebGpuRenderer,
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> Unit {
  render_commands(self, commands, size, None)
}

///|
pub fn WebGpuRenderer::dispose(self : WebGpuRenderer) -> Unit {
  js_webgpu_dispose(self)
}

///|
pub fn render_commands_for_test(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> RenderBridgeTrace {
  let trace = RenderBridgeTrace::new()
  render_commands(stub_renderer(), commands, size, Some(trace))
  trace
}

///|
fn render_commands(
  renderer : WebGpuRenderer,
  commands : Array[@core.DrawCommand],
  size : @core.Size,
  trace : RenderBridgeTrace?,
) -> Unit {
  js_webgpu_begin(renderer, size.width, size.height)
  trace_call(trace, "begin")
  for command in commands {
    match command {
      @core.DrawCommand::Clear(color) => {
        js_webgpu_clear(renderer, color.r, color.g, color.b, color.a)
        trace_call(trace, "clear")
      }
      @core.DrawCommand::FillRect(rect, color) => {
        js_webgpu_fill_rect(
          renderer,
          rect.origin.x,
          rect.origin.y,
          rect.size.width,
          rect.size.height,
          color.r,
          color.g,
          color.b,
          color.a,
        )
        trace_call(trace, "rect")
      }
      @core.DrawCommand::DrawText(run) => {
        js_webgpu_draw_text(
          renderer,
          run.text,
          run.frame.origin.x,
          run.frame.origin.y,
          run.frame.size.width,
          run.frame.size.height,
          run.font.family,
          run.font.size,
          run.font.weight,
          run.color.r,
          run.color.g,
          run.color.b,
          run.color.a,
        )
        trace_call(trace, "text")
      }
      @core.DrawCommand::PushClip(rect) => {
        js_webgpu_push_clip(
          renderer,
          rect.origin.x,
          rect.origin.y,
          rect.size.width,
          rect.size.height,
        )
        trace_call(trace, "push_clip")
      }
      @core.DrawCommand::PopClip => {
        js_webgpu_pop_clip(renderer)
        trace_call(trace, "pop_clip")
      }
    }
  }
  js_webgpu_present(renderer)
  trace_call(trace, "present")
}

///|
fn trace_call(trace : RenderBridgeTrace?, call : String) -> Unit {
  match trace {
    Some(trace) => trace.push(call)
    None => ()
  }
}

///|
extern "js" fn stub_renderer() -> WebGpuRenderer =
  #|() => globalThis.__mouiWebGpuStubRenderer ?? {}

///|
extern "js" fn js_webgpu_resize(
  renderer : WebGpuRenderer,
  width : Double,
  height : Double,
) -> Unit =
  #|(renderer, width, height) => {
  #|  renderer?.resize?.(width, height);
  #|}

///|
extern "js" fn js_webgpu_begin(
  renderer : WebGpuRenderer,
  width : Double,
  height : Double,
) -> Unit =
  #|(renderer, width, height) => {
  #|  renderer?.begin?.(width, height);
  #|}

///|
extern "js" fn js_webgpu_clear(
  renderer : WebGpuRenderer,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit =
  #|(renderer, r, g, b, a) => {
  #|  renderer?.clear?.(r, g, b, a);
  #|}

///|
extern "js" fn js_webgpu_fill_rect(
  renderer : WebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit =
  #|(renderer, x, y, width, height, r, g, b, a) => {
  #|  renderer?.fillRect?.(x, y, width, height, r, g, b, a);
  #|}

///|
extern "js" fn js_webgpu_draw_text(
  renderer : WebGpuRenderer,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  family : String,
  size : Double,
  weight : Int,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit =
  #|(renderer, text, x, y, width, height, family, size, weight, r, g, b, a) => {
  #|  renderer?.drawText?.(text, x, y, width, height, family, size, weight, r, g, b, a);
  #|}

///|
extern "js" fn js_webgpu_push_clip(
  renderer : WebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit =
  #|(renderer, x, y, width, height) => {
  #|  renderer?.pushClip?.(x, y, width, height);
  #|}

///|
extern "js" fn js_webgpu_pop_clip(renderer : WebGpuRenderer) -> Unit =
  #|(renderer) => {
  #|  renderer?.popClip?.();
  #|}

///|
extern "js" fn js_webgpu_present(renderer : WebGpuRenderer) -> Unit =
  #|(renderer) => {
  #|  renderer?.present?.();
  #|}

///|
extern "js" fn js_webgpu_dispose(renderer : WebGpuRenderer) -> Unit =
  #|(renderer) => {
  #|  renderer?.dispose?.();
  #|}
