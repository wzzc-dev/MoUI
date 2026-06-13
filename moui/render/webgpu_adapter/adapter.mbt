///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    status=@render.RendererCapabilityStatus::Supported,
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
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    family=@render.RendererFamily::WebGpu,
    presentation=@render.RendererPresentationModel::WebCanvas,
    supported_targets=[
      @render.RendererTarget::WasmGc,
      @render.RendererTarget::Web,
    ],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::WebGpuWasm,
    ),
    description="Browser WebGPU renderer reached through wasm-gc host imports.",
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
    image_resource: source => {
      match renderer_ref.val {
        Some(renderer) => host_image_resource_record(renderer, source)
        None => None
      }
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
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    layer_cache: WebGpuLayerCommandCache::new(),
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
  self.record_web_image_commands(commands)
  let calls = draw_commands_to_host_calls(commands, self.size)
  (self.port.submit)(calls)
  self.refresh_web_image_commands(commands)
  self.last_calls = calls
  self.present_count = self.present_count + 1
}

///|
pub fn WebGpuWasmRenderer::render_frame(
  self : WebGpuWasmRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  let expanded = self.layer_cache.expand_frame_commands(frame.commands)
  self.render(expanded.commands) catch {
    _ => ()
  }
  @render.RenderFrameResult::new(
    cache_hit_count=expanded.cache_hit_count,
    cache_miss_count=expanded.cache_miss_count,
    cache_update_count=expanded.cache_update_count,
    missing_layer_keys=expanded.missing_layer_keys,
  )
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
pub fn WebGpuWasmRenderer::image_resources(
  self : WebGpuWasmRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.image_lifecycle.snapshot()
}

///|
pub fn WebGpuWasmRenderer::image_resource_snapshot(
  self : WebGpuWasmRenderer,
) -> @render.ImageResourceSnapshot {
  self.image_lifecycle.snapshot_with_revision()
}
