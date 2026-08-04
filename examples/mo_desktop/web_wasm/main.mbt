///|
fn main {
  @runtime.run_app(
    "Mo Desktop",
    @runtime.new_program_with_dimensions(
      program=@mo_desktop_app.program(
        wallpaper_source="assets/tahoe-day.jpg",
        environment=@web.app_environment(),
        wall_clock=web_desktop_clock,
      ),
      width=1280.0,
      height=800.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}

///|
fn web_desktop_clock() -> @mo_desktop_app.DesktopClock {
  let clock = @web.web_wall_clock()
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
