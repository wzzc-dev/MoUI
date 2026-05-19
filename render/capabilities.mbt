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
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu renders rect fills and strokes as visual pipeline quads.",
      web_note: "Web wasm-gc forwards rect commands to the browser WebGPU host.",
    },
    {
      feature: RendererFeature::RoundedRect,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu renders rounded fills and strokes with shader SDF geometry.",
      web_note: "Web wasm-gc forwards rounded rect commands to the browser WebGPU host.",
    },
    {
      feature: RendererFeature::Gradient,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu evaluates linear gradients in the visual shader.",
      web_note: "Web wasm-gc forwards solid and gradient brush payloads to the host.",
    },
    {
      feature: RendererFeature::Shadow,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu renders soft rounded shadows as visual shader primitives.",
      web_note: "Web wasm-gc forwards shadow payloads to the host.",
    },
    {
      feature: RendererFeature::Text,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu uses shaped glyphs and a glyph-atlas text pipeline.",
      web_note: "Web wasm-gc forwards text runs to the browser WebGPU host.",
    },
    {
      feature: RendererFeature::Image,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu currently emits an image placeholder visual item; source decode, upload, and sampling remain follow-up work.",
      web_note: "Web wasm-gc forwards image source, frame, and opacity to the host.",
    },
    {
      feature: RendererFeature::Clip,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu maps rectangular clips to scissor rectangles; rounded clips and mask stacks remain follow-up work.",
      web_note: "Web wasm-gc forwards push/pop clip commands to the host.",
    },
    {
      feature: RendererFeature::Transform,
      native_status: RendererFeatureStatus::Partial,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu folds transforms into planned vertices; scissor uses transformed bounding boxes and richer render-pass transform state remains follow-up work.",
      web_note: "Web wasm-gc forwards affine transform stack commands to the host.",
    },
    {
      feature: RendererFeature::Opacity,
      native_status: RendererFeatureStatus::Ready,
      web_status: RendererFeatureStatus::HostForwarded,
      native_note: "Native wgpu folds opacity into visual and text vertex alpha.",
      web_note: "Web wasm-gc forwards push/pop opacity commands to the host.",
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
