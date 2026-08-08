///|
fn host_test_text_field(
  value : String,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[String] {
  let normal = @views.new_control_state_style(
    foreground=@core.Color::black(),
    background=@core.Brush::solid(@core.Color::white()),
    radius=0.0,
  )
  let field_style = @views.TextFieldStyle::new(
    normal~,
    focused=normal,
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
          [host_test_text_field(model, width~, height~)],
          spacing=0.0,
          justify=@views.MainAlign::Start,
          align=@views.CrossAlign::Start,
        )
      },
    ),
    size~,
  )
}
