///|
fn host_test_text_field(
  value : @core.State[String],
  width? : Double = 240.0,
  height? : Double = 40.0,
  outlined? : Bool = false,
) -> @core.View[Unit] {
  let normal_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::gray()),
        width=1.0,
      ),
    )
  } else {
    None
  }
  let focused_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::blue()),
        width=2.0,
      ),
    )
  } else {
    None
  }
  let normal = @views.new_control_state_style(
    foreground=@core.Color::black(),
    background=@core.Brush::solid(@core.Color::white()),
    border?=normal_border,
    radius=0.0,
  )
  let focused = @views.new_control_state_style(
    foreground=@core.Color::black(),
    background=@core.Brush::solid(@core.Color::white()),
    border?=focused_border,
    radius=0.0,
  )
  let field_style = @views.TextFieldStyle::new(
    normal~,
    focused~,
    disabled=normal,
    placeholder_color=@core.Color::gray(),
    cursor_color=@core.Color::blue(),
    font=@core.FontSpec::new(size=16.0, weight=400),
  )
  @views.component(ctx => {
    @views.text_field(
      ctx.watch(value),
      on_input=next => value.set(next),
      placeholder="Type",
      style=field_style,
      width~,
      height~,
    )
  })
}
