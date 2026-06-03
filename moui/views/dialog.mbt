///|
pub fn[Msg] alert(
  title : String,
  message : String,
  primary_action~ : StateViewAction[Msg],
  secondary_action? : StateViewAction[Msg]? = None,
  tone? : FeedbackTone = FeedbackTone::Info,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
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
  surface(
    column(
      [
        text(
          title,
          role=TextRole::Control,
          theme~,
          width=content_width,
          height=28.0,
        ).foreground(feedback_accent(tone, theme)),
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
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(dialog_border(theme, accent=Some(feedback_accent(tone, theme))))
  .shadow(theme.shadow_scale.lg)
  .semantics_role(@core.SemanticsRole::Dialog)
  .accessibility_label(title)
}

///|
pub fn[Msg] dialog(
  title : String,
  content~ : @core.View[Msg],
  subtitle? : String = "",
  primary_action? : StateViewAction[Msg]? = None,
  secondary_action? : StateViewAction[Msg]? = None,
  dismiss_action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
  height? : Double = 240.0,
) -> @core.View[Msg] {
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
          width=dialog_action_width(action.label),
          height=36.0,
        ),
      )
    None => ()
  }
  match primary_action {
    Some(action) =>
      actions.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Primary,
          theme~,
          width=dialog_action_width(action.label),
          height=36.0,
        ),
      )
    None => ()
  }
  let body_rows : Array[@core.View[Msg]] = [
    dialog_header(
      title,
      subtitle~,
      dismiss_action~,
      theme~,
      width=content_width,
    ),
    content.frame(width=content_width),
  ]
  if actions.length() > 0 {
    body_rows.push(
      row(
        actions,
        spacing=theme.spacing_scale.sm,
        justify=MainAlign::End,
        align=CrossAlign::Center,
      ).frame(width=content_width, height=40.0),
    )
  }
  surface(
    column(body_rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(dialog_border(theme))
  .shadow(theme.shadow_scale.lg)
  .semantics_role(@core.SemanticsRole::Dialog)
  .semantics_description(subtitle)
  .accessibility_label(title)
}

///|
fn dialog_border(
  theme : @core.Theme,
  accent? : @core.Color? = None,
) -> @core.BorderStyle {
  let color = match accent {
    Some(color) => color.multiply_alpha(0.84)
    None => theme.palette.outline
  }
  @core.BorderStyle::new(brush=@core.Brush::solid(color), width=1.5)
}

///|
fn[Msg] dialog_header(
  title : String,
  subtitle~ : String,
  dismiss_action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let title_width = match dismiss_action {
    Some(action) =>
      views_max_double(
        80.0,
        width - dialog_action_width(action.label) - theme.spacing_scale.sm,
      )
    None => width
  }
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=title_width, height=28.0),
  ]
  if subtitle != "" {
    rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
        width=title_width,
        height=24.0,
      ),
    )
  }
  let title_block = column(
    rows,
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Start,
  )
  match dismiss_action {
    Some(action) =>
      row(
        [
          title_block,
          button(
            action.label,
            on_click=action.message,
            variant=ButtonVariant::Ghost,
            theme~,
            width=dialog_action_width(action.label),
            height=34.0,
          ).semantics_dismiss_action(),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Start,
      ).frame(width~)
    None => title_block.frame(width~)
  }
}

///|
fn dialog_action_width(label : String) -> Double {
  views_max_double(82.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
