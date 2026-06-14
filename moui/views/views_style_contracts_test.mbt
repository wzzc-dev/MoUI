///|
test "theme helper customizes core theme tokens" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let motion : @core.MotionScale = {
    fast_ms: 80.0,
    normal_ms: 140.0,
    slow_ms: 220.0,
    easing: @core.Easing::EaseOut,
  }
  let theme = @views.theme(
    base=@core.Theme::dark(),
    accent~,
    spacing=14.0,
    corner_radius=10.0,
    motion~,
  )
  assert_true(theme.scheme == @core.ColorScheme::Dark)
  assert_true(theme.palette.primary == accent)
  inspect(theme.spacing_scale.sm, content="14")
  inspect(theme.radius_scale.md, content="10")
  inspect(theme.motion.normal_ms, content="140")
}

///|
test "scalar controls can resolve colors from theme" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let theme = @views.theme(accent~)
  let runtime = test_runtime(
    @views.column([
      @views.checkbox(
        "Themed checkbox",
        checked=true,
        on_change=_value => (),
        theme~,
      ),
      @views.progress(0.4, theme~, width=160.0),
      @views.slider(0.6, theme~, width=160.0),
      @views.toggle("Themed toggle", true, on_change=_value => (), theme~),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, accent))
  assert_true(has_text(draw, "Themed toggle"))
}

///|
test "picker controls can resolve surface style from theme" {
  let surface = @core.Color::rgba(r=0.14, g=0.18, b=0.24)
  let base = @core.Theme::light()
  let theme = @views.theme(
    base~,
    palette={ ..base.palette, surface, },
    corner_radius=18.0,
  )
  let items = [
    @views.picker_item("native", "Native"),
    @views.picker_item("web", "Web"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.picker(items, selected="native", on_select=_value => (), theme~),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=5, day=21),
        on_select=_value => (),
        theme~,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, surface))
}

///|
test "controls can consume neutral core style contracts" {
  let button_bg = @core.Color::rgba(r=0.72, g=0.12, b=0.36)
  let field_bg = @core.Color::rgba(r=0.10, g=0.18, b=0.26)
  let rich_field_bg = @core.Color::rgba(r=0.12, g=0.20, b=0.34)
  let progress_fg = @core.Color::rgba(r=0.18, g=0.64, b=0.38)
  let slider_thumb = @core.Color::rgba(r=0.96, g=0.68, b=0.20)
  let picker_bg = @core.Color::rgba(r=0.18, g=0.12, b=0.30)
  let date_bg = @core.Color::rgba(r=0.14, g=0.24, b=0.20)
  let button_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(button_bg),
    border: None,
    radius: 14.0,
    shadow: None,
  }
  let button_style : @core.ButtonStyle = {
    normal: button_state,
    hovered: button_state,
    pressed: button_state,
    disabled: button_state,
  }
  let field_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(field_bg),
    border: None,
    radius: 10.0,
    shadow: None,
  }
  let field_style : @core.TextFieldStyle = {
    normal: field_state,
    focused: field_state,
    disabled: field_state,
    placeholder_color: @core.Color::gray(),
    cursor_color: progress_fg,
    font: @core.FontSpec::new(size=15.0, weight=500),
  }
  let rich_field_state = {
    ..field_state,
    background: @core.Brush::solid(rich_field_bg),
  }
  let rich_field_style = {
    ..field_style,
    normal: rich_field_state,
    focused: rich_field_state,
    disabled: rich_field_state,
  }
  let progress_style : @core.ProgressStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.07, g=0.09, b=0.12),
    radius: 6.0,
  }
  let slider_style : @core.SliderStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.12, g=0.14, b=0.18),
    thumb_color: slider_thumb,
    track_height: 7.0,
    thumb_size: 18.0,
    radius: 9.0,
  }
  let picker_style : @core.PickerStyle = {
    font: @core.FontSpec::new(size=14.0, weight=600),
    foreground: @core.Color::white(),
    background: @core.Brush::solid(picker_bg),
    radius: 12.0,
    popup_max_height: 180.0,
  }
  let date_style = { ..picker_style, background: @core.Brush::solid(date_bg) }
  let items = [
    @views.picker_item("material", "Material"),
    @views.picker_item("carbon", "Carbon"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.button("Styled", on_click=(), style=button_style, width=120.0),
      @views.text_field(
        "tokens",
        on_input=_value => (),
        placeholder="Styled field",
        style=field_style,
      ),
      @views.rich_text_editor(
        "rich tokens",
        value => {
          @core.RichTextDocument::new(blocks=[
            @core.RichTextBlock::new(runs=[@core.RichTextRun::new(text=value)]),
          ])
        },
        on_input=_value => (),
        placeholder="Styled editor",
        style=rich_field_style,
        width=180.0,
        height=60.0,
      ),
      @views.progress(0.5, style=progress_style, width=160.0),
      @views.slider(0.5, style=slider_style, width=160.0),
      @views.picker(
        items,
        selected="material",
        on_select=_value => (),
        style=picker_style,
      ),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=6, day=10),
        on_select=_value => (),
        style=date_style,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, button_bg))
  assert_true(has_solid_fill(draw, field_bg))
  assert_true(has_solid_fill(draw, rich_field_bg))
  assert_true(has_solid_fill(draw, progress_fg))
  assert_true(has_solid_fill(draw, slider_thumb))
  assert_true(has_solid_fill(draw, picker_bg))
  assert_true(has_solid_fill(draw, date_bg))
}

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
