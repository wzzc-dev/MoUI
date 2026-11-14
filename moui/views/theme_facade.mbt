///|
/// Theme facade additions kept out of `views.mbt` (line budget): the Desktop
/// preset, the resolver-driven spec helpers, and the size-only layout scale.
/// `views.mbt` keeps the long-standing Minimal re-exports unchanged.
pub using @style {
  type LayoutScale,
  type ThemeSpec,
  type ThemePreset,
  desktop_light_theme,
  desktop_dark_theme,
  minimal_theme_spec,
  desktop_theme_spec,
  theme_from_spec,
}
