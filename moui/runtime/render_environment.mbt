///|
priv struct RenderEnvironment {
  environment : Environment
  style : ViewStyle
  font : FontSpec?
  foreground : Color?
  corner_radius : Double?
  text_system : TextSystem
  enabled : Bool
  scale_factor : Double
  text_scale : Double
  locale : String
  layout_direction : LayoutDirection
  accessibility_contrast : AccessibilityContrast
  reduced_motion : Bool
  content_size_category : ContentSizeCategory
  /// Current animation clock time in ms. 0.0 means "no clock active" (e.g. the
  /// intrinsic-size layout path), which makes transition progress clamp to the
  /// terminal state so non-animated paint is unchanged. Non-zero only during a
  /// real paint pass driven by `FrameTick`.
  now_ms : Double
}

///|
fn RenderEnvironment::from_environment(
  environment : Environment,
) -> RenderEnvironment {
  {
    environment,
    style: ViewStyle::empty(),
    font: None,
    foreground: None,
    corner_radius: None,
    text_system: TextSystem::fallback(),
    enabled: environment.enabled,
    scale_factor: environment.scale_factor,
    text_scale: environment.text_scale,
    locale: environment.locale,
    layout_direction: environment.layout_direction,
    accessibility_contrast: environment.accessibility_contrast,
    reduced_motion: environment.reduced_motion,
    content_size_category: environment.content_size_category,
    now_ms: 0.0,
  }
}

///|
fn RenderEnvironment::with_text_system(
  self : RenderEnvironment,
  text_system : TextSystem,
) -> RenderEnvironment {
  { ..self, text_system, }
}

///|
fn RenderEnvironment::with_child_context(
  self : RenderEnvironment,
  data : &RuntimeViewNode,
) -> RenderEnvironment {
  let environment = data.child_environment(self.environment)
  let style = data.child_style(self.style)
  {
    ..self,
    environment,
    style,
    enabled: environment.enabled,
    scale_factor: environment.scale_factor,
    text_scale: environment.text_scale,
    locale: environment.locale,
    layout_direction: environment.layout_direction,
    accessibility_contrast: environment.accessibility_contrast,
    reduced_motion: environment.reduced_motion,
    content_size_category: environment.content_size_category,
  }
}

///|
fn RenderEnvironment::with_now_ms(
  self : RenderEnvironment,
  now_ms : Double,
) -> RenderEnvironment {
  { ..self, now_ms, }
}

///|
fn RenderEnvironment::matches_default_cache_key(
  self : RenderEnvironment,
) -> Bool {
  self.environment == Environment::neutral() &&
  self.style == ViewStyle::empty() &&
  self.font is None &&
  self.foreground is None &&
  self.corner_radius is None &&
  self.text_system.id() == TextSystem::fallback().id() &&
  self.enabled &&
  self.scale_factor == 1.0 &&
  self.text_scale == 1.0 &&
  self.locale == "en-US" &&
  self.layout_direction == LayoutDirection::LeftToRight &&
  self.accessibility_contrast == AccessibilityContrast::Standard &&
  !self.reduced_motion &&
  self.content_size_category == ContentSizeCategory::Medium &&
  self.now_ms == 0.0
}

///|
fn render_environment_to_view_environment(
  environment : RenderEnvironment,
) -> Environment {
  environment.environment
}
