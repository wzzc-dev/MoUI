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
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native wgpu maps nested rectangular and rounded clips, using physical scissor rectangles with shader SDF masks for rounded corners.",
      web_note: "The browser WebGPU host applies the same transformed rectangular clip intersection before setting DPR-aware scissor rectangles; rounded masks remain follow-up work.",
    },
    {
      feature: RendererFeature::Transform,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native wgpu folds affine transforms into planned visual, image, and text vertices; scissor uses transformed bounding boxes and layer-level transform state remains follow-up work.",
      web_note: "The browser WebGPU host folds affine transforms into visual, image, and text vertices; richer render-pass transform state remains follow-up work.",
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
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Layer intent is modeled with PushLayer/PopLayer, opacity, blend, mask, and offscreen flags; native wgpu still needs retained offscreen pass execution.",
      web_note: "Layer intent is modeled in DrawCommand; the browser WebGPU host ABI still needs layer pass calls and mask composition.",
    },
    {
      feature: RendererFeature::BlendMode,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "BlendMode is part of LayerSpec; pipeline blend-state mapping remains follow-up work.",
      web_note: "BlendMode is part of LayerSpec; the wasm-gc WebGPU host still needs ABI and pipeline mapping.",
    },
    {
      feature: RendererFeature::FilterEffect,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "PushFilter/PopFilter now represent blur, color, and contrast-style effects; shader pass execution remains follow-up work.",
      web_note: "FilterEffect is renderer-neutral; browser WebGPU host calls and shader passes remain follow-up work.",
    },
    {
      feature: RendererFeature::PathVector,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::Ready,
      native_note: "DrawPath models move/line/quad/cubic/close verbs and is lowered by the shared path tessellator into fill and stroke triangle vertices before renderer execution.",
      web_note: "DrawPath uses the same renderer-neutral tessellation contract as native; WebGPU host upload remains aligned to the generated triangle mesh.",
    },
    {
      feature: RendererFeature::ShaderEffect,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "DrawShaderEffect resolves through a shared registry with built-in solid, checker, linear-gradient-debug, and vignette entries; GPU shader execution remains follow-up work.",
      web_note: "DrawShaderEffect resolves through the same shared registry before browser host execution; WebGPU shader host calls remain follow-up work.",
    },
    {
      feature: RendererFeature::TextShaping,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Native text uses HarfBuzz shaping and fallback faces, but full bidi, line breaking, and typography conformance remain follow-up work.",
      web_note: "Web text uses canvas-rasterized glyph atlases, but full shaping, bidi, and line breaking conformance remain follow-up work.",
    },
    {
      feature: RendererFeature::EmojiText,
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Color emoji font fallback and atlas upload are not implemented in native wgpu yet.",
      web_note: "Browser canvas glyph rasterization can surface emoji where fonts support it, but deterministic coverage is not tested.",
    },
    {
      feature: RendererFeature::AsyncImage,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::Partial,
      native_note: "Renderer-neutral image lifecycle state now models loading, ready, failed, disposed, and eviction; native decode still reports synchronously through the adapter.",
      web_note: "Renderer-neutral image lifecycle state now matches the browser async loading cache contract; wiring runtime JS diagnostics into app-visible state remains follow-up work.",
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
      @core.DrawCommand::PushLayer(_) => {
        layer_depth = layer_depth + 1
        fallbacks.push(
          renderer_command_fallback(
            index~,
            feature=RendererFeature::LayerCompositing,
            command="PushLayer",
            reason="layer intent is modeled, but retained offscreen compositing is not executed by the renderer yet",
          ),
        )
      }
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
      @core.DrawCommand::PushFilter(_) => {
        filter_depth = filter_depth + 1
        fallbacks.push(
          renderer_command_fallback(
            index~,
            feature=RendererFeature::FilterEffect,
            command="PushFilter",
            reason="filter intent is modeled, but GPU filter passes are not executed by the renderer yet",
          ),
        )
      }
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
      @core.DrawCommand::DrawShaderEffect(_) =>
        fallbacks.push(
          renderer_command_fallback(
            index~,
            feature=RendererFeature::ShaderEffect,
            command="DrawShaderEffect",
            reason="shader effect intent is modeled, but shader registry execution is not implemented yet",
          ),
        )
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
