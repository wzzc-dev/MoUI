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
