///|
pub struct RenderEnvironment {
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
}

///|
pub fn RenderEnvironment::from_environment(
  environment : Environment,
) -> RenderEnvironment {
  {
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
  }
}

///|
pub fn RenderEnvironment::with_text_system(
  self : RenderEnvironment,
  text_system : TextSystem,
) -> RenderEnvironment {
  { ..self, text_system, }
}

///|
pub fn RenderEnvironment::matches_default_cache_key(
  self : RenderEnvironment,
) -> Bool {
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
  self.content_size_category == ContentSizeCategory::Medium
}

///|
pub fn environment_color(
  environment : RenderEnvironment,
  fallback : Color,
) -> Color {
  let color = environment.foreground.unwrap_or(fallback)
  if environment.enabled {
    color
  } else {
    color.multiply_alpha(0.7)
  }
}

///|
pub fn environment_font(
  environment : RenderEnvironment,
  fallback : FontSpec,
) -> FontSpec {
  let font = environment.font.unwrap_or(fallback)
  if environment.text_scale == 1.0 {
    font
  } else {
    { ..font, size: font.size * environment.text_scale }
  }
}

///|
pub fn environment_measure_text(
  environment : RenderEnvironment,
  input : TextLayoutInput,
) -> TextLayoutResult {
  environment.text_system.measure_text(input)
}
