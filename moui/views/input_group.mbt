///|
pub fn[Msg] input_group(
  child~ : @core.View[Msg],
  prefix? : @core.View[Msg]? = None,
  suffix? : @core.View[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  height? : Double = 44.0,
  padding? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  match prefix {
    Some(view) => rows.push(view)
    None => ()
  }
  rows.push(child.expanded())
  match suffix {
    Some(view) => rows.push(view)
    None => ()
  }
  surface(
    row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding~,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.74)),
      width=1.0,
    ),
  )
}

///|
pub fn[Msg] clearable_text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_clear~ : Msg,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  row(
    [
      text_field(
        value,
        on_input~,
        placeholder~,
        variant~,
        theme~,
        width=views_max_double(80.0, width - 72.0),
        height~,
      ),
      button(
        "Clear",
        on_click=on_clear,
        variant=ButtonVariant::Ghost,
        theme~,
        width=64.0,
        height~,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
}

///|
pub fn[Msg] password_field(
  value : String,
  on_input~ : (String) -> Msg,
  revealed~ : Bool,
  on_toggle_reveal~ : Msg,
  placeholder? : String = "Password",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let display_value = if revealed { value } else { mask_text(value) }
  row(
    [
      text_field(
        display_value,
        on_input~,
        placeholder~,
        variant~,
        theme~,
        width=views_max_double(80.0, width - 72.0),
        height~,
      ),
      button(
        if revealed { "Hide" } else { "Show" },
        on_click=on_toggle_reveal,
        variant=ButtonVariant::Ghost,
        theme~,
        width=64.0,
        height~,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
}

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
  row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center).frame(width~)
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
    button("-", on_click=on_decrement, variant=ButtonVariant::Outline, theme~, width=36.0, height~),
  ]
  if label != "" {
    rows.push(
      text(label, role=TextRole::Control, theme~, width=views_max_double(24.0, width - 80.0), height~),
    )
  }
  rows.push(
    button("+", on_click=on_increment, variant=ButtonVariant::Outline, theme~, width=36.0, height~),
  )
  row(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Center).frame(width~, height~)
}

///|
pub fn[Msg] multiline_text_area_shell(
  value : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  lines? : Int = 4,
  variant? : TextFieldVariant = TextFieldVariant::Outline,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  line_height? : Double = 28.0,
) -> @core.View[Msg] {
  text_field(
    value,
    on_input~,
    placeholder~,
    variant~,
    theme~,
    width~,
    height=views_max_double(line_height, lines.to_double() * line_height),
  )
  .accessibility_label("Multiline text area")
}

///|
fn mask_text(value : String) -> String {
  let mut masked = ""
  for _ in value {
    masked = masked + "*"
  }
  masked
}
