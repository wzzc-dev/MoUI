///|
pub fn[Msg] number_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_step? : ((Double) -> Msg)? = None,
  step? : Double = 1.0,
  placeholder? : String = "0",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 220.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let control_width = match on_step {
    Some(_) => views_max_double(80.0, width - 88.0)
    None => width
  }
  let rows : Array[@core.View[Msg]] = [
    text_field(
      value,
      on_input~,
      placeholder~,
      variant~,
      theme~,
      width=control_width,
      height~,
    ),
  ]
  match on_step {
    Some(handle_step) =>
      rows.push(
        stepper(
          on_decrement=handle_step(0.0 - step),
          on_increment=handle_step(step),
          theme~,
          width=80.0,
          height~,
        ),
      )
    None => ()
  }
  row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center).frame(
    width~,
  )
}

///|
pub fn[Msg] stepper(
  on_decrement~ : Msg,
  on_increment~ : Msg,
  label? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 140.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    button(
      "-",
      on_click=on_decrement,
      variant=ButtonVariant::Outline,
      theme~,
      width=36.0,
      height~,
    ),
  ]
  if label != "" {
    rows.push(
      text(
        label,
        role=TextRole::Control,
        theme~,
        width=views_max_double(24.0, width - 80.0),
        height~,
      ),
    )
  }
  rows.push(
    button(
      "+",
      on_click=on_increment,
      variant=ButtonVariant::Outline,
      theme~,
      width=36.0,
      height~,
    ),
  )
  row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center).frame(
    width~,
    height~,
  )
}
