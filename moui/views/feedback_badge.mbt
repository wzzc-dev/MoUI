///|
pub fn[Msg] badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  style? : BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let style = resolve_badge_style(style, theme)
  surface(
    text(
      label,
      role=TextRole::Caption,
      theme~,
      width=width - style.padding * 2.0,
      height=height - style.padding * 2.0,
    ).foreground(badge_foreground(tone, style)),
    width~,
    height~,
    background=badge_background(tone, style),
    corner_radius=min_view_double(height / 2.0, style.radius),
    padding=style.padding,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] status_badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  detail? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  style? : BadgeStyle,
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let base = badge(label, tone~, theme~, style?, width~, height~).accessibility_label(
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
  tone? : FeedbackTone = FeedbackTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  style? : FeedbackStyle,
  width? : Double = 180.0,
  height? : Double = 116.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  let rows : Array[@core.View[Msg]] = [
    text(label, role=TextRole::Caption, theme~, width=width - 24.0, height=22.0),
    text(value, role=TextRole::Title, theme~, width=width - 24.0, height=34.0).foreground(
      feedback_accent(tone, style),
    ),
  ]
  if caption != "" {
    rows.push(
      text(
        caption,
        role=TextRole::Caption,
        theme~,
        width=width - 24.0,
        height=22.0,
      ),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn resolve_badge_style(style : BadgeStyle?, theme : @core.Theme) -> BadgeStyle {
  match style {
    Some(value) => value
    None => BadgeStyle::default(theme~)
  }
}

///|
fn badge_background(tone : BadgeTone, style : BadgeStyle) -> @core.Color {
  badge_tone_style(tone, style).background
}

///|
fn badge_foreground(tone : BadgeTone, style : BadgeStyle) -> @core.Color {
  badge_tone_style(tone, style).foreground
}

///|
fn badge_tone_style(tone : BadgeTone, style : BadgeStyle) -> ToneStyle {
  match tone {
    Neutral => style.neutral
    Accent => style.accent
    Success => style.success
    Warning => style.warning
    Danger => style.danger
  }
}
