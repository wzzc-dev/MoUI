///|
pub fn[Msg] toast(
  message : String,
  tone? : FeedbackTone = FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : FeedbackStyle,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone~,
    action~,
    theme~,
    style~,
    width~,
    title="",
    height=52.0,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] toast_stack(
  items : Array[ToastStackItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  style? : FeedbackStyle,
  width? : Double = 360.0,
  spacing? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  if items.length() == 0 {
    empty()
  } else {
    let style = resolve_feedback_style(style, theme)
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(toast_stack_row(item, theme~, style~, width~, spacing~))
    }
    column(rows, spacing~, align=CrossAlign::Stretch)
    .semantics_role(@core.SemanticsRole::Group)
    .accessibility_label("Toast stack")
  }
}

///|
pub fn[Msg] snackbar(
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  style? : FeedbackStyle,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let style = resolve_feedback_style(style, theme)
  feedback_surface(
    message,
    tone=FeedbackTone::Neutral,
    action~,
    theme~,
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
  style~ : FeedbackStyle,
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
            width=views_max_double(120.0, width - dismiss_width - spacing),
          ),
          button(
            "Dismiss",
            on_click=message,
            variant=ButtonVariant::Ghost,
            theme~,
            width=dismiss_width,
            height=36.0,
          ).semantics_dismiss_action(),
        ],
        spacing~,
        align=CrossAlign::Center,
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
