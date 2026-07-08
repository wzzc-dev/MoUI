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
  Supported
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
pub struct RendererCommandFallback {
  priv index : Int
  priv feature : RendererFeature
  priv command : String
  priv kind : RendererCommandFallbackKind
  priv reason : String
} derive(Eq, Debug, ToJson)

///|
pub struct RendererCommandPlan {
  priv total_commands : Int
  priv fallback_count : Int
  priv final_layer_depth : Int
  priv final_filter_depth : Int
  priv fallbacks : Array[RendererCommandFallback]
} derive(Eq, Debug, ToJson)

///|
pub fn RendererCommandFallback::index(self : RendererCommandFallback) -> Int {
  self.index
}

///|
pub fn RendererCommandFallback::feature(
  self : RendererCommandFallback,
) -> RendererFeature {
  self.feature
}

///|
pub fn RendererCommandFallback::command(
  self : RendererCommandFallback,
) -> String {
  self.command
}

///|
pub fn RendererCommandFallback::kind(
  self : RendererCommandFallback,
) -> RendererCommandFallbackKind {
  self.kind
}

///|
pub fn RendererCommandFallback::reason(
  self : RendererCommandFallback,
) -> String {
  self.reason
}

///|
pub fn RendererCommandPlan::total_commands(self : RendererCommandPlan) -> Int {
  self.total_commands
}

///|
pub fn RendererCommandPlan::fallback_count(self : RendererCommandPlan) -> Int {
  self.fallback_count
}

///|
pub fn RendererCommandPlan::final_layer_depth(
  self : RendererCommandPlan,
) -> Int {
  self.final_layer_depth
}

///|
pub fn RendererCommandPlan::final_filter_depth(
  self : RendererCommandPlan,
) -> Int {
  self.final_filter_depth
}

///|
pub fn RendererCommandPlan::fallbacks(
  self : RendererCommandPlan,
) -> Array[RendererCommandFallback] {
  self.fallbacks
}

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
    Supported => "supported"
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
    Supported | HostForwarded => false
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
