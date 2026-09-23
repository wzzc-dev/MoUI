///|
test "sickle theme exposes light dark and modes" {
  assert_true(@sickle.light_theme().scheme == Light)
  assert_true(@sickle.dark_theme().scheme == Dark)
  let skeuo_components = @sickle.control_theme_set(scheme=Light, mode=Skeuo)
  let flat_components = @sickle.control_theme_set(scheme=Light, mode=Flat)
  let hybrid_components = @sickle.control_theme_set(scheme=Light, mode=Hybrid)
  assert_true(skeuo_components.surface.raised_shadow is Some(_))
  assert_true(flat_components.surface.raised_shadow == None)
  assert_true(hybrid_components.surface.overlay_shadow is Some(_))
  assert_true(@sickle.SickleStyleMode::Hybrid.label() == "hybrid")
  ignore(@sickle.skeuo_theme())
}

///|
test "sickle combines skeuomorphic surfaces with flat semantic controls" {
  let theme = @sickle.light_theme()
  let components = @sickle.control_theme_set(scheme=Light, mode=Hybrid)
  assert_true(theme.palette.primary == color_byte(r=185, g=36, b=34))
  assert_true(components.button.primary.border_width == 1.0)
  assert_true(components.button.ghost.background.a == 0.0)
  assert_true(components.text_field.focused.inner_focus_border is Some(_))
  assert_true(components.slider.thumb_shape == Circle)
  assert_true(theme.surfaces.raised is LinearGradient(_))
}

///|
test "sickle flat mode removes depth while preserving brand tokens" {
  let theme = @sickle.flat_theme()
  let components = @sickle.control_theme_set(scheme=Light, mode=Flat)
  assert_true(theme.palette.primary == color_byte(r=185, g=36, b=34))
  assert_true(components.button.primary.border_width == 0.0)
  assert_true(components.surface.base_shadow == None)
  assert_true(theme.surfaces.raised is Solid(_))
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
