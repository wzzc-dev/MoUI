///|
/// Theme selection intent. `ThemeSpec` expresses what the user *wants*
/// (preset, light/dark/system, density, contrast, seed, reduced motion); the
/// `ThemeResolver` turns a spec plus the actual system color scheme into a
/// fully resolved, drawable `Theme`. This split fixes the old
/// `Environment::with_color_scheme` bug where flipping the scheme flag did not
/// rebuild the palette/surfaces/shadows.

///|
/// Which design-system preset the user selected. `core` only resolves
/// `Minimal` itself; branded presets (Material/Carbon/Primer/Fluent) are
/// resolved by the `moui_theme` addon, which produces a complete `@core.Theme`
/// (including `components`). The enum lives in `core` so `Environment` can
/// record the user's choice without `core` depending on the addon.
pub(all) enum ThemePreset {
  Minimal
  Material
  Carbon
  Primer
  Fluent
} derive(Eq, Debug, ToJson)

///|
/// Color mode: force light, force dark, or follow the system.
pub(all) enum ColorMode {
  Light
  Dark
  System
} derive(Eq, Debug, ToJson)

///|
/// Density tier. `Compact` shrinks spacing by ~18%, `Comfortable` grows it by
/// ~18%; `Standard` is 1.0.
pub(all) enum ThemeDensity {
  Compact
  Standard
  Comfortable
} derive(Eq, Debug, ToJson)

///|
pub fn ThemeDensity::label(self : ThemeDensity) -> String {
  match self {
    Compact => "compact"
    Standard => "standard"
    Comfortable => "comfortable"
  }
}

///|
pub fn ThemeDensity::multiplier(self : ThemeDensity) -> Double {
  match self {
    Compact => 0.82
    Standard => 1.0
    Comfortable => 1.18
  }
}

///|
/// User theme intent. Built by app code (or by a branded addon helper) and
/// stored on `Environment.theme_spec`; the resolver consumes it whenever the
/// system scheme changes so a `ThemeChanged` event rebuilds the full theme.
pub(all) struct ThemeSpec {
  preset : ThemePreset
  color_mode : ColorMode
  density : ThemeDensity
  contrast : AccessibilityContrast
  // Brand seed color. `None` keeps the preset's default primary; `Some(c)`
  // overrides the primary family. `core` only applies this for `Minimal`;
  // branded addons may use it to seed their own palette generation.
  seed : Color?
  reduced_motion : Bool
} derive(Eq, Debug, ToJson)

///|
/// Default spec: MoUI Minimal, follow the system, standard density, standard
/// contrast, no seed, full motion.
pub fn ThemeSpec::default() -> ThemeSpec {
  {
    preset: ThemePreset::Minimal,
    color_mode: ColorMode::System,
    density: ThemeDensity::Standard,
    contrast: AccessibilityContrast::Standard,
    seed: None,
    reduced_motion: false,
  }
}

///|
/// Minimal-light spec (forced light, used by the legacy `light_theme()` helper).
pub fn ThemeSpec::minimal_light() -> ThemeSpec {
  { ..ThemeSpec::default(), preset: Minimal, color_mode: ColorMode::Light }
}

///|
/// Minimal-dark spec (forced dark, used by the legacy `dark_theme()` helper).
pub fn ThemeSpec::minimal_dark() -> ThemeSpec {
  { ..ThemeSpec::default(), preset: Minimal, color_mode: ColorMode::Dark }
}

///|
/// Resolve the effective color scheme for a spec given the current system
/// scheme. `System` defers to the platform; `Light`/`Dark` override it.
pub fn ThemeSpec::resolve_scheme(
  self : ThemeSpec,
  system_scheme : ColorScheme,
) -> ColorScheme {
  match self.color_mode {
    Light => Light
    Dark => Dark
    System => system_scheme
  }
}

///|
pub fn ThemeSpec::with_preset(self : ThemeSpec, preset : ThemePreset) -> ThemeSpec {
  { ..self, preset }
}

///|
pub fn ThemeSpec::with_color_mode(
  self : ThemeSpec,
  color_mode : ColorMode,
) -> ThemeSpec {
  { ..self, color_mode }
}

///|
pub fn ThemeSpec::with_density(self : ThemeSpec, density : ThemeDensity) -> ThemeSpec {
  { ..self, density }
}

///|
pub fn ThemeSpec::with_contrast(
  self : ThemeSpec,
  contrast : AccessibilityContrast,
) -> ThemeSpec {
  { ..self, contrast }
}

///|
pub fn ThemeSpec::with_seed(self : ThemeSpec, seed : Color?) -> ThemeSpec {
  { ..self, seed }
}

///|
pub fn ThemeSpec::with_reduced_motion(
  self : ThemeSpec,
  reduced_motion : Bool,
) -> ThemeSpec {
  { ..self, reduced_motion }
}
