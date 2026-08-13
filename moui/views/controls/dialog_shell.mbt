///|
pub fn[Msg] dialog(
  title : String,
  content~ : @core.View[Msg],
  subtitle? : String = "",
  primary_action? : StateViewAction[Msg]? = None,
  secondary_action? : StateViewAction[Msg]? = None,
  dismiss_action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme,
  width? : Double = 432.0,
  height? : Double = 280.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let panel_padding = resolved_theme.spacing_scale.lg
  let section_spacing = resolved_theme.spacing_scale.md
  let content_width = @common.view_max_double(
    180.0,
    width - panel_padding * 2.0,
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
          width=dialog_action_width(action.label),
          height=36.0,
        ),
      )
    None => ()
  }
  match primary_action {
    Some(action) =>
      actions.push(
        @button.button(
          action.label,
          on_click=action.message,
          variant=@style.ButtonVariant::Primary,
          theme=resolved_theme,
          width=dialog_action_width(action.label),
          height=36.0,
        ),
      )
    None => ()
  }
  let header_height = if subtitle == "" { 36.0 } else { 62.0 }
  let footer_height = if actions.length() > 0 { 48.0 } else { 0.0 }
  let section_count = if actions.length() > 0 { 2.0 } else { 1.0 }
  let body_height = @common.view_max_double(
    56.0,
    height -
    panel_padding * 2.0 -
    header_height -
    footer_height -
    section_spacing * section_count,
  )
  let body_rows : Array[@core.View[Msg]] = [
    dialog_header(
      title,
      subtitle~,
      dismiss_action~,
      theme=resolved_theme,
      width=content_width,
      height=header_height,
    ),
    content.frame(width=content_width, height=body_height),
  ]
  if actions.length() > 0 {
    body_rows.push(
      @layout.row(
        actions,
        spacing=resolved_theme.spacing_scale.sm,
        justify=@style.MainAlign::End,
        align=@style.CrossAlign::Center,
      ).frame(width=content_width, height=footer_height),
    )
  }
  let dialog_view = @container.container(
      @layout.column(
        body_rows,
        spacing=section_spacing,
        align=@style.CrossAlign::Start,
      ),
      width~,
      height~,
      variant=@style.ContainerVariant::Raised,
      theme=resolved_theme,
      padding=panel_padding,
    )
    .border(dialog_border(resolved_theme))
    .shadow(resolved_theme.shadow_scale.lg)
    .semantics_role(@core.SemanticsRole::Dialog)
    .semantics_description(subtitle)
    .accessibility_label(title)
  match dismiss_action {
    Some(action) =>
      semantic_dismiss_action_control(
        dialog_view,
        action.message,
        role=Some(@core.SemanticsRole::Dialog),
      )
    None => dialog_view
  }
}

///|
fn dialog_border(
  theme : @core.Theme,
  accent? : @core.Color? = None,
) -> @core.BorderStyle {
  let color = match accent {
    Some(color) => color.multiply_alpha(0.72)
    None => theme.palette.outline.multiply_alpha(0.66)
  }
  @core.BorderStyle::new(brush=@core.Brush::solid(color), width=1.0)
}

///|
fn[Msg] dialog_header(
  title : String,
  subtitle~ : String,
  dismiss_action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
  height~ : Double,
) -> @core.View[Msg] {
  let title_width = match dismiss_action {
    Some(action) =>
      @common.view_max_double(
        80.0,
        width -
        dialog_dismiss_action_width(action.label) -
        theme.spacing_scale.md,
      )
    None => width
  }
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme~,
      width=title_width,
      height=28.0,
    ),
  ]
  if subtitle != "" {
    rows.push(
      @text.text(
        subtitle,
        role=@style.TextRole::Caption,
        theme~,
        width=title_width,
        height=24.0,
      ),
    )
  }
  let title_block = @layout.column(
    rows,
    spacing=theme.spacing_scale.xs,
    align=@style.CrossAlign::Start,
  )
  match dismiss_action {
    Some(action) =>
      @layout.row(
        [
          title_block.frame(width=title_width, height~),
          semantic_dismiss_action_control(
            @button.button(
              action.label,
              on_click=action.message,
              variant=@style.ButtonVariant::Ghost,
              theme~,
              width=dialog_dismiss_action_width(action.label),
              height=32.0,
            ),
            action.message,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@style.CrossAlign::Start,
      ).frame(width~, height~)
    None => title_block.frame(width~, height~)
  }
}

///|
fn dialog_action_width(label : String) -> Double {
  @common.view_max_double(
    82.0,
    label.to_array().length().to_double() * 8.0 + 24.0,
  )
}

///|
fn dialog_dismiss_action_width(label : String) -> Double {
  @common.view_max_double(
    72.0,
    label.to_array().length().to_double() * 7.0 + 20.0,
  )
}
