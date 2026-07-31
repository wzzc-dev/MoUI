///|
pub fn[Msg] toast(
  message : String,
  tone? : @style.FeedbackTone = @style.FeedbackTone::Neutral,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  feedback_panel(
    message,
    tone~,
    action~,
    theme=resolved_theme,
    style~,
    width~,
    title="",
    height=52.0,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] toast_stack(
  items : Array[ToastStackItem[Msg]],
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 360.0,
  spacing? : Double = @style.default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  if items.length() == 0 {
    @container.empty()
  } else {
    let style = resolve_feedback_style(style, resolved_theme)
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(
        toast_stack_row(item, theme=resolved_theme, style~, width~, spacing~),
      )
    }
    column(rows, spacing~, align=@style.CrossAlign::Stretch)
    .semantics_role(@core.SemanticsRole::Group)
    .accessibility_label("Toast stack")
  }
}

///|
pub fn[Msg] snackbar(
  message : String,
  action? : @controls.StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  style? : @style.FeedbackStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let style = resolve_feedback_style(style, resolved_theme)
  feedback_panel(
    message,
    tone=@style.FeedbackTone::Neutral,
    action~,
    theme=resolved_theme,
    style~,
    width~,
    title="",
    height=56.0,
  )
}

///|
fn[Msg] toast_stack_row(
  item : ToastStackItem[Msg],
  theme~ : @core.Theme,
  style~ : @style.FeedbackStyle,
  width~ : Double,
  spacing~ : Double,
) -> @core.View[Msg] {
  match item.dismiss {
    Some(message) => {
      let dismiss_width = 86.0
      row(
        [
          toast(
            item.message,
            tone=item.tone,
            action=item.action,
            theme~,
            style~,
            width=@common.max_view_double(
              120.0,
              width - dismiss_width - spacing,
            ),
          ),
          @controls.semantic_dismiss_action_control(
            @button.button(
              "Dismiss",
              on_click=message,
              variant=@style.ButtonVariant::Ghost,
              theme~,
              width=dismiss_width,
              height=36.0,
            ),
            message,
          ),
        ],
        spacing~,
        align=@style.CrossAlign::Center,
      ).frame(width~, height=52.0)
    }
    None =>
      toast(
        item.message,
        tone=item.tone,
        action=item.action,
        theme~,
        style~,
        width~,
      )
  }
}
