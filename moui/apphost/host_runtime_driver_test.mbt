///|
test "accent color host event rebuilds the desktop environment accent" {
  let environment = @core.Environment::neutral().with_theme_spec(
    @core.ThemeSpec::default().with_preset(@core.Desktop),
  )
  let root : @core.View[Unit] = @views.text("accent")
  let runtime : @runtime.AppRuntime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=80.0),
    environment~,
    on_message=Option::None,
  )
  let driver = @apphost.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let accent = @core.Color::from_argb(0xFF3366CCU)
  ignore(driver.dispatch(@backend_host.Event::AccentColorChanged(0xFF3366CCU)))
  let updated = runtime.environment()
  assert_true(updated.system_accent == Some(accent))
  assert_true(updated.theme.palette.primary == accent)
}
