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
  WebGpuHostImportInfo::new(
    import_module="webgpu",
    target="wasm-gc",
    surface_resource="browser canvas WebGPU surface handle",
    renderer_resource="browser WebGPU renderer handle",
    description="MoonBit calls synchronous wasm-gc host imports; the browser loader must initialize navigator.gpu before instantiating the app.",
  )
}

///|
pub fn required_capabilities() -> WebGpuHostCapabilities {
  WebGpuHostCapabilities::new(
    webgpu_available=true,
    adapter_ready=true,
    can_render=true,
  )
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
    capabilities=webgpu_provider_capabilities(
      provider_id="webgpu-wasm",
      backend=@render.RendererBackendKind::WebGpuWasm,
    ),
    description="Browser WebGPU renderer reached through wasm-gc host imports.",
  )
}

///|
/// Provider factory for the wasm-gc WebGPU adapter. Browser composition owns
/// the canvas-specific renderer factory while this package owns negotiation
/// and its capability declaration.
pub fn create_webgpu_provider(
  create_webgpu~ : (@render.RendererSurfaceMetrics) -> WebGpuWasmRenderer,
) -> @render.RendererProvider {
  let caps = webgpu_provider_capabilities(
    provider_id="webgpu-wasm",
    backend=@render.RendererBackendKind::WebGpuWasm,
  )
  @render.RendererProvider::{
    id: "webgpu-wasm",
    descriptor: renderer_descriptor(),
    capabilities: () => caps,
    negotiate: web_canvas_negotiate_surface,
    create: (metrics, _bound) => webgpu_create_instance(metrics, create_webgpu~),
  }
}

///|
/// Build the browser Canvas2D fallback provider. The browser runtime exposes
/// its Canvas2D implementation through the WebGPU-compatible host-import
/// port, so this provider intentionally creates `WebGpuWasmRenderer` values
/// instead of importing the WeChat-only `canvas2d` wasm host module.
pub fn create_browser_canvas2d_fallback_provider(
  create_canvas2d~ : (@render.RendererSurfaceMetrics) -> WebGpuWasmRenderer,
) -> @render.RendererProvider {
  let caps = browser_canvas2d_fallback_capabilities(
    provider_id="canvas2d",
    backend=@render.RendererBackendKind::Canvas2DWasm,
  )
  @render.RendererProvider::{
    id: "canvas2d",
    descriptor: @render.RendererDescriptor::new(
      backend=@render.RendererBackendKind::Canvas2DWasm,
      family=@render.RendererFamily::Canvas2D,
      presentation=@render.RendererPresentationModel::WebCanvas,
      supported_targets=[
        @render.RendererTarget::WasmGc,
        @render.RendererTarget::Web,
      ],
      capabilities=caps,
      description="Browser Canvas2D fallback reached through the WebGPU-compatible wasm-gc host-import port.",
    ),
    capabilities: () => caps,
    negotiate: web_canvas_negotiate_surface,
    create: (metrics, _bound) => {
      webgpu_create_instance(metrics, create_webgpu=create_canvas2d)
    },
  }
}

///|
pub fn webgpu_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let status = match feature {
      @render.RendererFeature::Gradient | @render.RendererFeature::Transform =>
        @render.RendererFeatureStatus::Partial
      _ => @render.RendererFeatureStatus::Supported
    }
    (status, "Browser WebGPU provider declares \{feature.label()} support.")
  })
}

///|
pub fn browser_canvas2d_fallback_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let status = match feature {
      @render.RendererFeature::Image | @render.RendererFeature::AsyncImage =>
        @render.RendererFeatureStatus::Partial
      _ => @render.RendererFeatureStatus::Supported
    }
    (
      status,
      "Browser Canvas2D fallback provider declares \{feature.label()} support.",
    )
  })
}

///|
fn web_canvas_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  match surface {
    @render.SurfaceDescriptor::CpuRaster(width, height, scale_factor) =>
      if width >= 1.0 && height >= 1.0 && scale_factor > 0.0 {
        @render.SurfaceNegotiationResult::SurfaceAccepted(
          @render.BoundSurface::new(
            kind=@render.RendererPresentationModel::WebCanvas,
            route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
            metrics=@render.RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor~,
            ),
          ),
        )
      } else {
        @render.SurfaceNegotiationResult::SurfaceRejected(
          "invalid browser canvas dimensions",
        )
      }
    @render.SurfaceDescriptor::GpuSurface(_, _, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "browser renderer provider accepts canvas surfaces",
      )
  }
}

///|
fn webgpu_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_webgpu~ : (@render.RendererSurfaceMetrics) -> WebGpuWasmRenderer,
) -> @render.RendererInstance {
  let renderer = create_webgpu(metrics)
  @render.new_provider_instance(
    render_frame=frame => renderer.render_frame(frame),
    recover=_reason => @render.RecoveryResult::RecoverySucceeded,
    dispose=() => renderer.dispose(),
  )
}

///|
pub fn adapter_info() -> WebGpuHostAdapterInfo {
  WebGpuHostAdapterInfo::new(
    renderer=backend_info(),
    surface_contract=canvas_surface_contract(),
    imports=host_import_info(),
    capabilities=required_capabilities(),
    description="Web/Wasm uses a single wasm-gc path: window/web events plus browser WebGPU host imports. Missing host capabilities fail startup instead of falling back.",
  )
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
  WebGpuHostRendererPort::new(
    capabilities=() => {
      WebGpuHostCapabilities::new(
        webgpu_available=host_webgpu_available(),
        adapter_ready=host_adapter_ready(),
        can_render=host_can_render(),
      )
    },
    create_surface=(canvas_id, metrics) => {
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
      WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => {
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
    resize=metrics => {
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
    measure_text=input => host_measure_text_layout(input),
    register_font_data=(family, data) => {
      ignore(
        host_register_font_data(
          host_string(family.css_token()),
          host_string(@base64.encode(data[:])),
        ),
      )
    },
    image_resource=source => {
      match renderer_ref.val {
        Some(renderer) => host_image_resource_record(renderer, source)
        None => None
      }
    },
    submit=calls => {
      match renderer_ref.val {
        Some(renderer) => submit_host_calls(renderer, calls)
        None => raise WebGpuHostError::InvalidResource
      }
    },
    dispose=() => {
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
  )
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
  port.create_surface(canvas_id, metrics)
}

///|
pub fn create_renderer(
  canvas_id~ : String,
  logical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
  port~ : WebGpuHostRendererPort,
) -> WebGpuWasmRenderer raise WebGpuHostError {
  let capabilities = port.capabilities()
  ensure_required_capabilities(capabilities)
  let surface = create_surface(canvas_id~, logical_size~, scale_factor~, port~)
  port.create_renderer(surface)
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
  self.port.resize(metrics)
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
  self.port.submit(calls)
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
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(frame.clear_color),
  ]
  commands.append(expanded.commands)
  self.render(commands) catch {
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
    measure=input => self.port.measure_text(input),
    register_font_data=(family, data) => {
      self.port.register_font_data(family, data)
    },
  )
}

///|
pub fn WebGpuWasmRenderer::dispose(self : WebGpuWasmRenderer) -> Unit {
  self.port.dispose()
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
