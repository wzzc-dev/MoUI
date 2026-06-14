///|
pub type AppRuntime = @core.AppRuntime

///|
pub fn[Msg] new_view(
  root~ : @core.View[Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> AppRuntime {
  @core.AppRuntime::new_view(root~, size~, environment~, on_message~)
}

///|
pub fn[Model, Msg] new_program(
  program~ : @core.Program[Model, Msg],
  size~ : @core.Size,
  environment? : @core.Environment = @core.Environment::default(),
) -> AppRuntime {
  @core.AppRuntime::new_program(program~, size~, environment~)
}
