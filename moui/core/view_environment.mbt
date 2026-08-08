///|
/// Immutable environment snapshot passed to an application's Program view.
pub struct ViewEnvironment {
  viewport_size : Size
  environment : Environment
}

///|
pub fn ViewEnvironment::new(
  viewport_size~ : Size,
  environment~ : Environment,
) -> ViewEnvironment {
  { viewport_size, environment }
}

///|
pub fn ViewEnvironment::viewport_size(self : ViewEnvironment) -> Size {
  self.viewport_size
}

///|
pub fn ViewEnvironment::environment(self : ViewEnvironment) -> Environment {
  self.environment
}
