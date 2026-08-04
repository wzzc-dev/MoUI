///|
fn macos_desktop_clock() -> @mo_desktop_app.DesktopClock {
  let clock = @macos_backend.macos_wall_clock()
  @mo_desktop_app.DesktopClock::new(
    clock.year,
    clock.month,
    clock.day,
    clock.weekday,
    clock.hour,
    clock.minute,
    second=clock.second,
  )
}
