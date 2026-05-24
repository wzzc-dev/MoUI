///|
type HostWebGpuSurface = Int

///|
type HostWebGpuRenderer = Int

///|
type HostWebGpuString = Int

///|
pub(all) suberror WebGpuHostError {
  Unavailable
  AdapterUnavailable
  DeviceUnavailable
  SurfaceUnavailable
  PipelineUnavailable
  InvalidResource
  HostError(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostCapabilities {
  webgpu_available : Bool
  adapter_ready : Bool
  can_render : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostImportInfo {
  import_module : String
  target : String
  surface_resource : String
  renderer_resource : String
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostAdapterInfo {
  renderer : @render.RendererBackendInfo
  surface_contract : @render.WgpuSurfaceContract
  imports : WebGpuHostImportInfo
  capabilities : WebGpuHostCapabilities
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebGpuHostCall {
  BeginFrame(@core.Size)
  Clear(@core.Color)
  FillRect(@core.Rect, @core.Color)
  StrokeRect(@core.Rect, @core.Color, Double)
  FillRoundedRect(@core.RoundedRect, @core.Color)
  StrokeRoundedRect(@core.RoundedRect, @core.Color, Double)
  FillRoundedRectBrush(@core.RoundedRect, @core.Brush)
  StrokeRoundedRectBrush(@core.RoundedRect, @core.Brush, Double)
  DrawShadow(@core.ShadowSpec)
  DrawText(@core.TextRun)
  DrawImage(@core.ImageRun)
  PushClip(@core.Rect)
  PopClip
  PushRoundedClip(@core.RoundedRect)
  PopRoundedClip
  PushTransform(@core.Transform2D)
  PopTransform
  PushOpacity(Double)
  PopOpacity
  PushLayer(@core.LayerSpec)
  PopLayer
  PushFilter(@core.FilterEffect)
  PopFilter
  DrawShaderEffect(@core.ShaderEffectSpec)
  Present
} derive(Eq, Debug, ToJson)

///|
priv struct HostBrushPayload {
  start : @core.Point
  end : @core.Point
  start_color : @core.Color
  end_color : @core.Color
}

///|
pub(all) struct WebGpuHostSurface {
  canvas_id : String
  mut metrics : @render.RendererSurfaceMetrics
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostRendererPort {
  capabilities : () -> WebGpuHostCapabilities raise WebGpuHostError
  create_surface : (String, @render.RendererSurfaceMetrics) -> WebGpuHostSurface raise WebGpuHostError
  create_renderer : (WebGpuHostSurface) -> Unit raise WebGpuHostError
  resize : (@render.RendererSurfaceMetrics) -> Unit raise WebGpuHostError
  measure_text : (@core.TextLayoutInput) -> @core.TextLayoutResult
  register_font_data : (@core.FontFamily, Bytes) -> Unit
  submit : (Array[WebGpuHostCall]) -> Unit raise WebGpuHostError
  dispose : () -> Unit
}

///|
pub(all) struct WebGpuWasmRenderer {
  surface : WebGpuHostSurface
  port : WebGpuHostRendererPort
  mut size : @core.Size
  mut present_count : Int
  mut last_calls : Array[WebGpuHostCall]
  mut last_fallback_plan : @render.RendererCommandPlan
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    status=@render.RendererCapabilityStatus::Ready,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="Browser WebGPU renderer for MoonBit wasm-gc. It requires the `webgpu` host import module and has no JS-target fallback.",
  )
}

///|
pub fn host_import_info() -> WebGpuHostImportInfo {
  {
    import_module: "webgpu",
    target: "wasm-gc",
    surface_resource: "browser canvas WebGPU surface handle",
    renderer_resource: "browser WebGPU renderer handle",
    description: "MoonBit calls synchronous wasm-gc host imports; the browser loader must initialize navigator.gpu before instantiating the app.",
  }
}

///|
pub fn required_capabilities() -> WebGpuHostCapabilities {
  { webgpu_available: true, adapter_ready: true, can_render: true }
}

///|
pub fn canvas_surface_contract() -> @render.WgpuSurfaceContract {
  @render.WgpuSurfaceContract::new(
    source=@render.WgpuSurfaceSourceKind::WebCanvasSurface,
    backend=@render.RendererBackendKind::WebGpuWasm,
    ready=true,
    description="Canvas surface is supplied by window/web and configured by the wasm-gc `webgpu` host import module.",
  )
}

///|
pub fn adapter_info() -> WebGpuHostAdapterInfo {
  {
    renderer: backend_info(),
    surface_contract: canvas_surface_contract(),
    imports: host_import_info(),
    capabilities: required_capabilities(),
    description: "Web/Wasm uses a single wasm-gc path: window/web events plus browser WebGPU host imports. Missing host capabilities fail startup instead of falling back.",
  }
}

///|
pub fn create_webgpu_renderer(
  canvas_id~ : String,
  logical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> WebGpuWasmRenderer raise WebGpuHostError {
  create_renderer(
    canvas_id~,
    logical_size~,
    scale_factor~,
    port=wasm_gc_host_port(),
  )
}

///|
pub fn wasm_gc_host_port() -> WebGpuHostRendererPort {
  let surface_ref : Ref[HostWebGpuSurface?] = Ref(None)
  let renderer_ref : Ref[HostWebGpuRenderer?] = Ref(None)
  {
    capabilities: () => {
      webgpu_available: host_webgpu_available(),
      adapter_ready: host_adapter_ready(),
      can_render: host_can_render(),
    },
    create_surface: (canvas_id, metrics) => {
      let surface = host_create_surface(
        host_string(canvas_id),
        metrics.logical_size.width,
        metrics.logical_size.height,
        metrics.scale_factor,
      )
      if !host_surface_is_valid(surface) {
        raise WebGpuHostError::SurfaceUnavailable
      }
      surface_ref.val = Some(surface)
      { canvas_id, metrics }
    },
    create_renderer: _surface => {
      match surface_ref.val {
        Some(surface) => {
          let renderer = host_create_renderer(surface)
          if !host_renderer_is_valid(renderer) {
            raise WebGpuHostError::DeviceUnavailable
          }
          renderer_ref.val = Some(renderer)
        }
        None => raise WebGpuHostError::SurfaceUnavailable
      }
    },
    resize: metrics => {
      match (surface_ref.val, renderer_ref.val) {
        (Some(surface), Some(renderer)) => {
          raise_for_host_status(
            host_surface_resize(
              surface,
              metrics.logical_size.width,
              metrics.logical_size.height,
              metrics.scale_factor,
            ),
          )
          raise_for_host_status(
            host_renderer_resize(
              renderer,
              metrics.logical_size.width,
              metrics.logical_size.height,
              metrics.scale_factor,
            ),
          )
        }
        _ => raise WebGpuHostError::InvalidResource
      }
    },
    measure_text: input => host_measure_text_layout(input),
    register_font_data: (family, data) => {
      ignore(
        host_register_font_data(
          host_string(family.css_token()),
          host_string(@base64.encode(data[:])),
        ),
      )
    },
    submit: calls => {
      match renderer_ref.val {
        Some(renderer) => submit_host_calls(renderer, calls)
        None => raise WebGpuHostError::InvalidResource
      }
    },
    dispose: () => {
      match renderer_ref.val {
        Some(renderer) => host_renderer_dispose(renderer)
        None => ()
      }
      match surface_ref.val {
        Some(surface) => host_surface_dispose(surface)
        None => ()
      }
      renderer_ref.val = None
      surface_ref.val = None
    },
  }
}

///|
pub fn create_surface(
  canvas_id~ : String,
  logical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
  port~ : WebGpuHostRendererPort,
) -> WebGpuHostSurface raise WebGpuHostError {
  let metrics = @render.RendererSurfaceMetrics::from_logical(
    size=logical_size,
    scale_factor~,
  )
  (port.create_surface)(canvas_id, metrics)
}

///|
pub fn create_renderer(
  canvas_id~ : String,
  logical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
  port~ : WebGpuHostRendererPort,
) -> WebGpuWasmRenderer raise WebGpuHostError {
  let capabilities = (port.capabilities)()
  ensure_required_capabilities(capabilities)
  let surface = create_surface(canvas_id~, logical_size~, scale_factor~, port~)
  (port.create_renderer)(surface)
  {
    surface,
    port,
    size: logical_size,
    present_count: 0,
    last_calls: [],
    last_fallback_plan: @render.plan_renderer_command_fallbacks([]),
  }
}

///|
pub fn WebGpuWasmRenderer::backend_kind(
  self : WebGpuWasmRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  @render.RendererBackendKind::WebGpuWasm
}

///|
pub fn WebGpuWasmRenderer::backend_info(
  self : WebGpuWasmRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn WebGpuWasmRenderer::resize(
  self : WebGpuWasmRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise WebGpuHostError {
  (self.port.resize)(metrics)
  self.surface.metrics = metrics
  self.size = metrics.logical_size
}

///|
pub fn WebGpuWasmRenderer::render(
  self : WebGpuWasmRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise WebGpuHostError {
  self.last_fallback_plan = @render.plan_renderer_command_fallbacks(commands)
  let calls = draw_commands_to_host_calls(commands, self.size)
  (self.port.submit)(calls)
  self.last_calls = calls
  self.present_count = self.present_count + 1
}

///|
pub fn WebGpuWasmRenderer::text_system(
  self : WebGpuWasmRenderer,
) -> @core.TextSystem {
  @core.TextSystem::new(
    id="webgpu-wasm-host",
    measure=input => (self.port.measure_text)(input),
    register_font_data=(family, data) => {
      (self.port.register_font_data)(family, data)
    },
  )
}

///|
pub fn WebGpuWasmRenderer::dispose(self : WebGpuWasmRenderer) -> Unit {
  (self.port.dispose)()
}

///|
pub fn WebGpuWasmRenderer::present_count(self : WebGpuWasmRenderer) -> Int {
  self.present_count
}

///|
pub fn WebGpuWasmRenderer::last_calls(
  self : WebGpuWasmRenderer,
) -> Array[WebGpuHostCall] {
  self.last_calls
}

///|
pub fn WebGpuWasmRenderer::last_fallback_plan(
  self : WebGpuWasmRenderer,
) -> @render.RendererCommandPlan {
  self.last_fallback_plan
}

///|
pub fn draw_commands_to_host_calls(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> Array[WebGpuHostCall] {
  let calls : Array[WebGpuHostCall] = [WebGpuHostCall::BeginFrame(size)]
  for command in commands {
    match command {
      @core.DrawCommand::Clear(color) =>
        calls.push(WebGpuHostCall::Clear(color))
      @core.DrawCommand::FillRect(rect, color) =>
        calls.push(WebGpuHostCall::FillRect(rect, color))
      @core.DrawCommand::StrokeRect(rect, color, width) =>
        calls.push(WebGpuHostCall::StrokeRect(rect, color, width))
      @core.DrawCommand::FillRoundedRect(rect, color) =>
        calls.push(WebGpuHostCall::FillRoundedRect(rect, color))
      @core.DrawCommand::StrokeRoundedRect(rect, color, width) =>
        calls.push(WebGpuHostCall::StrokeRoundedRect(rect, color, width))
      @core.DrawCommand::FillRoundedRectBrush(rect, brush) =>
        calls.push(WebGpuHostCall::FillRoundedRectBrush(rect, brush))
      @core.DrawCommand::StrokeRoundedRectBrush(rect, brush, width) =>
        calls.push(WebGpuHostCall::StrokeRoundedRectBrush(rect, brush, width))
      @core.DrawCommand::DrawShadow(shadow) =>
        calls.push(WebGpuHostCall::DrawShadow(shadow))
      @core.DrawCommand::DrawText(run) =>
        calls.push(WebGpuHostCall::DrawText(run))
      @core.DrawCommand::DrawImage(run) =>
        calls.push(WebGpuHostCall::DrawImage(run))
      @core.DrawCommand::PushClip(rect) =>
        calls.push(WebGpuHostCall::PushClip(rect))
      @core.DrawCommand::PopClip => calls.push(WebGpuHostCall::PopClip)
      @core.DrawCommand::PushRoundedClip(rect) =>
        calls.push(WebGpuHostCall::PushRoundedClip(rect))
      @core.DrawCommand::PopRoundedClip =>
        calls.push(WebGpuHostCall::PopRoundedClip)
      @core.DrawCommand::PushTransform(transform) =>
        calls.push(WebGpuHostCall::PushTransform(transform))
      @core.DrawCommand::PopTransform =>
        calls.push(WebGpuHostCall::PopTransform)
      @core.DrawCommand::PushOpacity(opacity) =>
        calls.push(WebGpuHostCall::PushOpacity(opacity))
      @core.DrawCommand::PopOpacity => calls.push(WebGpuHostCall::PopOpacity)
      @core.DrawCommand::PushLayer(layer) =>
        calls.push(WebGpuHostCall::PushLayer(layer))
      @core.DrawCommand::PopLayer => calls.push(WebGpuHostCall::PopLayer)
      @core.DrawCommand::PushFilter(filter) =>
        calls.push(WebGpuHostCall::PushFilter(filter))
      @core.DrawCommand::PopFilter => calls.push(WebGpuHostCall::PopFilter)
      @core.DrawCommand::DrawShaderEffect(spec) =>
        calls.push(WebGpuHostCall::DrawShaderEffect(spec))
      @core.DrawCommand::DrawPath(_) => ()
    }
  }
  calls.push(WebGpuHostCall::Present)
  calls
}

///|
fn ensure_required_capabilities(
  capabilities : WebGpuHostCapabilities,
) -> Unit raise WebGpuHostError {
  if !capabilities.webgpu_available {
    raise WebGpuHostError::Unavailable
  }
  if !capabilities.adapter_ready {
    raise WebGpuHostError::AdapterUnavailable
  }
  if !capabilities.can_render {
    raise WebGpuHostError::PipelineUnavailable
  }
}

///|
fn submit_host_calls(
  renderer : HostWebGpuRenderer,
  calls : Array[WebGpuHostCall],
) -> Unit raise WebGpuHostError {
  for call in calls {
    match call {
      BeginFrame(size) =>
        raise_for_host_status(
          host_begin_frame(renderer, size.width, size.height),
        )
      Clear(color) =>
        raise_for_host_status(
          host_clear(renderer, color.r, color.g, color.b, color.a),
        )
      FillRect(rect, color) =>
        raise_for_host_status(
          host_fill_rect(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            color.r,
            color.g,
            color.b,
            color.a,
          ),
        )
      StrokeRect(rect, color, width) =>
        raise_for_host_status(
          host_stroke_rect(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            color.r,
            color.g,
            color.b,
            color.a,
            width,
          ),
        )
      FillRoundedRect(rounded, color) =>
        raise_for_host_status(
          host_fill_rounded_rect(
            renderer,
            rounded.rect.origin.x,
            rounded.rect.origin.y,
            rounded.rect.size.width,
            rounded.rect.size.height,
            rounded.radius,
            color.r,
            color.g,
            color.b,
            color.a,
          ),
        )
      StrokeRoundedRect(rounded, color, width) =>
        raise_for_host_status(
          host_stroke_rounded_rect(
            renderer,
            rounded.rect.origin.x,
            rounded.rect.origin.y,
            rounded.rect.size.width,
            rounded.rect.size.height,
            rounded.radius,
            color.r,
            color.g,
            color.b,
            color.a,
            width,
          ),
        )
      FillRoundedRectBrush(rounded, brush) =>
        submit_fill_rounded_rect_brush(renderer, rounded, brush)
      StrokeRoundedRectBrush(rounded, brush, width) =>
        submit_stroke_rounded_rect_brush(renderer, rounded, brush, width)
      DrawShadow(shadow) =>
        raise_for_host_status(
          host_draw_shadow(
            renderer,
            shadow.rect.rect.origin.x,
            shadow.rect.rect.origin.y,
            shadow.rect.rect.size.width,
            shadow.rect.rect.size.height,
            shadow.rect.radius,
            shadow.offset.x,
            shadow.offset.y,
            shadow.blur_radius,
            shadow.spread,
            shadow.color.r,
            shadow.color.g,
            shadow.color.b,
            shadow.color.a,
          ),
        )
      DrawText(run) =>
        raise_for_host_status(
          host_draw_text(
            renderer,
            host_string(run.text),
            run.frame.origin.x,
            run.frame.origin.y,
            run.frame.size.width,
            run.frame.size.height,
            host_string(run.font.css_family()),
            host_string(run.font.css_style()),
            run.font.size,
            run.font.weight,
            run.color.r,
            run.color.g,
            run.color.b,
            run.color.a,
            text_align_host_code(run.align),
          ),
        )
      DrawImage(run) =>
        raise_for_host_status(
          host_draw_image(
            renderer,
            host_string(run.source),
            run.frame.origin.x,
            run.frame.origin.y,
            run.frame.size.width,
            run.frame.size.height,
            run.opacity,
            image_fit_host_code(run.fit),
          ),
        )
      PushClip(rect) =>
        raise_for_host_status(
          host_push_clip(
            renderer,
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
          ),
        )
      PopClip => raise_for_host_status(host_pop_clip(renderer))
      PushRoundedClip(_) => () // Temporarily no-op
      PopRoundedClip => () // Temporarily no-op
      PushTransform(transform) =>
        raise_for_host_status(
          host_push_transform(
            renderer,
            transform.a,
            transform.b,
            transform.c,
            transform.d,
            transform.tx,
            transform.ty,
          ),
        )
      PopTransform => raise_for_host_status(host_pop_transform(renderer))
      PushOpacity(opacity) =>
        raise_for_host_status(host_push_opacity(renderer, opacity))
      PopOpacity => raise_for_host_status(host_pop_opacity(renderer))
      PushLayer(layer) => submit_push_layer(renderer, layer)
      PopLayer => raise_for_host_status(host_pop_layer(renderer))
      PushFilter(filter) => submit_push_filter(renderer, filter)
      PopFilter => raise_for_host_status(host_pop_filter(renderer))
      DrawShaderEffect(spec) => submit_draw_shader_effect(renderer, spec)
      Present => raise_for_host_status(host_present(renderer))
    }
  }
}

///|
fn submit_push_layer(
  renderer : HostWebGpuRenderer,
  layer : @core.LayerSpec,
) -> Unit raise WebGpuHostError {
  let mask = layer_mask_payload(layer.mask)
  raise_for_host_status(
    host_push_layer(
      renderer,
      layer.opacity,
      blend_mode_host_code(layer.blend_mode),
      mask.kind,
      mask.rect.origin.x,
      mask.rect.origin.y,
      mask.rect.size.width,
      mask.rect.size.height,
      mask.radius,
      layer.offscreen,
    ),
  )
}

///|
fn submit_push_filter(
  renderer : HostWebGpuRenderer,
  filter : @core.FilterEffect,
) -> Unit raise WebGpuHostError {
  let payload = filter_effect_payload(filter)
  raise_for_host_status(
    host_push_filter(
      renderer,
      payload.kind,
      payload.amount,
      host_string(payload.matrix_values),
    ),
  )
}

///|
fn submit_draw_shader_effect(
  renderer : HostWebGpuRenderer,
  spec : @core.ShaderEffectSpec,
) -> Unit raise WebGpuHostError {
  let fallback = brush_payload(spec.fallback, spec.frame)
  raise_for_host_status(
    host_draw_shader_effect(
      renderer,
      host_string(spec.name),
      spec.frame.origin.x,
      spec.frame.origin.y,
      spec.frame.size.width,
      spec.frame.size.height,
      host_string(double_array_string(spec.uniforms)),
      fallback.start.x,
      fallback.start.y,
      fallback.end.x,
      fallback.end.y,
      fallback.start_color.r,
      fallback.start_color.g,
      fallback.start_color.b,
      fallback.start_color.a,
      fallback.end_color.r,
      fallback.end_color.g,
      fallback.end_color.b,
      fallback.end_color.a,
    ),
  )
}

///|
priv struct HostLayerMaskPayload {
  kind : Int
  rect : @core.Rect
  radius : Double
}

///|
fn layer_mask_payload(mask : @core.LayerMask) -> HostLayerMaskPayload {
  match mask {
    @core.LayerMask::NoMask =>
      {
        kind: 0,
        rect: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        radius: 0.0,
      }
    @core.LayerMask::RectMask(rect) => { kind: 1, rect, radius: 0.0 }
    @core.LayerMask::RoundedMask(rounded) =>
      { kind: 2, rect: rounded.rect, radius: rounded.radius }
  }
}

///|
priv struct HostFilterPayload {
  kind : Int
  amount : Double
  matrix_values : String
}

///|
fn filter_effect_payload(filter : @core.FilterEffect) -> HostFilterPayload {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      { kind: 0, amount: radius.max(0.0), matrix_values: "" }
    @core.FilterEffect::Saturate(amount) =>
      { kind: 1, amount, matrix_values: "" }
    @core.FilterEffect::Brightness(amount) =>
      { kind: 2, amount, matrix_values: "" }
    @core.FilterEffect::Contrast(amount) =>
      { kind: 3, amount, matrix_values: "" }
    @core.FilterEffect::ColorMatrix(values) =>
      { kind: 4, amount: 1.0, matrix_values: double_array_string(values) }
  }
}

///|
fn blend_mode_host_code(mode : @core.BlendMode) -> Int {
  match mode {
    @core.BlendMode::SourceOver => 0
    @core.BlendMode::Multiply => 1
    @core.BlendMode::Screen => 2
    @core.BlendMode::Overlay => 3
    @core.BlendMode::Darken => 4
    @core.BlendMode::Lighten => 5
  }
}

///|
fn brush_payload(brush : @core.Brush, frame : @core.Rect) -> HostBrushPayload {
  match brush {
    @core.Brush::Solid(color) =>
      {
        start: frame.origin,
        end: @core.Point::new(x=frame.origin.x + 1.0, y=frame.origin.y),
        start_color: color,
        end_color: color,
      }
    @core.Brush::LinearGradient(gradient) =>
      {
        start: gradient.start,
        end: gradient.end,
        start_color: gradient.start_color,
        end_color: gradient.end_color,
      }
  }
}

///|
fn double_array_string(values : Array[Double]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push(value.to_string())
  }
  parts.join(",")
}

///|
fn submit_fill_rounded_rect_brush(
  renderer : HostWebGpuRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
) -> Unit raise WebGpuHostError {
  match brush {
    @core.Brush::Solid(color) =>
      raise_for_host_status(
        host_fill_rounded_rect(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          color.r,
          color.g,
          color.b,
          color.a,
        ),
      )
    @core.Brush::LinearGradient(gradient) =>
      raise_for_host_status(
        host_fill_rounded_rect_gradient(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          gradient.start.x,
          gradient.start.y,
          gradient.end.x,
          gradient.end.y,
          gradient.start_color.r,
          gradient.start_color.g,
          gradient.start_color.b,
          gradient.start_color.a,
          gradient.end_color.r,
          gradient.end_color.g,
          gradient.end_color.b,
          gradient.end_color.a,
        ),
      )
  }
}

///|
fn submit_stroke_rounded_rect_brush(
  renderer : HostWebGpuRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
) -> Unit raise WebGpuHostError {
  match brush {
    @core.Brush::Solid(color) =>
      raise_for_host_status(
        host_stroke_rounded_rect(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          color.r,
          color.g,
          color.b,
          color.a,
          width,
        ),
      )
    @core.Brush::LinearGradient(gradient) =>
      raise_for_host_status(
        host_stroke_rounded_rect_gradient(
          renderer,
          rounded.rect.origin.x,
          rounded.rect.origin.y,
          rounded.rect.size.width,
          rounded.rect.size.height,
          rounded.radius,
          width,
          gradient.start.x,
          gradient.start.y,
          gradient.end.x,
          gradient.end.y,
          gradient.start_color.r,
          gradient.start_color.g,
          gradient.start_color.b,
          gradient.start_color.a,
          gradient.end_color.r,
          gradient.end_color.g,
          gradient.end_color.b,
          gradient.end_color.a,
        ),
      )
  }
}

///|
fn raise_for_host_status(code : Int) -> Unit raise WebGpuHostError {
  if code != 0 {
    raise host_status_to_error(code)
  }
}

///|
fn host_measure_text_layout(
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let text_chars = input.text.to_array()
  let carets : Array[Double] = [0.0]
  let prefix_chars : Array[Char] = []
  for ch in text_chars {
    prefix_chars.push(ch)
    let prefix = String::from_array(prefix_chars)
    carets.push(host_measure_text_width_for_input(input, prefix))
  }
  let measured_width = host_measure_text_width_for_input(input, input.text)
  let width = match input.max_width {
    Some(max_width) => measured_width.min(max_width)
    None => measured_width
  }
  match input.max_width {
    Some(max_width) =>
      for index in 0..<carets.length() {
        carets[index] = carets[index].min(max_width)
      }
    None => ()
  }
  {
    size: @core.Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn host_measure_text_width_for_input(
  input : @core.TextLayoutInput,
  text : String,
) -> Double {
  let measured = host_measure_text_width(
    host_string(text),
    host_string(input.font.css_family()),
    host_string(input.font.css_style()),
    input.font.size,
    input.font.weight,
  )
  if measured > 0.0 {
    measured
  } else {
    @core.TextSystem::fallback().measure_text({ ..input, text, }).size.width
  }
}

///|
fn host_status_to_error(code : Int) -> WebGpuHostError {
  match code {
    1 => WebGpuHostError::Unavailable
    2 => WebGpuHostError::AdapterUnavailable
    3 => WebGpuHostError::DeviceUnavailable
    4 => WebGpuHostError::SurfaceUnavailable
    5 => WebGpuHostError::PipelineUnavailable
    6 => WebGpuHostError::InvalidResource
    _ => WebGpuHostError::HostError("webgpu host error code \{code}")
  }
}

///|
fn host_string(value : String) -> HostWebGpuString {
  let handle = host_begin_create_string()
  for ch in value {
    host_string_append_char(handle, ch.to_int())
  }
  host_finish_create_string(handle)
}

///|
fn host_begin_create_string() -> Int = "webgpu" "begin_create_string"

///|
fn host_string_append_char(handle : Int, code_point : Int) -> Unit = "webgpu" "string_append_char"

///|
fn host_finish_create_string(handle : Int) -> HostWebGpuString = "webgpu" "finish_create_string"

///|
fn host_webgpu_available() -> Bool = "webgpu" "webgpu_available"

///|
fn host_adapter_ready() -> Bool = "webgpu" "adapter_ready"

///|
fn host_can_render() -> Bool = "webgpu" "can_render"

///|
fn host_measure_text_width(
  text : HostWebGpuString,
  family : HostWebGpuString,
  style : HostWebGpuString,
  size : Double,
  weight : Int,
) -> Double = "webgpu" "measure_text_width"

///|
fn host_register_font_data(
  family : HostWebGpuString,
  base64_data : HostWebGpuString,
) -> Int = "webgpu" "register_font_data"

///|
fn host_create_surface(
  canvas_id : HostWebGpuString,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> HostWebGpuSurface = "webgpu" "create_surface"

///|
fn host_surface_is_valid(surface : HostWebGpuSurface) -> Bool = "webgpu" "surface_is_valid"

///|
fn host_surface_resize(
  surface : HostWebGpuSurface,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Int = "webgpu" "surface_resize"

///|
fn host_surface_dispose(surface : HostWebGpuSurface) -> Unit = "webgpu" "surface_dispose"

///|
fn host_create_renderer(surface : HostWebGpuSurface) -> HostWebGpuRenderer = "webgpu" "create_renderer"

///|
fn host_renderer_is_valid(renderer : HostWebGpuRenderer) -> Bool = "webgpu" "renderer_is_valid"

///|
fn host_renderer_resize(
  renderer : HostWebGpuRenderer,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Int = "webgpu" "renderer_resize"

///|
fn host_begin_frame(
  renderer : HostWebGpuRenderer,
  width : Double,
  height : Double,
) -> Int = "webgpu" "begin_frame"

///|
fn host_clear(
  renderer : HostWebGpuRenderer,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int = "webgpu" "clear"

///|
fn host_fill_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int = "webgpu" "fill_rect"

///|
fn host_stroke_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  stroke_width : Double,
) -> Int = "webgpu" "stroke_rect"

///|
fn host_fill_rounded_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int = "webgpu" "fill_rounded_rect"

///|
fn host_stroke_rounded_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  stroke_width : Double,
) -> Int = "webgpu" "stroke_rounded_rect"

///|
fn host_fill_rounded_rect_gradient(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int = "webgpu" "fill_rounded_rect_gradient"

///|
fn host_stroke_rounded_rect_gradient(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  stroke_width : Double,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int = "webgpu" "stroke_rounded_rect_gradient"

///|
fn host_draw_shadow(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  offset_x : Double,
  offset_y : Double,
  blur_radius : Double,
  spread : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int = "webgpu" "draw_shadow"

///|
fn host_draw_text(
  renderer : HostWebGpuRenderer,
  text : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  family : HostWebGpuString,
  style : HostWebGpuString,
  size : Double,
  weight : Int,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  align : Int,
) -> Int = "webgpu" "draw_text"

///|
fn text_align_host_code(align : @core.TextAlign) -> Int {
  match align {
    @core.TextAlign::TextStart => 0
    @core.TextAlign::TextCenter => 1
    @core.TextAlign::TextEnd => 2
  }
}

///|
fn host_draw_image(
  renderer : HostWebGpuRenderer,
  source : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  opacity : Double,
  fit : Int,
) -> Int = "webgpu" "draw_image"

///|
fn image_fit_host_code(fit : @core.ImageFit) -> Int {
  match fit {
    @core.ImageFit::Contain => 0
    @core.ImageFit::Cover => 1
  }
}

///|
fn host_push_clip(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Int = "webgpu" "push_clip"

///|
fn host_pop_clip(renderer : HostWebGpuRenderer) -> Int = "webgpu" "pop_clip"

///|
fn host_push_transform(
  renderer : HostWebGpuRenderer,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  tx : Double,
  ty : Double,
) -> Int = "webgpu" "push_transform"

///|
fn host_pop_transform(renderer : HostWebGpuRenderer) -> Int = "webgpu" "pop_transform"

///|
fn host_push_opacity(renderer : HostWebGpuRenderer, opacity : Double) -> Int = "webgpu" "push_opacity"

///|
fn host_pop_opacity(renderer : HostWebGpuRenderer) -> Int = "webgpu" "pop_opacity"

///|
fn host_push_layer(
  renderer : HostWebGpuRenderer,
  opacity : Double,
  blend_mode : Int,
  mask_kind : Int,
  mask_x : Double,
  mask_y : Double,
  mask_width : Double,
  mask_height : Double,
  mask_radius : Double,
  offscreen : Bool,
) -> Int = "webgpu" "push_layer"

///|
fn host_pop_layer(renderer : HostWebGpuRenderer) -> Int = "webgpu" "pop_layer"

///|
fn host_push_filter(
  renderer : HostWebGpuRenderer,
  filter_kind : Int,
  amount : Double,
  matrix_values : HostWebGpuString,
) -> Int = "webgpu" "push_filter"

///|
fn host_pop_filter(renderer : HostWebGpuRenderer) -> Int = "webgpu" "pop_filter"

///|
fn host_draw_shader_effect(
  renderer : HostWebGpuRenderer,
  name : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  uniforms : HostWebGpuString,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int = "webgpu" "draw_shader_effect"

///|
fn host_present(renderer : HostWebGpuRenderer) -> Int = "webgpu" "present"

///|
fn host_renderer_dispose(renderer : HostWebGpuRenderer) -> Unit = "webgpu" "renderer_dispose"
