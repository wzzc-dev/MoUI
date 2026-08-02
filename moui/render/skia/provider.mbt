///|
/// Build a Skia raster `RendererProvider` that creates `SkiaRasterRenderer`
/// instances via the given `create_raster` factory.
///
/// The `create_raster` closure receives metrics and returns a live
/// raster renderer with its present target already wired. This lets the
/// platform entrypoint (macos, linux, windows, …) capture its own
/// `SkiaPresentTarget` without the provider needing to know the platform.
pub fn create_skia_raster_provider(
  create_raster~ : (@render.RendererSurfaceMetrics) -> SkiaRasterRenderer,
) -> @render.RendererProvider {
  let caps = skia_provider_capabilities(
    provider_id="skia-raster",
    backend=@render.RendererBackendKind::SkiaRasterNative,
  )
  @render.RendererProvider::{
    id: "skia-raster",
    descriptor: skia_raster_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_raster_surface,
    create: (metrics, _bound) => skia_create_instance(metrics, create_raster~),
  }
}

///|
/// Build a Skia hybrid (raster+GPU) `RendererProvider` that creates
/// `SkiaHybridRenderer` instances via the given `create_hybrid` factory.
///
/// The `create_hybrid` closure receives metrics and returns a hybrid
/// renderer with the platform present targets already wired.
pub fn create_skia_hybrid_provider(
  create_hybrid~ : (@render.RendererSurfaceMetrics) -> SkiaHybridRenderer,
) -> @render.RendererProvider {
  let caps = skia_provider_capabilities(
    provider_id="skia-hybrid",
    backend=@render.RendererBackendKind::SkiaGpuNative,
  )
  @render.RendererProvider::{
    id: "skia-hybrid",
    descriptor: skia_gpu_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_gpu_surface,
    create: (metrics, _bound) => {
      skia_create_hybrid_instance(metrics, create_hybrid~)
    },
  }
}

///|
/// Build a host-facing raster binding. The provider still has a real
/// `RendererInstance` factory for diagnostics and tests, while production
/// hosts create the richer `HostWindowRenderer` through the binding.
pub fn create_skia_raster_host_binding(
  create_host_renderer~ : (@render.RendererSurfaceMetrics, @render.BoundSurface) -> @render.HostWindowRenderer,
) -> @render.RendererProviderBinding {
  let caps = skia_provider_capabilities(
    provider_id="skia-raster",
    backend=@render.RendererBackendKind::SkiaRasterNative,
  )
  let provider : @render.RendererProvider = {
    id: "skia-raster",
    descriptor: skia_raster_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_raster_surface,
    create: (metrics, bound) => {
      @render.RendererInstance::from_host_window_renderer(
        create_host_renderer(metrics, bound),
      )
    },
  }
  @render.RendererProviderBinding::new(provider~, create_host_renderer~)
}

///|
/// Build a host-facing GPU binding. Its registration order relative to the
/// raster binding is the platform's explicit `auto` policy.
pub fn create_skia_hybrid_host_binding(
  create_host_renderer~ : (@render.RendererSurfaceMetrics, @render.BoundSurface) -> @render.HostWindowRenderer,
) -> @render.RendererProviderBinding {
  let caps = skia_provider_capabilities(
    provider_id="skia-hybrid",
    backend=@render.RendererBackendKind::SkiaGpuNative,
  )
  let provider : @render.RendererProvider = {
    id: "skia-hybrid",
    descriptor: skia_gpu_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_gpu_surface,
    create: (metrics, bound) => {
      @render.RendererInstance::from_host_window_renderer(
        create_host_renderer(metrics, bound),
      )
    },
  }
  @render.RendererProviderBinding::new(provider~, create_host_renderer~)
}

///|
/// Skia owns the capability declarations used by both its raster and GPU
/// providers. The backend enum is descriptive metadata; the id is the report
/// identity used by composition roots.
pub fn skia_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let base_note = skia_feature_note(feature)
    let note = match backend {
      @render.RendererBackendKind::SkiaGpuNative =>
        "Skia GPU reuses the native Skia command and resource semantics; " +
        base_note
      _ => base_note
    }
    (@render.RendererFeatureStatus::Supported, note)
  })
}

///|
/// Feature evidence belongs to the Skia provider package. This is deliberately
/// not mirrored in `moui/render`: reports aggregate the declarations from the
/// providers registered by a composition root.
fn skia_feature_note(feature : @render.RendererFeature) -> String {
  match feature {
    Rect =>
      "Skia raster renders clear, rect fill, and rect stroke commands in the real native renderer pixel smoke through moui_skia/native."
    RoundedRect =>
      "Skia raster renders rounded rect fills, strokes, and solid rounded brushes in the real native renderer pixel smoke."
    Gradient =>
      "Skia raster renders linear-gradient and radial-gradient fills and strokes for rounded rects and paths; linear gradients have real native renderer pixel smoke coverage and radial brushes have renderer-local guarded pixel coverage."
    Shadow =>
      "Skia raster renders soft rounded shadows through moui_skia MaskFilter blur and real native renderer pixel smoke coverage."
    Text =>
      "Skia raster text measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interior stabilization for both caret paths, grapheme-safe mixed-run fallback segments, and best-available glyph-run rendering clip to the TextRun frame while resolving FontSpec family, weight, style, and representative coverage characters through Skia FontMgr FontFallbackRequest/Font; real native renderer smoke covers glyph-run pixels and bounded TextRun frame clipping; broader shaping remains tracked separately."
    Image =>
      "Skia raster decodes PNG/JPEG/BMP data URIs and local PNG/JPEG/BMP files through moui_skia encoded image APIs, validates contain/cover/stretch/scale-down/fit-width/fit-height placement geometry and draw_image_rect output, records ready/failed image lifecycle states, and renders failed-image placeholders in the real native renderer smoke."
    Clip =>
      "Skia raster applies canvas clip_rect, clip_rrect, and clip_path scopes, with rectangular, rounded, and path-clipped gradient output covered by the real native renderer smoke."
    Transform =>
      "Skia raster maps MoUI affine fields into Skia matrix members and validates translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform output in the real native renderer smoke."
    Opacity =>
      "Skia raster applies save_layer opacity, with blended pixel output covered by the real native renderer smoke."
    LayerCompositing =>
      "Skia raster composites save_layer scopes with renderer-local pixel tests and real native renderer smoke coverage for opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter combinations."
    BlendMode =>
      "Skia raster maps all MoUI blend modes to Skia paint blend modes with renderer-local multiply pixel coverage plus real native renderer smoke coverage for multiply, screen, overlay, darken, and lighten output pixels."
    FilterEffect =>
      "Skia raster applies image-filter and color-filter save_layer scopes with renderer-local saturation/color-matrix coverage plus real native renderer smoke coverage for blur, saturation, brightness, contrast, and identity-normalized color matrix filters."
    PathVector =>
      "Skia raster replays MoUI PathSpec into native Skia paths with renderer-local pixel tests and real native smoke coverage for solid and linear-gradient fills and strokes, plus quadratic and cubic curve verbs."
    ShaderEffect =>
      "Skia raster executes solid, checker, linear-gradient-debug, and vignette effects with renderer-local pixel tests and real native renderer pixel smoke coverage; unknown shader names still use fallback paths."
    TextShaping =>
      "Skia raster text provider maps FontSpec family, weight, and style to Skia FontMgr/Font, builds FontFallbackRequest values with representative emoji/non-ASCII coverage characters before regular family matching, splits mixed-script text into grapheme-safe fallback segments for per-run FontMgr resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or Skia-measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interiors in both caret paths, retries emoji-family fonts for emoji-hint text on the system FontMgr path, uses optional SkShaper shaped glyph-run drawing once linked, and marks SkParagraph-style line breaking plus bidi reordering ready in the text maturity preflight."
    EmojiText =>
      "Skia raster detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, emoji tag-sequence, Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark, and Hangul Jamo grapheme cluster samples, prefers emoji coverage characters and inferred language tags in system FontMgr FontFallbackRequest matching, stabilizes representative cluster interior carets, retries platform emoji font candidates before default-font fallback, and reports deterministic color emoji readiness through Typeface::has_color_glyphs and glyph format metadata."
    AsyncImage =>
      "Skia raster image lifecycle uses the same renderer-neutral records, ImageResourceLoadCompletion apply helper, and revisioned snapshot contract, exposes renderer-local image-resource change callbacks when lifecycle revisions advance, native Skia providers create renderers with off-main-thread async image loading where data URI sources complete through the renderer decode path and local-file sources read and decode to RGBA pixels on background native workers via platform C++ stubs (GCD on macOS, pthread on Linux, CreateThread on Windows) before decoded completion delivery, forward snapshots and callback setters through HostWindowRenderer, HostWindowRenderer exposes apply_image_resource_load_completion as the renderer-neutral completion apply port, HostAsyncImageLoader scans loading records and gates late/cancelled callbacks before HostImageResourceCompletionSource routes native async loader completion snapshots through HostImageResourceRepaintTracker, macOS/Windows/Linux hosts install baseline-guarded callbacks, call optional provider-owned async image loaders after present baseline, and request redraw for post-present image revisions, immutable failed sources are cached with diagnostics before placeholder drawing, local-file failures retry once the file appears, hosts discard closed-window image changes, real Skia observation covers PNG/JPEG/BMP data URI decode, PNG/JPEG/BMP local-file decode, failed-image placeholder, failed-cache snapshot, local-file retry, image-resource callback snapshots, HostWindowRenderer callback bridge coverage, async image second-frame smoke, and dispose-record diagnostics, and decoded completions carry background_io, background_decode, decoded dimensions, row bytes, and RGBA pixels."
  }
}

///|
/// Default raster surface negotiation: accepts `CpuRaster` surfaces for
/// any logical size ≥ 1×1.
fn skia_negotiate_raster_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  @render.negotiate_cpu_raster_surface(
    surface,
    label="raster",
    id="skia-raster",
    presentation_model=@render.RendererPresentationModel::CpuPixelFrame,
  )
}

///|
/// GPU surface negotiation: accepts GPU surfaces with a Metal, Vulkan,
/// EGL, or D3D12 handle; the route is resolved from the handle kind.
fn skia_negotiate_gpu_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  @render.negotiate_gpu_surface(
    surface,
    label="GPU",
    id="skia-gpu",
    route_for=skia_route_for_gpu_handle,
  )
}

///|
fn skia_route_for_gpu_handle(
  handle : @render.GpuHostSurfaceDescriptor,
) -> @render.SkiaSurfaceRoute {
  match handle {
    @render.GpuHostSurfaceDescriptor::MetalLayer(_) =>
      @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(_) =>
      @render.SkiaSurfaceRoute::Direct3DGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(_) =>
      @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(_, _) =>
      @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(_) =>
      @render.SkiaSurfaceRoute::EglGpuSurfaceRoute
  }
}

///|
fn skia_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_raster~ : (@render.RendererSurfaceMetrics) -> SkiaRasterRenderer,
) -> @render.RendererInstance {
  let renderer = create_raster(metrics)
  @render.new_provider_instance(
    render_frame=frame => renderer.render_frame(frame),
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => renderer.dispose(),
  )
}

///|
fn skia_create_hybrid_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_hybrid~ : (@render.RendererSurfaceMetrics) -> SkiaHybridRenderer,
) -> @render.RendererInstance {
  let hybrid = create_hybrid(metrics)
  @render.new_provider_instance(
    render_frame=frame => hybrid.render_frame(frame),
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => {
      let _ = hybrid.drain_present_completions()
    },
  )
}
