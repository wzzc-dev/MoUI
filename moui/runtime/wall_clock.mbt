///|
/// A local civil-time snapshot supplied by a platform host.
///
/// `weekday` follows the host calendar convention: Sunday is `0` and Saturday
/// is `6`. It is an instantaneous value rather than a timer; applications that
/// need updates should pair it with an app-facing `@services.TimerSource`
/// subscription supplied by the composition root.
pub(all) struct HostWallClock {
  year : Int
  month : Int
  day : Int
  weekday : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug, ToJson)

///|
pub fn HostWallClock::new(
  year : Int,
  month : Int,
  day : Int,
  weekday : Int,
  hour : Int,
  minute : Int,
  second? : Int = 0,
) -> HostWallClock {
  { year, month, day, weekday, hour, minute, second }
}
