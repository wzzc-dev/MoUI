///|
pub fn[Msg] alert(
  title : String,
  message : String,
  primary_action~ : StateViewAction[Msg],
  secondary_action? : StateViewAction[Msg]? = None,
  tone? : @style.FeedbackTone = @style.FeedbackTone::Info,
  theme? : @core.Theme,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let feedback_style = @style.FeedbackStyle::default(theme=resolved_theme)
  let content_width = @common.view_max_double(
    120.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let actions : Array[@core.View[Msg]] = []
  match secondary_action {
    Some(action) =>
      actions.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Ghost,
          theme=resolved_theme,
          width=104.0,
          height=36.0,
        ),
      )
    None => ()
  }
  actions.push(
    @button.button(
      primary_action.label,
      on_click=primary_action.message,
      variant=@style.ButtonVariant::Primary,
      theme=resolved_theme,
      width=104.0,
      height=36.0,
    ),
  )
  @container.container(
    column(
      [
        @text.text(
          title,
          role=@style.TextRole::Control,
          theme=resolved_theme,
          width=content_width,
          height=28.0,
        ).foreground(feedback_accent(tone, feedback_style)),
        @text.text(
          message,
          role=@style.TextRole::Caption,
          theme=resolved_theme,
          width=content_width,
          height=54.0,
        ),
        row(
          actions,
          spacing=resolved_theme.spacing_scale.sm,
          justify=@style.MainAlign::End,
          align=@style.CrossAlign::Center,
        ).frame(width=content_width, height=40.0),
      ],
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height=158.0,
    variant=@style.ContainerVariant::Raised,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  .border(
    dialog_border(
      resolved_theme,
      accent=Some(feedback_accent(tone, feedback_style)),
    ),
  )
  .shadow(resolved_theme.shadow_scale.lg)
  .semantics_role(@core.SemanticsRole::Dialog)
  .accessibility_label(title)
}
