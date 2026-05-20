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
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Gap,
      native_note: "Layer-level offscreen composition, masks, and retained render-pass state are not modeled yet.",
      web_note: "The browser runtime does not expose offscreen layer composition beyond per-command vertices yet.",
    },
    {
      feature: RendererFeature::BlendMode,
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Gap,
      native_note: "Blend mode intent is not represented in DrawCommand payloads yet.",
      web_note: "Blend mode intent is not represented in the wasm-gc command stream yet.",
    },
    {
      feature: RendererFeature::FilterEffect,
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Gap,
      native_note: "Blur, color matrix, and backdrop filters are not represented in renderer-neutral commands yet.",
      web_note: "Browser WebGPU filters are not represented in renderer-neutral commands yet.",
    },
    {
      feature: RendererFeature::PathVector,
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Gap,
      native_note: "Arbitrary path/vector draw commands are not modeled yet.",
      web_note: "Arbitrary path/vector draw commands are not modeled yet.",
    },
    {
      feature: RendererFeature::ShaderEffect,
      native_status: RendererFeatureStatus::Gap,
      web_status: RendererFeatureStatus::Gap,
      native_note: "User shader effects are not part of the renderer facade yet.",
      web_note: "User shader effects are not part of the browser host import ABI yet.",
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
      native_note: "Images are cached after decode, but async loading state and resource lifecycle APIs remain follow-up work.",
      web_note: "Images load asynchronously in the browser runtime, but loading/error state is not surfaced to app code yet.",
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
