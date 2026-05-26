///|
test "theme exposes light and dark token palettes" {
  let light = Theme::light()
  let dark = Theme::dark()
  assert_true(light.scheme == ColorScheme::Light)
  assert_true(dark.scheme == ColorScheme::Dark)
  assert_true(light.palette.background != dark.palette.background)
  assert_true(light.foreground == light.palette.foreground)
  assert_true(dark.background == dark.palette.background)
}

///|
test "theme token builders preserve compatibility fields" {
  let spacing = SpacingScale::{ xs: 2.0, sm: 6.0, md: 10.0, lg: 14.0, xl: 20.0 }
  let radius = RadiusScale::{ sm: 3.0, md: 7.0, lg: 11.0, pill: 999.0 }
  let theme = Theme::light()
    .with_spacing_scale(spacing)
    .with_radius_scale(radius)
    .with_accent(Color::gray())
  inspect(theme.spacing, content="6")
  inspect(theme.corner_radius, content="7")
  assert_true(theme.accent == Color::gray())
  assert_true(theme.palette.primary == Color::gray())
}

///|
test "environment tracks theme color scheme" {
  let environment = Environment::default().with_theme(Theme::dark())
  assert_true(environment.color_scheme == ColorScheme::Dark)
  assert_true(environment.theme.scheme == ColorScheme::Dark)
}

///|
test "environment carries accessibility and internationalization signals" {
  let environment = Environment::default()
    .with_locale("ar-SA")
    .with_layout_direction(LayoutDirection::RightToLeft)
    .with_accessibility_contrast(AccessibilityContrast::High)
    .with_reduced_motion(true)
    .with_content_size_category(ContentSizeCategory::Accessibility)
  inspect(environment.locale, content="ar-SA")
  assert_true(environment.layout_direction == LayoutDirection::RightToLeft)
  assert_true(environment.accessibility_contrast == AccessibilityContrast::High)
  inspect(environment.reduced_motion, content="true")
  assert_true(
    environment.content_size_category == ContentSizeCategory::Accessibility,
  )
  inspect(environment.text_scale, content="1.6")
}

///|
test "theme environment propagates through build context and render scale" {
  let environment = Environment::default()
    .with_theme(Theme::dark())
    .with_locale("zh-CN")
    .with_content_size_category(ContentSizeCategory::ExtraLarge)
    .with_layout_direction(LayoutDirection::RightToLeft)
    .with_accessibility_contrast(AccessibilityContrast::High)
    .with_reduced_motion(true)
  let seen_rtl = Ref(false)
  let seen_high_contrast = Ref(false)
  let seen_extra_large = Ref(false)
  let seen_reduced_motion = Ref(false)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let theme = ctx.theme()
      seen_rtl.val = ctx.layout_direction() == LayoutDirection::RightToLeft
      seen_high_contrast.val = ctx.accessibility_contrast() ==
        AccessibilityContrast::High
      seen_extra_large.val = ctx.content_size_category() ==
        ContentSizeCategory::ExtraLarge
      seen_reduced_motion.val = ctx.reduced_motion()
      ViewSpec::TextSpec({
        key: None,
        text: ctx.locale(),
        size: Size::new(width=160.0, height=40.0),
        font: FontSpec::new(size=10.0, weight=400),
        color: theme.foreground,
      })
    }),
    size=Size::new(width=160.0, height=40.0),
    environment~,
  )
  assert_true(seen_rtl.val)
  assert_true(seen_high_contrast.val)
  assert_true(seen_extra_large.val)
  assert_true(seen_reduced_motion.val)
  let first = runtime.build_draw_commands()
  guard first[1]
    is DrawText(
      { text: "zh-CN", font: { size: 13.0, .. }, color: color_first, .. }
    ) else {
    fail("expected environment-driven text")
  }
  assert_true(color_first == Theme::dark().foreground)
  runtime.set_environment(
    Environment::default().with_theme(Theme::light()).with_locale("fr-FR"),
  )
  let second = runtime.build_draw_commands()
  guard second[1]
    is DrawText(
      { text: "fr-FR", font: { size: 10.0, .. }, color: color_second, .. }
    ) else {
    fail("expected updated environment")
  }
  assert_true(color_second == Theme::light().foreground)
}
