///|
pub(all) enum RendererFeature {
  Rect
  RoundedRect
  Gradient
  Shadow
  Text
  Image
  Clip
  Transform
  Opacity
  LayerCompositing
  BlendMode
  FilterEffect
  PathVector
  ShaderEffect
  TextShaping
  EmojiText
  AsyncImage
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererFeatureStatus {
  Ready
  Partial
  Gap
  HostForwarded
  Unavailable
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererBackendFeatureCapability {
  feature : RendererFeature
  backend : RendererBackendKind
  status : RendererFeatureStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererFeatureCapability {
  feature : RendererFeature
  backends : Array[RendererBackendFeatureCapability]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererCommandFallbackKind {
  PlannedFallback
  UnbalancedPop
  UnclosedScope
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererCommandFallback {
  index : Int
  feature : RendererFeature
  command : String
  kind : RendererCommandFallbackKind
  reason : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererCommandPlan {
  total_commands : Int
  fallback_count : Int
  final_layer_depth : Int
  final_filter_depth : Int
  fallbacks : Array[RendererCommandFallback]
} derive(Eq, Debug, ToJson)

///|
pub fn RendererFeature::label(self : RendererFeature) -> String {
  match self {
    Rect => "rect"
    RoundedRect => "rounded-rect"
    Gradient => "gradient"
    Shadow => "shadow"
    Text => "text"
    Image => "image"
    Clip => "clip"
    Transform => "transform"
    Opacity => "opacity"
    LayerCompositing => "layer-compositing"
    BlendMode => "blend-mode"
    FilterEffect => "filter-effect"
    PathVector => "path-vector"
    ShaderEffect => "shader-effect"
    TextShaping => "text-shaping"
    EmojiText => "emoji-text"
    AsyncImage => "async-image"
  }
}

///|
pub fn RendererFeatureStatus::label(self : RendererFeatureStatus) -> String {
  match self {
    Ready => "ready"
    Partial => "partial"
    Gap => "gap"
    HostForwarded => "host-forwarded"
    Unavailable => "unavailable"
  }
}

///|
pub fn RendererFeatureStatus::needs_follow_up(
  self : RendererFeatureStatus,
) -> Bool {
  match self {
    Partial | Gap | Unavailable => true
    Ready | HostForwarded => false
  }
}

///|
pub fn RendererBackendFeatureCapability::new(
  feature~ : RendererFeature,
  backend~ : RendererBackendKind,
  status~ : RendererFeatureStatus,
  note? : String = "",
) -> RendererBackendFeatureCapability {
  { feature, backend, status, note }
}

///|
pub fn RendererFeatureCapability::new(
  feature~ : RendererFeature,
  backends~ : Array[RendererBackendFeatureCapability],
) -> RendererFeatureCapability {
  { feature, backends }
}

///|
pub fn RendererFeatureCapability::backend_capability(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> RendererBackendFeatureCapability? {
  for capability in self.backends {
    if capability.backend == backend {
      return Some(capability)
    }
  }
  None
}

///|
pub fn RendererFeatureCapability::status_for_backend(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> RendererFeatureStatus {
  match self.backend_capability(backend) {
    Some(capability) => capability.status
    None => RendererFeatureStatus::Unavailable
  }
}

///|
pub fn RendererFeatureCapability::note_for_backend(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> String {
  match self.backend_capability(backend) {
    Some(capability) => capability.note
    None => "renderer backend has no recorded capability for this feature"
  }
}

///|
pub fn RendererFeatureCapability::needs_follow_up(
  self : RendererFeatureCapability,
) -> Bool {
  self.backends.any(capability => capability.status.needs_follow_up())
}

///|
pub fn renderer_capability_backends() -> Array[RendererBackendKind] {
  [
    RendererBackendKind::NativeWgpu,
    RendererBackendKind::SkiaRasterNative,
    RendererBackendKind::WebGpuWasm,
  ]
}

///|
fn renderer_backend_feature(
  feature : RendererFeature,
  backend : RendererBackendKind,
  status : RendererFeatureStatus,
  note : String,
) -> RendererBackendFeatureCapability {
  RendererBackendFeatureCapability::new(feature~, backend~, status~, note~)
}

///|
fn renderer_feature_capability_entry(
  feature : RendererFeature,
  native_wgpu_status : RendererFeatureStatus,
  native_wgpu_note : String,
  skia_status : RendererFeatureStatus,
  skia_note : String,
  web_status : RendererFeatureStatus,
  web_note : String,
) -> RendererFeatureCapability {
  RendererFeatureCapability::new(feature~, backends=[
    renderer_backend_feature(
      feature,
      RendererBackendKind::NativeWgpu,
      native_wgpu_status,
      native_wgpu_note,
    ),
    renderer_backend_feature(
      feature,
      RendererBackendKind::SkiaRasterNative,
      skia_status,
      skia_note,
    ),
    renderer_backend_feature(
      feature,
      RendererBackendKind::WebGpuWasm,
      web_status,
      web_note,
    ),
  ])
}

///|
pub fn renderer_feature_capability_report() -> Array[RendererFeatureCapability] {
  [
    renderer_feature_capability_entry(
      RendererFeature::Rect,
      RendererFeatureStatus::Ready,
      "Native wgpu renders rect fills and strokes as visual pipeline quads.",
      RendererFeatureStatus::Unavailable,
      "Skia raster support is gated on real skia_mbt native availability and renderer pixel evidence.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host renders rect fills and strokes as visual pipeline quads.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::RoundedRect,
      RendererFeatureStatus::Ready,
      "Native wgpu renders rounded fills and strokes with shader SDF geometry.",
      RendererFeatureStatus::Unavailable,
      "Skia raster support is gated on real skia_mbt native availability and renderer pixel evidence.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host renders rounded fills and strokes with shader SDF geometry.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Gradient,
      RendererFeatureStatus::Ready,
      "Native wgpu evaluates linear gradients in the visual shader.",
      RendererFeatureStatus::Unavailable,
      "Skia raster gradient support depends on shader-backed paint bindings in skia_mbt/native.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host evaluates solid and linear-gradient brush payloads.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Shadow,
      RendererFeatureStatus::Ready,
      "Native wgpu renders soft rounded shadows as visual shader primitives.",
      RendererFeatureStatus::Unavailable,
      "Skia raster shadow support depends on mask blur/filter bindings and real native smoke evidence.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host renders soft rounded shadows as visual shader primitives.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Text,
      RendererFeatureStatus::Ready,
      "Native wgpu uses shaped glyphs and a glyph-atlas text pipeline.",
      RendererFeatureStatus::Unavailable,
      "Skia raster text uses skia_mbt Font and draw_text_utf8 once real Skia is linked; shaping remains tracked separately.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host uses a canvas-rasterized DPR-aware glyph atlas and WebGPU text pipeline.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Image,
      RendererFeatureStatus::Ready,
      "Native wgpu decodes local file paths and base64 data URIs through mizchi/image for PNG, JPEG, and BMP, then caches GPU textures with contain/cover sampling.",
      RendererFeatureStatus::Unavailable,
      "Skia raster image support depends on skia_mbt encoded image decode and draw_image_rect real-backend validation.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host loads image sources into a texture cache, samples them through a WebGPU image pipeline, and falls back to a deterministic source color while loading or on failure.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Clip,
      RendererFeatureStatus::Ready,
      "Native wgpu maps nested rectangular and rounded clips, using physical scissor rectangles with shader SDF masks for rounded corners.",
      RendererFeatureStatus::Unavailable,
      "Skia raster clip support is planned through canvas clip_rect, clip_rrect, and clip_path.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host applies transformed rectangular scissors; the wasm-gc adapter submits rounded clip scopes as offscreen layer masks in the advanced composite shader.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Transform,
      RendererFeatureStatus::Partial,
      "Native wgpu folds affine transforms into planned visual, image, text, shader-effect advanced vertices, and masked layer composite vertices; scissor uses transformed bounding boxes; scoped layer/filter child plans inherit transform and clip while outer opacity is applied at composite time. Filter scopes preserve transformed child vertices and transformed clip scissors. Broader render-pass transform pixel evidence remains follow-up work.",
      RendererFeatureStatus::Unavailable,
      "Skia raster transform support is planned through canvas concat and scale-factor setup, pending pixel evidence.",
      RendererFeatureStatus::Partial,
      "The browser WebGPU host folds affine transforms into visual, image, text, and shader-effect advanced vertices, and scoped layer/filter commands clone the current transform and clip state. Web adapter tests preserve transform scope around layers, filters, and shader effects; broader render-pass transform pixel evidence remains follow-up work.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Opacity,
      RendererFeatureStatus::Ready,
      "Native wgpu folds opacity into visual and text vertex alpha.",
      RendererFeatureStatus::Unavailable,
      "Skia raster opacity support is planned through paint alpha and save_layer opacity.",
      RendererFeatureStatus::Ready,
      "The browser WebGPU host folds opacity into visual and text vertex alpha.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::LayerCompositing,
      RendererFeatureStatus::Ready,
      "PushLayer/PopLayer render child commands into offscreen textures and composite them back through the advanced GPU pass with opacity, masks, filters, and blend selection.",
      RendererFeatureStatus::Unavailable,
      "Skia raster layer compositing is planned through canvas save_layer with blend and filter paint.",
      RendererFeatureStatus::Ready,
      "The wasm-gc host ABI forwards PushLayer/PopLayer and the browser runtime renders layer scopes into offscreen WebGPU textures before compositing.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::BlendMode,
      RendererFeatureStatus::Ready,
      "Layer composite pipelines map source-over, multiply, screen, darken, and lighten to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math.",
      RendererFeatureStatus::Unavailable,
      "Skia raster blend support is planned through Skia blend-mode paint mappings.",
      RendererFeatureStatus::Ready,
      "The browser runtime maps source-over, multiply, screen, darken, and lighten to WebGPU blend states; overlay uses a backdrop-sampling WebGPU pass for exact semantics.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::FilterEffect,
      RendererFeatureStatus::Ready,
      "PushFilter/PopFilter render scoped content into offscreen textures, then the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
      RendererFeatureStatus::Unavailable,
      "Skia raster filter support requires skia_mbt image-filter and color-filter bindings before it can be marked ready.",
      RendererFeatureStatus::Ready,
      "The wasm-gc host forwards filter scopes and the browser advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::PathVector,
      RendererFeatureStatus::Ready,
      "Native wgpu tessellates DrawPath through moon_zeno and renders the resulting fill/stroke triangle mesh through the visual GPU pipeline.",
      RendererFeatureStatus::Unavailable,
      "Skia raster path support is planned through native Skia Path replay from MoUI PathSpec.",
      RendererFeatureStatus::Ready,
      "The wasm-gc adapter tessellates DrawPath through the same moon_zeno contract and forwards a mesh payload to the browser WebGPU visual pipeline.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::ShaderEffect,
      RendererFeatureStatus::Ready,
      "DrawShaderEffect executes through the advanced GPU shader path for built-in solid, checker, linear-gradient-debug, vignette, and fallback-brush effects.",
      RendererFeatureStatus::Unavailable,
      "Skia raster shader effects are planned as procedural canvas draws with fallback brush handling.",
      RendererFeatureStatus::Ready,
      "DrawShaderEffect is forwarded through the wasm-gc host ABI and executes in the browser advanced WebGPU shader path with the same built-ins and fallback brush.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::TextShaping,
      RendererFeatureStatus::Partial,
      "Native wgpu uses a private platform text provider boundary: render/wgpu owns validation and atlas upload, including non-empty run-layout caret coverage checks, render/wgpu/cosmic_text owns the Cosmic provider, macOS composes CoreText/CoreGraphics with Cosmic fallback, Windows composes a DirectWrite scaffold with Cosmic fallback, and Linux has a fontconfig/HarfBuzz/FreeType scaffold. Cosmic measurement and native run layout paths safe-map provider-fragile emoji samples before shaping while preserving monotonic caret coverage. Full bidi, line breaking, and typography conformance remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Skia raster text provider can use basic Skia Font measurement/drawing once linked, but SkShaper/SkParagraph-style shaping is still follow-up work.",
      RendererFeatureStatus::Partial,
      "Web text uses canvas-rasterized glyph atlases, but full shaping, bidi, and line breaking conformance remain follow-up work.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::EmojiText,
      RendererFeatureStatus::Partial,
      "Native wgpu atlas upload, text vertices, and provider protocol can preserve RGBA color glyph payloads; Cosmic loads platform emoji fallback font candidates when available, keeps color swash pixels, and safe-maps provider-fragile single-codepoint, variation-selector, and ZWJ emoji samples before native layout so caret coverage remains stable; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS. Full emoji font fallback across native providers, ZWJ/color emoji conformance, and full grapheme shaping remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Skia raster emoji rendering depends on platform font fallback and future shaping coverage; deterministic emoji conformance remains follow-up work.",
      RendererFeatureStatus::Partial,
      "Browser canvas glyph rasterization can surface emoji where fonts support it. Diagnostic text conformance covers deterministic measurement and caret invariants, but not browser rasterization determinism or full grapheme shaping parity.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::AsyncImage,
      RendererFeatureStatus::Partial,
      "Renderer-neutral image lifecycle state models loading, ready, failed, disposed, and eviction; native WgpuRenderer now exposes renderer-local image resource snapshots, with synchronous decode paths marking ready or failed.",
      RendererFeatureStatus::Partial,
      "Skia raster image lifecycle uses the same renderer-neutral records; real Skia decode and repaint evidence remains follow-up work.",
      RendererFeatureStatus::Partial,
      "Renderer-neutral image lifecycle state matches the browser async loading cache contract; WebGpuWasmRenderer and the backend WebRenderer facade expose app-visible image resource snapshots, refresh loading, ready, or failed records from the browser cache after host submission, and the canonical Web boot path schedules a redraw when Image.onload or Image.onerror reports a resource change.",
    ),
  ]
}

///|
pub fn renderer_feature_capability(
  feature : RendererFeature,
) -> RendererFeatureCapability? {
  for entry in renderer_feature_capability_report() {
    if entry.feature == feature {
      return Some(entry)
    }
  }
  None
}

///|
pub fn renderer_feature_follow_ups() -> Array[RendererFeatureCapability] {
  let follow_ups : Array[RendererFeatureCapability] = []
  for entry in renderer_feature_capability_report() {
    if entry.needs_follow_up() {
      follow_ups.push(entry)
    }
  }
  follow_ups
}

///|
pub fn renderer_backend_capabilities(
  backend : RendererBackendKind,
) -> Array[RendererBackendFeatureCapability] {
  let capabilities : Array[RendererBackendFeatureCapability] = []
  for entry in renderer_feature_capability_report() {
    match entry.backend_capability(backend) {
      Some(capability) => capabilities.push(capability)
      None => ()
    }
  }
  capabilities
}

///|
pub fn plan_renderer_command_fallbacks(
  commands : Array[@core.DrawCommand],
) -> RendererCommandPlan {
  let fallbacks : Array[RendererCommandFallback] = []
  let mut layer_depth = 0
  let mut filter_depth = 0
  for index, command in commands {
    match command {
      @core.DrawCommand::PushLayer(_) => layer_depth = layer_depth + 1
      @core.DrawCommand::PopLayer =>
        if layer_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::LayerCompositing,
              command="PopLayer",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopLayer has no matching PushLayer",
            ),
          )
        } else {
          layer_depth = layer_depth - 1
        }
      @core.DrawCommand::PushFilter(_) => filter_depth = filter_depth + 1
      @core.DrawCommand::PopFilter =>
        if filter_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::FilterEffect,
              command="PopFilter",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopFilter has no matching PushFilter",
            ),
          )
        } else {
          filter_depth = filter_depth - 1
        }
      @core.DrawCommand::DrawPath(_) => ()
      @core.DrawCommand::DrawShaderEffect(_) => ()
      _ => ()
    }
  }
  if layer_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::LayerCompositing,
        command="PushLayer",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open layer scope",
      ),
    )
  }
  if filter_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::FilterEffect,
        command="PushFilter",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open filter scope",
      ),
    )
  }
  {
    total_commands: commands.length(),
    fallback_count: fallbacks.length(),
    final_layer_depth: layer_depth,
    final_filter_depth: filter_depth,
    fallbacks,
  }
}

///|
fn renderer_command_fallback(
  index~ : Int,
  feature~ : RendererFeature,
  command~ : String,
  reason~ : String,
  kind? : RendererCommandFallbackKind = RendererCommandFallbackKind::PlannedFallback,
) -> RendererCommandFallback {
  { index, feature, command, kind, reason }
}
