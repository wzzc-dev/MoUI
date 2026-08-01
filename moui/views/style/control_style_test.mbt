///|
/// Regression guard: after the style-unification, every legacy `XStyle::default`
/// constructor must project from `ControlThemeSet` (the single compute source).
/// Any future divergence between the two sources fails these assertions.
test "legacy_style_defaults_match_control_theme_set" {
  let theme = @core.Theme::neutral()
  let set = views_ambient_control_theme(theme)

  let surface = SurfaceStyle::default(theme~)
  assert_eq(surface.radius, set.surface.base_radius)

  let choice = ChoiceControlStyle::default(theme~)
  assert_eq(choice.foreground, set.choice_control.foreground)
  assert_eq(choice.selected_color, set.choice_control.selected_color)
  assert_eq(choice.control_size, set.choice_control.control_size)

  let progress = ProgressStyle::default(theme~)
  assert_eq(progress.foreground, set.progress.foreground)
  assert_eq(progress.background, set.progress.background)

  // The track fill once diverged (legacy used surface_variant * 0.7); keep it aligned.
  let slider = SliderStyle::default(theme~)
  assert_eq(slider.foreground, set.slider.foreground)
  assert_eq(slider.background, set.slider.background)
  assert_eq(slider.thumb_size, set.slider.thumb_size)

  let picker = PickerStyle::default(theme~)
  assert_eq(picker.font, set.picker.font)
  assert_eq(picker.radius, set.picker.radius)

  let feedback = FeedbackStyle::default(theme~)
  assert_eq(feedback.neutral.foreground, set.feedback.neutral.foreground)
  assert_eq(feedback.neutral.background, set.feedback.neutral.background)
  assert_eq(feedback.info.foreground, set.feedback.info.foreground)

  // The badge accent foreground once diverged (legacy used white); keep it aligned.
  let badge = BadgeStyle::default(theme~)
  assert_eq(badge.accent.foreground, set.badge.accent.foreground)
  assert_eq(badge.accent.background, set.badge.accent.background)
  assert_eq(badge.success.foreground, set.badge.success.foreground)

  let fv = FormValidationStyle::default(theme~)
  assert_eq(fv.foreground, set.form_validation.foreground)
  assert_eq(fv.background, set.form_validation.background)
}
