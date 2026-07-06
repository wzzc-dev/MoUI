///|
test "sickle theme exposes light dark and modes" {
  assert_true(light_theme().scheme == @core.ColorScheme::Light)
  assert_true(dark_theme().scheme == @core.ColorScheme::Dark)
  assert_true(skeuo_theme().components.surface.raised_shadow is Some(_))
  assert_true(flat_theme().components.surface.raised_shadow == None)
  assert_true(hybrid_theme().components.surface.overlay_shadow is Some(_))
  assert_true(SickleStyleMode::Hybrid.label() == "hybrid")
}

///|
test "sickle combines skeuomorphic surfaces with flat semantic controls" {
  let theme = light_theme()
  assert_true(theme.palette.primary == color_byte(r=185, g=36, b=34))
  assert_true(theme.components.button.primary.border_width == 1.0)
  assert_true(theme.components.button.ghost.background.a == 0.0)
  assert_true(theme.components.text_field.focused.inner_focus_border is Some(_))
  assert_true(theme.components.slider.thumb_shape == @core.ThumbShape::Circle)
  assert_true(theme.surfaces.raised is @core.Brush::LinearGradient(_))
}

///|
test "sickle flat mode removes depth while preserving brand tokens" {
  let theme = flat_theme()
  assert_true(theme.palette.primary == color_byte(r=185, g=36, b=34))
  assert_true(theme.components.button.primary.border_width == 0.0)
  assert_true(theme.components.surface.base_shadow == None)
  assert_true(theme.surfaces.raised is @core.Brush::Solid(_))
  assert_true(theme.motion.normal_ms == 120.0)
}

///|
fn color_byte(r~ : Int, g~ : Int, b~ : Int, a? : Double = 1.0) -> @core.Color {
  @core.Color::rgba(
    r=r.to_double() / 255.0,
    g=g.to_double() / 255.0,
    b=b.to_double() / 255.0,
    a~,
  )
}
