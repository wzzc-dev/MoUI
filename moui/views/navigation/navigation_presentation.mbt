///|
pub fn[Msg] wizard_step(step : WizardStep[Msg]) -> @core.View[Msg] {
  step.content
}

///|
pub fn[Msg] wizard(
  steps : Array[WizardStep[Msg]],
  current~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 260.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let header_width = @common.view_max_double(
    120.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let step_count = wizard_visible_step_count(steps.length())
  let step_width = @common.view_max_double(
    88.0,
    header_width / step_count.to_double() - 4.0,
  )
  let step_buttons : Array[@core.View[Msg]] = []
  let mut content = @container.empty()
  for step in steps {
    if step.id == current {
      content = wizard_step(step)
    }
    let variant = if step.id == current {
      @style.ButtonVariant::Primary
    } else {
      @style.ButtonVariant::Tonal
    }
    step_buttons.push(
      @button.button(
        step.title,
        on_click=on_select(step.id),
        variant~,
        theme=resolved_theme,
        width=step_width,
        height=36.0,
      )
      .disabled(disabled=!step.enabled)
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=step.id == current),
    )
  }
  @container.container(
    @layout.column(
      [
        @layout.row(
          step_buttons,
          spacing=resolved_theme.spacing_scale.xs,
          align=@style.CrossAlign::Center,
        ),
        content.frame(width=header_width, height=height - 74.0),
      ],
      spacing=resolved_theme.spacing_scale.md,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Raised,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn wizard_visible_step_count(count : Int) -> Int {
  if count > 1 {
    count
  } else {
    1
  }
}
