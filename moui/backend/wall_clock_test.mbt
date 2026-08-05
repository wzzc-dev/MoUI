///|
test "wall clock snapshots retain their civil-time fields" {
  let clock = @runtime.HostWallClock::new(2026, 7, 19, 0, 9, 41, second=23)
  inspect(clock.year, content="2026")
  inspect(clock.month, content="7")
  inspect(clock.day, content="19")
  inspect(clock.weekday, content="0")
  inspect(clock.hour, content="9")
  inspect(clock.minute, content="41")
  inspect(clock.second, content="23")
}
