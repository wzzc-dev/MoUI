///|
pub fn[Msg] badge(
  label : String,
  tone? : @style.BadgeTone = @style.BadgeTone::Neutral,
  theme? : @core.Theme,
  style? : @style.BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_badge_style(style, resolved_theme)
  @container.container(
    @text.text(
      label,
      role=@style.TextRole::Caption,
      theme=resolved_theme,
      width=width - style.padding * 2.0,
      height=height - style.padding * 2.0,
    ).foreground(badge_foreground(tone, style)),
    width~,
    height~,
    background=badge_background(tone, style),
    corner_radius=@common.min_view_double(height / 2.0, style.radius),
    padding=style.padding,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] status_badge(
  label : String,
  tone? : @style.BadgeTone = @style.BadgeTone::Neutral,
  detail? : String = "",
  theme? : @core.Theme,
  style? : @style.BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let base = badge(label, tone~, theme=resolved_theme, style?, width~, height~).accessibility_label(
    "Status: " + label,
  )
  if detail == "" {
    base
  } else {
    base.semantics_description(detail)
  }
}

///|
pub fn[Msg] stat_card(
  label : String,
  value : String,
  caption? : String = "",
  tone? : @style.FeedbackTone = @style.FeedbackTone::Neutral,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 180.0,
  height? : Double = 116.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      label,
      role=@style.TextRole::Caption,
      theme=resolved_theme,
      width=width - 24.0,
      height=22.0,
    ),
    @text.text(
      value,
      role=@style.TextRole::Title,
      theme=resolved_theme,
      width=width - 24.0,
      height=34.0,
    ).foreground(@controls.feedback_accent(tone, style)),
  ]
  if caption != "" {
    rows.push(
      @text.text(
        caption,
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=width - 24.0,
        height=22.0,
      ),
    )
  }
  @container.container(
    column(
      rows,
      spacing=resolved_theme.spacing_scale.xs,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Raised,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
}

///|
fn resolve_badge_style(
  style : @style.BadgeStyle?,
  theme : @core.Theme,
) -> @style.BadgeStyle {
  match style {
    Some(value) => value
    None => @style.BadgeStyle::default(theme~)
  }
}

///|
fn badge_background(
  tone : @style.BadgeTone,
  style : @style.BadgeStyle,
) -> @core.Color {
  badge_tone_style(tone, style).background
}

///|
fn badge_foreground(
  tone : @style.BadgeTone,
  style : @style.BadgeStyle,
) -> @core.Color {
  badge_tone_style(tone, style).foreground
}

///|
fn badge_tone_style(
  tone : @style.BadgeTone,
  style : @style.BadgeStyle,
) -> @style.ToneStyle {
  match tone {
    Neutral => style.neutral
    Accent => style.accent
    Success => style.success
    Warning => style.warning
    Danger => style.danger
  }
}
