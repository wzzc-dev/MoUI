///|
// Desktop preset regression guards. Minimal keeps its 0.6.x metrics; Desktop
// is the new opt-in preset that moves type sizes, radii, control heights and
// elevation together. Keep these assertions numeric: the numbers are the
// contract README screenshots and `docs/design-metrics.md` refer to.

///|
test "desktop preset resolves brand accent and compact metrics" {
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light(),
    @core.Light,
  )
  assert_true(theme.scheme == @core.Light)
  assert_true(
    theme.palette.primary ==
    @core.Color::rgba(r=29.0 / 255.0, g=111.0 / 255.0, b=224.0 / 255.0),
  )
  assert_eq(theme.layout_scale.control_height, 32.0)
  assert_eq(theme.layout_scale.control_padding_x, 12.0)
  assert_eq(theme.layout_scale.row_height, 30.0)
  assert_eq(theme.layout_scale.card_padding, 16.0)
  assert_eq(theme.layout_scale.overlay_padding, 8.0)
  assert_eq(theme.layout_scale.dialog_padding, 20.0)
  assert_eq(theme.radius_scale.md, 8.0)
  assert_eq(theme.radius_scale.lg, 12.0)
  assert_eq(theme.typography.body.size, 14.0)
  assert_eq(theme.typography.title.size, 18.0)
  assert_eq(theme.typography.label.weight, 550)
  assert_eq(theme.typography.body.line_height, Some(20.3))
  assert_eq(theme.typography.title.line_height, Some(23.4))
  assert_eq(theme.shadow_scale.sm.blur_radius, 2.0)
  assert_eq(theme.shadow_scale.lg.blur_radius, 32.0)
}

///|
test "minimal preset keeps legacy metrics unchanged" {
  let theme = @core.resolve_minimal_theme(
    @core.ThemeSpec::minimal_light(),
    @core.Light,
  )
  assert_eq(theme.layout_scale.control_height, 40.0)
  assert_eq(theme.layout_scale.control_padding_x, 16.0)
  assert_eq(theme.layout_scale.row_height, 34.0)
  assert_eq(theme.layout_scale.card_padding, 24.0)
  assert_eq(theme.layout_scale.overlay_padding, 12.0)
  assert_eq(theme.radius_scale.md, 6.0)
  assert_eq(theme.typography.body.size, 16.0)
}

///|
test "resolve_theme dispatches by preset" {
  let desktop = @core.resolve_theme(
    @core.ThemeSpec::desktop_dark(),
    @core.Light,
  )
  assert_true(desktop.scheme == @core.Dark)
  assert_eq(desktop.layout_scale.control_height, 32.0)
  let minimal = @core.resolve_theme(
    @core.ThemeSpec::minimal_dark(),
    @core.Light,
  )
  assert_true(minimal.scheme == @core.Dark)
  assert_eq(minimal.layout_scale.control_height, 40.0)
  // A branded preset that reaches core without its addon falls back to
  // Minimal instead of failing to render.
  let branded = @core.resolve_theme(
    @core.ThemeSpec::default().with_preset(@core.Fluent),
    @core.Light,
  )
  assert_eq(branded.layout_scale.control_height, 40.0)
}

///|
test "desktop density scales layout metrics" {
  let compact = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_density(@core.Compact),
    @core.Light,
  )
  assert_true(compact.layout_scale.control_height < 32.0)
  assert_true(compact.layout_scale.card_padding < 16.0)
  let comfortable = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_density(@core.Comfortable),
    @core.Light,
  )
  assert_true(comfortable.layout_scale.control_height > 32.0)
}

///|
test "desktop seed overrides the fallback accent" {
  let seed = @core.Color::rgba(r=0.1, g=0.6, b=0.3)
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_seed(Some(seed)),
    @core.Light,
  )
  assert_true(theme.palette.primary == seed)
}

///|
test "desktop reduced motion zeroes the motion scale" {
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_reduced_motion(true),
    @core.Light,
  )
  assert_eq(theme.motion.fast_ms, 0.0)
  assert_eq(theme.motion.normal_ms, 0.0)
  assert_eq(theme.motion.slow_ms, 0.0)
}

///|
test "desktop dark primary carries readable on-color" {
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_dark(),
    @core.Light,
  )
  // The dark accent is bright enough that the palette derivation picks a
  // near-black label, keeping filled-button text at AA contrast.
  let on_primary = theme.palette.on_primary
  assert_true(on_primary.r < 0.2)
  assert_true(on_primary.g < 0.2)
  assert_true(on_primary.b < 0.2)
}

///|
test "desktop high contrast still snaps surfaces" {
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_contrast(@core.High),
    @core.Light,
  )
  assert_true(theme.palette.background == @core.Color::white())
  assert_true(theme.palette.foreground == @core.Color::black())
}

///|
test "desktop preset uses the host accent when the app has no seed" {
  let accent = @core.Color::rgba(r=0.9, g=0.2, b=0.1)
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light(),
    @core.Light,
    system_accent=accent,
  )
  assert_true(theme.palette.primary == accent)
  // The accent derivation still picks a readable on-color.
  assert_true(theme.palette.on_primary == @core.Color::white())
}

///|
test "app seed wins over the host accent" {
  let app_seed = @core.Color::rgba(r=0.1, g=0.6, b=0.3)
  let host_accent = @core.Color::rgba(r=0.9, g=0.2, b=0.1)
  let theme = @core.resolve_desktop_theme(
    @core.ThemeSpec::desktop_light().with_seed(Some(app_seed)),
    @core.Light,
    system_accent=host_accent,
  )
  assert_true(theme.palette.primary == app_seed)
}

///|
test "minimal ignores the host accent" {
  let host_accent = @core.Color::rgba(r=0.9, g=0.2, b=0.1)
  let theme = @core.resolve_theme_with_accent(
    @core.ThemeSpec::minimal_light(),
    @core.Light,
    Some(host_accent),
  )
  assert_true(
    theme.palette.primary == @core.Color::rgba(r=0.145, g=0.145, b=0.149),
  )
}

///|
test "environment accent rebuilds and survives scheme changes" {
  let accent = @core.Color::rgba(r=0.2, g=0.4, b=0.9)
  let environment = @core.Environment::neutral()
    .with_theme_spec(@core.ThemeSpec::default().with_preset(@core.Desktop))
    .with_system_accent(Some(accent))
  assert_true(environment.theme.palette.primary == accent)
  let dark = environment.with_system_scheme(@core.Dark)
  assert_true(dark.theme.palette.primary == accent)
  assert_true(dark.theme.scheme == @core.Dark)
  let cleared = dark.with_system_accent(Option::None)
  assert_true(
    cleared.theme.palette.primary ==
    @core.Color::rgba(r=96.0 / 255.0, g=165.0 / 255.0, b=250.0 / 255.0),
  )
}

///|
test "color from argb decodes 0xAARRGGBB" {
  let color = @core.Color::from_argb(0xFF3366CCU)
  assert_true((color.r - 51.0 / 255.0).abs() < 0.000001)
  assert_true((color.g - 102.0 / 255.0).abs() < 0.000001)
  assert_true((color.b - 204.0 / 255.0).abs() < 0.000001)
  assert_eq(color.a, 1.0)
}
