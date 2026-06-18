///|
pub fn[Msg] alert(
  title : String,
  message : String,
  primary_action~ : StateViewAction[Msg],
  secondary_action? : StateViewAction[Msg]? = None,
  tone? : FeedbackTone = FeedbackTone::Info,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let feedback_style = FeedbackStyle::default(theme~)
  let content_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let actions : Array[@core.View[Msg]] = []
  match secondary_action {
    Some(action) =>
      actions.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=104.0,
          height=36.0,
        ),
      )
    None => ()
  }
  actions.push(
    button(
      primary_action.label,
      on_click=primary_action.message,
      variant=ButtonVariant::Primary,
      theme~,
      width=104.0,
      height=36.0,
    ),
  )
  container(
    column(
      [
        text(
          title,
          role=TextRole::Control,
          theme~,
          width=content_width,
          height=28.0,
        ).foreground(feedback_accent(tone, feedback_style)),
        text(
          message,
          role=TextRole::Caption,
          theme~,
          width=content_width,
          height=54.0,
        ),
        row(
          actions,
          spacing=theme.spacing_scale.sm,
          justify=MainAlign::End,
          align=CrossAlign::Center,
        ).frame(width=content_width, height=40.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=CrossAlign::Start,
    ),
    width~,
    height=158.0,
    variant=ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(
    dialog_border(theme, accent=Some(feedback_accent(tone, feedback_style))),
  )
  .shadow(theme.shadow_scale.lg)
  .semantics_role(@core.SemanticsRole::Dialog)
  .accessibility_label(title)
}
