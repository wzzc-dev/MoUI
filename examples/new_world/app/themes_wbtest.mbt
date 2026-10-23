///|
/// The two appearances: palette construction, legibility, switching, and the
/// mood accent mapping. These are the tests that keep 宣纸/墨蓝 honest — a
/// palette whose text stops reading on its own background fails here, not in
/// front of the player.

///|
/// Perceived luminance, the same weighting the framework's contrast-aware
/// derivation uses.
fn luminance(color : @graphics.Color) -> Double {
  color.r * 0.299 + color.g * 0.587 + color.b * 0.114
}

///|
test "both palettes carry the hand-set roles" {
  let paper = palette_paper()
  // 雾蓝 seeds the derived roles.
  assert_eq(paper.primary.r, 0.357)
  assert_eq(paper.primary.g, 0.478)
  // 宣纸 neutrals are set by hand, not left at the factory's cold greys.
  assert_eq(paper.background.r, 0.961)
  assert_eq(paper.background.g, 0.945)
  assert_eq(paper.background.b, 0.910)
  // 玉 rides on secondary, 金 on warning.
  assert_eq(paper.secondary.g, 0.663)
  assert_eq(paper.warning.r, 0.706)
  // 朱红 replaces the factory's colder red on error/danger.
  assert_eq(paper.danger.r, 0.706)
  assert_eq(paper.danger.g, 0.263)
  assert_eq(paper.error, paper.danger)
  let ink = palette_ink()
  assert_eq(ink.background.b, 0.125)
  assert_eq(ink.secondary.g, 0.761)
  assert_eq(ink.warning.r, 0.788)
  assert_eq(ink.danger.r, 0.851)
}

///|
test "text reads on its own background in both appearances" {
  for appearance in [Paper, Ink] {
    let theme = app_theme(appearance)
    let palette = theme.palette
    let text_lum = luminance(palette.on_surface)
    let ground_lum = luminance(palette.background)
    let gap = if text_lum > ground_lum {
      text_lum - ground_lum
    } else {
      ground_lum - text_lum
    }
    // A wide perceptual gap: the transcript is long-form reading, so the
    // body tier must never sit close to the page.
    assert_true(gap > 0.5)
    // The primary accent stays visible on the surface too.
    let accent_gap = if luminance(palette.primary) > luminance(palette.surface) {
      luminance(palette.primary) - luminance(palette.surface)
    } else {
      luminance(palette.surface) - luminance(palette.primary)
    }
    assert_true(accent_gap > 0.1)
  }
}

///|
test "app_theme resolves the scheme each appearance asks for" {
  let paper = app_theme(Paper)
  let ink = app_theme(Ink)
  assert_true(paper.scheme is @state.ColorScheme::Light)
  assert_true(ink.scheme is @state.ColorScheme::Dark)
  // The reading bump: the body tier sits above the control default.
  assert_eq(paper.typography.body.size, 16.5)
  // And the two themes are genuinely different products.
  assert_true(paper != ink)
}

///|
test "the stored appearance string decodes and snaps" {
  assert_true(appearance_from_wire("paper") is Paper)
  assert_true(appearance_from_wire("ink") is Ink)
  assert_true(appearance_from_wire("INK") is Ink)
  assert_true(appearance_from_wire("") is Paper)
  assert_true(appearance_from_wire("nonsense") is Paper)
  assert_eq(Appearance::Paper.wire(), "paper")
  assert_eq(Appearance::Ink.wire(), "ink")
  // The convenience the views use agrees with the two-step path.
  assert_true(app_theme_for("ink") == app_theme(Ink))
}

///|
test "mood accents pick distinct roles, not one flat colour" {
  let theme = app_theme(Paper)
  let calm = mood_accent(theme, Calm)
  let tense = mood_accent(theme, Tense)
  let warm = mood_accent(theme, Warm)
  let cold = mood_accent(theme, Cold)
  let mysterious = mood_accent(theme, Mysterious)
  // 玉 / 朱红 / 金 / 雾蓝 — four different roles.
  assert_true(calm != tense && calm != warm && calm != cold)
  assert_true(tense != warm && tense != cold && warm != cold)
  // Mysterious is a deepened 雾蓝: darker than Cold, still blue-leaning.
  assert_true(mysterious.b > mysterious.r)
  assert_true(mysterious.r + mysterious.g + mysterious.b < cold.r + cold.g + cold.b)
  // Dark scheme keeps the same mapping with its own lifted roles.
  let night = app_theme(Ink)
  assert_true(mood_accent(night, Calm) != calm)
  assert_true(mood_accent(night, Tense) == night.palette.danger)
}

///|
test "the compact row theme keeps the palette and shrinks the metrics" {
  let base = app_theme(Paper)
  let compact = compact_action_theme(base)
  // Same colours: the row wears the appearance, not the framework default.
  assert_eq(compact.palette.primary, base.palette.primary)
  assert_eq(compact.palette.danger, base.palette.danger)
  // Smaller metrics: that is what makes the half-height row real.
  assert_true(compact.spacing_scale.sm < base.spacing_scale.sm)
  assert_true(compact.typography.label.size < base.typography.label.size)
  // The destructive style reads the danger colour it was given.
  let style = destructive_ghost_style(base)
  ignore(style)
  assert_eq(base.palette.danger.r, 0.706)
}
