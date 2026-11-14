///|
// Desktop preset control-token guards. The values below are what
// `docs/design-metrics.md` documents and what the gallery screenshots show.

///|
fn desktop_theme_test_light() -> @core.Theme {
  @core.resolve_desktop_theme(@core.ThemeSpec::desktop_light(), @core.Light)
}

///|
fn desktop_theme_test_dark() -> @core.Theme {
  @core.resolve_desktop_theme(@core.ThemeSpec::desktop_dark(), @core.Dark)
}

///|
test "desktop control set tracks layout scale and elevation" {
  let theme = desktop_theme_test_light()
  let set = @style.views_ambient_control_theme(theme)
  assert_eq(set.surface.raised_padding, 16.0)
  assert_eq(set.surface.overlay_padding, 8.0)
  assert_eq(set.surface.raised_radius, 12.0)
  assert_eq(set.surface.overlay_radius, 12.0)
  assert_true(set.surface.raised_shadow is Some(_))
  assert_true(set.surface.overlay_shadow is Some(_))
  // Control radii follow the Desktop radius scale.
  assert_eq(set.button.primary.radius, 8.0)
  assert_eq(set.text_field.normal.radius, 8.0)
  assert_eq(set.text_field.font.size, 14.0)
}

///|
test "desktop control set keeps minimal metrics unchanged" {
  let theme = @core.Theme::neutral()
  let set = @style.views_ambient_control_theme(theme)
  assert_eq(set.surface.raised_padding, 24.0)
  assert_eq(set.surface.overlay_padding, 12.0)
  assert_eq(set.button.primary.radius, 6.0)
  assert_eq(set.text_field.font.size, 16.0)
}

///|
test "state layers tint with the foreground, not the brand color" {
  let theme = desktop_theme_test_light()
  let set = @style.views_ambient_control_theme(theme)
  assert_true(set.button.state_layer.color == theme.palette.foreground)
  assert_eq(set.button.state_layer.hover_alpha, 0.06)
  assert_eq(set.button.state_layer.pressed_alpha, 0.10)
}

///|
test "desktop dark control set keeps the same metrics" {
  let light = @style.views_ambient_control_theme(desktop_theme_test_light())
  let dark = @style.views_ambient_control_theme(desktop_theme_test_dark())
  assert_eq(dark.surface.raised_padding, light.surface.raised_padding)
  assert_eq(dark.button.primary.radius, light.button.primary.radius)
  assert_true(dark.surface.overlay_shadow is Some(_))
}
