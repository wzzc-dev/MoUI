///|
pub fn[Msg] wizard_step(step : WizardStep[Msg]) -> @core.View[Msg] {
  step.content
}

///|
pub fn[Msg] wizard(
  steps : Array[WizardStep[Msg]],
  current~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 260.0,
) -> @core.View[Msg] {
  let header_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let step_count = wizard_visible_step_count(steps.length())
  let step_width = views_max_double(
    88.0,
    header_width / step_count.to_double() - 4.0,
  )
  let step_buttons : Array[@core.View[Msg]] = []
  let mut content = empty()
  for step in steps {
    if step.id == current {
      content = wizard_step(step)
    }
    let variant = if step.id == current {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Tonal
    }
    step_buttons.push(
      button(
        step.title,
        on_click=on_select(step.id),
        variant~,
        theme~,
        width=step_width,
        height=36.0,
      )
      .disabled(disabled=!step.enabled)
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=step.id == current),
    )
  }
  surface(
    column(
      [
        row(
          step_buttons,
          spacing=theme.spacing_scale.xs,
          align=CrossAlign::Center,
        ),
        content.frame(width=header_width, height=height - 74.0),
      ],
      spacing=theme.spacing_scale.md,
      align=CrossAlign::Start,
    ),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] dialog_host(
  child : @core.View[Msg],
  dialog? : @core.View[Msg]? = None,
  presented? : Bool = false,
  trap_focus? : Bool = true,
) -> @core.View[Msg] {
  if presented {
    match dialog {
      Some(dialog) => {
        let scrim = modal_scrim(alpha=0.22)
        let presented_dialog = dialog
          .semantics_role(@core.SemanticsRole::Dialog)
          .align(alignment=@core.Alignment::center())
        let presented_dialog = if trap_focus {
          presented_dialog.focus_trap()
        } else {
          presented_dialog
        }
        stack([child, scrim, presented_dialog])
      }
      None => child
    }
  } else {
    child
  }
}

///|
fn wizard_visible_step_count(count : Int) -> Int {
  if count > 1 {
    count
  } else {
    1
  }
}
