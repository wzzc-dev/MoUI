///|
fn host_test_text_field(
  value : String,
  width? : Double = 240.0,
  height? : Double = 40.0,
  outlined? : Bool = false,
) -> @core.View[String] {
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
  @views.text_field(
    value,
    on_input=next => next,
    placeholder="Type",
    style=field_style,
    width~,
    height~,
  )
}

///|
fn window_test_text_field_runtime(
  value~ : Ref[String],
  size~ : @core.Size,
  width? : Double = 240.0,
  height? : Double = 40.0,
  outlined? : Bool = false,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=value.val,
      update=(_model, next) => {
        value.val = next
        next
      },
      view=model => {
        @views.column(
          [host_test_text_field(model, width~, height~, outlined~)],
          spacing=0.0,
          justify=@views.MainAlign::Start,
          align=@views.CrossAlign::Start,
        )
      },
    ),
    size~,
  )
}
