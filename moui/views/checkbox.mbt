///|
pub fn[Msg] checkbox(
  label : String,
  checked~ : Bool,
  on_change~ : (Bool) -> Msg,
  font? : @core.FontSpec = @core.Theme::default().typography.control,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
  box_size? : Double = 20.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  @core.View::controlled_checkbox(
    label~,
    checked~,
    on_change~,
    font~,
    foreground~,
    check_color~,
    size=@core.Size::new(width=box_size, height~),
  )
}

///|
pub fn[Msg] checkbox_binding(
  label : String,
  checked~ : @core.Binding[Bool],
  font? : @core.FontSpec = @core.Theme::default().typography.control,
  foreground? : @core.Color = @core.Theme::default().palette.foreground,
  check_color? : @core.Color = @core.Theme::default().palette.primary,
  box_size? : Double = 20.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  @core.View::checkbox(
    label~,
    checked~,
    font~,
    foreground~,
    check_color~,
    size=@core.Size::new(width=box_size, height~),
  )
}
