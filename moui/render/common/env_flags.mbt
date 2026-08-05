///|
/// True when the environment variable `name` is set to exactly `"1"`.
///
/// Single shared implementation for platform-entrypoint feature switches;
/// the skia providers (macos/linux/windows) used to carry three identical
/// private copies.
pub fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}
