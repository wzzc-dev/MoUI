///|
test "feedback badge and validation views consume neutral core style contracts" {
  let feedback_info_fg = @core.Color::rgba(r=0.12, g=0.44, b=0.86)
  let feedback_info_bg = @core.Color::rgba(r=0.82, g=0.91, b=1.0)
  let feedback_success_fg = @core.Color::rgba(r=0.10, g=0.56, b=0.28)
  let feedback_success_bg = @core.Color::rgba(r=0.82, g=0.96, b=0.86)
  let feedback_danger_fg = @core.Color::rgba(r=0.86, g=0.12, b=0.24)
  let feedback_danger_bg = @core.Color::rgba(r=1.0, g=0.86, b=0.88)
  let neutral_tone : @core.ToneStyle = {
    foreground: @core.Color::rgba(r=0.24, g=0.27, b=0.32),
    background: @core.Color::rgba(r=0.94, g=0.95, b=0.97),
    border: @core.Color::rgba(r=0.70, g=0.72, b=0.76),
  }
  let info_tone : @core.ToneStyle = {
    foreground: feedback_info_fg,
    background: feedback_info_bg,
    border: @core.Color::rgba(r=0.46, g=0.68, b=0.92),
  }
  let success_tone : @core.ToneStyle = {
    foreground: feedback_success_fg,
    background: feedback_success_bg,
    border: @core.Color::rgba(r=0.40, g=0.76, b=0.48),
  }
  let warning_tone : @core.ToneStyle = {
    foreground: @core.Color::rgba(r=0.62, g=0.40, b=0.08),
    background: @core.Color::rgba(r=1.0, g=0.94, b=0.78),
    border: @core.Color::rgba(r=0.86, g=0.64, b=0.22),
  }
  let danger_tone : @core.ToneStyle = {
    foreground: feedback_danger_fg,
    background: feedback_danger_bg,
    border: @core.Color::rgba(r=0.92, g=0.48, b=0.54),
  }
  let feedback_style : @core.FeedbackStyle = {
    neutral: neutral_tone,
    info: info_tone,
    success: success_tone,
    warning: warning_tone,
    danger: danger_tone,
    radius: 11.0,
    padding: 9.0,
  }
  let badge_accent_bg = @core.Color::rgba(r=0.46, g=0.18, b=0.86)
  let badge_success_bg = @core.Color::rgba(r=0.08, g=0.58, b=0.28)
  let badge_danger_bg = @core.Color::rgba(r=0.78, g=0.10, b=0.20)
  let badge_style : @core.BadgeStyle = {
    neutral: neutral_tone,
    accent: {
      foreground: @core.Color::white(),
      background: badge_accent_bg,
      border: badge_accent_bg,
    },
    success: {
      foreground: @core.Color::white(),
      background: badge_success_bg,
      border: badge_success_bg,
    },
    warning: warning_tone,
    danger: {
      foreground: @core.Color::white(),
      background: badge_danger_bg,
      border: badge_danger_bg,
    },
    radius: 12.0,
    padding: 4.0,
  }
  let validation_fg = @core.Color::rgba(r=0.72, g=0.08, b=0.34)
  let validation_bg = @core.Color::rgba(r=1.0, g=0.88, b=0.94)
  let validation_style : @core.FormValidationStyle = {
    foreground: validation_fg,
    background: validation_bg,
    border: @core.Color::rgba(r=0.90, g=0.42, b=0.62),
    radius: 10.0,
    padding: 10.0,
  }
  let runtime = test_runtime(
    @views.column([
      @views.banner(
        "Styled banner",
        "Uses custom feedback tokens",
        tone=@views.FeedbackTone::Info,
        style=feedback_style,
      ),
      @views.inline_error(
        "Styled inline error",
        style=feedback_style,
        badge_style~,
      ),
      @views.progress_status(
        "Styled progress",
        value=0.48,
        tone=@views.FeedbackTone::Success,
        style=feedback_style,
        badge_style~,
        progress_style=@core.ProgressStyle::{
          foreground: @core.Color::gray(),
          background: @core.Color::rgba(r=0.18, g=0.18, b=0.20),
          radius: 4.0,
        },
      ),
      @views.row([
        @views.badge("Accent", tone=@views.BadgeTone::Accent, style=badge_style),
        @views.status_badge(
          "Passed",
          tone=@views.BadgeTone::Success,
          style=badge_style,
        ),
      ]),
      @views.form_validation_summary(
        summary=@core.FormValidationSummary::from_errors([
          { name: "email", message: "Email required" },
        ]),
        style=validation_style,
      ),
      @views.form_error("Standalone validation", style=validation_style),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, feedback_info_bg))
  assert_true(has_solid_fill(draw, feedback_danger_bg))
  assert_true(has_solid_fill(draw, feedback_success_bg))
  assert_true(has_solid_fill(draw, feedback_success_fg))
  assert_true(has_solid_fill(draw, badge_accent_bg))
  assert_true(has_solid_fill(draw, badge_success_bg))
  assert_true(has_solid_fill(draw, badge_danger_bg))
  assert_true(has_solid_fill(draw, validation_bg))
  assert_true(has_text_color(draw, "Review required", validation_fg))
  assert_true(has_text_color(draw, "Standalone validation", validation_fg))
}
