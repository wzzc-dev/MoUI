///|
priv struct RenderEnvironment {
  environment : Environment
  /// Interned identity of `environment`. Paint caches compare this integer
  /// instead of the full theme-bearing environment value.
  environment_id : Int32
  style : ViewStyle
  font : FontSpec?
  foreground : Color?
  corner_radius : Double?
  text_system : TextSystem
  reduced_motion : Bool
  /// Current animation clock time in ms. 0.0 means "no clock active" (e.g. the
  /// intrinsic-size layout path), which makes transition progress clamp to the
  /// terminal state so non-animated paint is unchanged. Non-zero only during a
  /// real paint pass driven by `FrameTick`.
  now_ms : Double
}

///|
fn RenderEnvironment::from_environment(
  environment : Environment,
) -> RenderEnvironment {
  {
    environment,
    environment_id: environment_identity(environment),
    style: ViewStyle::empty(),
    font: None,
    foreground: None,
    corner_radius: None,
    text_system: TextSystem::fallback(),
    reduced_motion: environment.reduced_motion,
    now_ms: 0.0,
  }
}

///|
fn RenderEnvironment::with_text_system(
  self : RenderEnvironment,
  text_system : TextSystem,
) -> RenderEnvironment {
  { ..self, text_system, }
}

///|
fn RenderEnvironment::with_child_context(
  self : RenderEnvironment,
  environment : Environment,
  style : ViewStyle,
  environment_id : Int32,
) -> RenderEnvironment {
  {
    ..self,
    environment,
    environment_id,
    style,
    reduced_motion: environment.reduced_motion,
  }
}

///|
fn RenderEnvironment::with_now_ms(
  self : RenderEnvironment,
  now_ms : Double,
) -> RenderEnvironment {
  { ..self, now_ms, }
}

///|
fn render_environment_to_view_environment(
  environment : RenderEnvironment,
) -> Environment {
  environment.environment
}
