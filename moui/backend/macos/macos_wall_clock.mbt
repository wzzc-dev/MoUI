///|
extern "C" fn macos_wall_clock_year() -> Int = "moui_macos_wall_clock_year"

///|
extern "C" fn macos_wall_clock_month() -> Int = "moui_macos_wall_clock_month"

///|
extern "C" fn macos_wall_clock_day() -> Int = "moui_macos_wall_clock_day"

///|
extern "C" fn macos_wall_clock_weekday() -> Int = "moui_macos_wall_clock_weekday"

///|
extern "C" fn macos_wall_clock_hour() -> Int = "moui_macos_wall_clock_hour"

///|
extern "C" fn macos_wall_clock_minute() -> Int = "moui_macos_wall_clock_minute"

///|
extern "C" fn macos_wall_clock_second() -> Int = "moui_macos_wall_clock_second"

///|
/// Read the local civil time using the host's native clock.
pub fn macos_wall_clock() -> @host.HostWallClock {
  @host.HostWallClock::new(
    macos_wall_clock_year(),
    macos_wall_clock_month(),
    macos_wall_clock_day(),
    macos_wall_clock_weekday(),
    macos_wall_clock_hour(),
    macos_wall_clock_minute(),
    second=macos_wall_clock_second(),
  )
}
