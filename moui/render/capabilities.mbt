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
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererFeatureCapability {
  feature : RendererFeature
  native_status : RendererFeatureStatus
  web_status : RendererFeatureStatus
  native_note : String
  web_note : String
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
  }
}

///|
pub fn RendererFeatureStatus::needs_follow_up(
  self : RendererFeatureStatus,
) -> Bool {
  match self {
    Partial | Gap => true
    Ready | HostForwarded => false
  }
}

///|
pub fn renderer_feature_capability_report() -> Array[RendererFeatureCapability] {
  [
    {
      feature: RendererFeature::Rect,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu renders rect fills and strokes as visual pipeline quads.",
      web_note: "The browser WebGPU host renders rect fills and strokes as visual pipeline quads.",
    },
    {
      feature: RendererFeature::RoundedRect,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu renders rounded fills and strokes with shader SDF geometry.",
      web_note: "The browser WebGPU host renders rounded fills and strokes with shader SDF geometry.",
    },
    {
      feature: RendererFeature::Gradient,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu evaluates linear gradients in the visual shader.",
      web_note: "The browser WebGPU host evaluates solid and linear-gradient brush payloads.",
    },
    {
      feature: RendererFeature::Shadow,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu renders soft rounded shadows as visual shader primitives.",
      web_note: "The browser WebGPU host renders soft rounded shadows as visual shader primitives.",
    },
    {
      feature: RendererFeature::Text,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu uses shaped glyphs and a glyph-atlas text pipeline.",
      web_note: "The browser WebGPU host uses a canvas-rasterized DPR-aware glyph atlas and WebGPU text pipeline.",
    },
    {
      feature: RendererFeature::Image,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu decodes local file paths and base64 data URIs through mizchi/image for PNG, JPEG, and BMP, then caches GPU textures with contain/cover sampling.",
      web_note: "The browser WebGPU host loads image sources into a texture cache, samples them through a WebGPU image pipeline, and falls back to a deterministic source color while loading or on failure.",
    },
    {
      feature: RendererFeature::Clip,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu maps nested rectangular and rounded clips, using physical scissor rectangles with shader SDF masks for rounded corners.",
      web_note: "The browser WebGPU host applies transformed rectangular scissors; the wasm-gc adapter submits rounded clip scopes as offscreen layer masks in the advanced composite shader.",
    },
    {
      feature: RendererFeature::Transform,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native wgpu folds affine transforms into planned visual, image, text, shader-effect advanced vertices, and masked layer composite vertices; scissor uses transformed bounding boxes; scoped layer/filter child plans inherit transform and clip while outer opacity is applied at composite time. Filter scopes preserve transformed child vertices and transformed clip scissors. Broader render-pass transform pixel evidence remains follow-up work.",
      web_note: "The browser WebGPU host folds affine transforms into visual, image, text, and shader-effect advanced vertices, and scoped layer/filter commands clone the current transform and clip state. Web adapter tests preserve transform scope around layers, filters, and shader effects; broader render-pass transform pixel evidence remains follow-up work.",
    },
    {
      feature: RendererFeature::Opacity,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu folds opacity into visual and text vertex alpha.",
      web_note: "The browser WebGPU host folds opacity into visual and text vertex alpha.",
    },
    {
      feature: RendererFeature::LayerCompositing,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "PushLayer/PopLayer render child commands into offscreen textures and composite them back through the advanced GPU pass with opacity, masks, filters, and blend selection.",
      web_note: "The wasm-gc host ABI forwards PushLayer/PopLayer and the browser runtime renders layer scopes into offscreen WebGPU textures before compositing.",
    },
    {
      feature: RendererFeature::BlendMode,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Layer composite pipelines map source-over, multiply, screen, darken, and lighten to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math.",
      web_note: "The browser runtime maps source-over, multiply, screen, darken, and lighten to WebGPU blend states; overlay uses a backdrop-sampling WebGPU pass for exact channel math.",
    },
    {
      feature: RendererFeature::FilterEffect,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "PushFilter/PopFilter render scoped content into offscreen textures, then the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
      web_note: "The wasm-gc host forwards filter scopes and the browser advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
    },
    {
      feature: RendererFeature::PathVector,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "Native wgpu tessellates DrawPath through moon_zeno and renders the resulting fill/stroke triangle mesh through the visual GPU pipeline.",
      web_note: "The wasm-gc adapter tessellates DrawPath through the same moon_zeno contract and forwards a mesh payload to the browser WebGPU visual pipeline.",
    },
    {
      feature: RendererFeature::ShaderEffect,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "DrawShaderEffect executes through the advanced GPU shader path for built-in solid, checker, linear-gradient-debug, vignette, and fallback-brush effects.",
      web_note: "DrawShaderEffect is forwarded through the wasm-gc host ABI and executes in the browser advanced WebGPU shader path with the same built-ins and fallback brush.",
    },
    {
      feature: RendererFeature::TextShaping,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native wgpu uses a private platform text provider boundary: render/wgpu owns validation and atlas upload, including non-empty run-layout caret coverage checks, render/wgpu/cosmic_text owns the Cosmic provider, macOS composes CoreText/CoreGraphics with Cosmic fallback, Windows composes a DirectWrite scaffold with Cosmic fallback, and Linux has a fontconfig/HarfBuzz/FreeType scaffold. Cosmic measurement and native run layout paths carry monotonic caret coverage for representative emoji clusters. Full bidi, line breaking, and typography conformance remain follow-up work.",
      web_note: "Web text uses canvas-rasterized glyph atlases, but full shaping, bidi, and line breaking conformance remain follow-up work.",
    },
    {
      feature: RendererFeature::EmojiText,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native wgpu atlas upload, text vertices, and provider protocol can preserve RGBA color glyph payloads; Cosmic loads platform emoji fallback font candidates when available, keeps color swash pixels, and returns native run layout caret coverage for single-codepoint, variation-selector, and ZWJ emoji samples; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS. Full emoji font fallback across native providers, ZWJ/color emoji conformance, and full grapheme shaping remain follow-up work.",
      web_note: "Browser canvas glyph rasterization can surface emoji where fonts support it. Diagnostic text conformance covers deterministic measurement and caret invariants, but not browser rasterization determinism or full grapheme shaping parity.",
    },
    {
      feature: RendererFeature::AsyncImage,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Renderer-neutral image lifecycle state models loading, ready, failed, disposed, and eviction; native WgpuRenderer now exposes renderer-local image resource snapshots, with synchronous decode paths marking ready or failed.",
      web_note: "Renderer-neutral image lifecycle state matches the browser async loading cache contract; WebGpuWasmRenderer and the backend WebRenderer facade expose app-visible image resource snapshots, refresh loading, ready, or failed records from the browser cache after host submission, and the canonical Web boot path schedules a redraw when Image.onload or Image.onerror reports a resource change.",
    },
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
    if entry.native_status.needs_follow_up() ||
      entry.web_status.needs_follow_up() {
      follow_ups.push(entry)
    }
  }
  follow_ups
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
