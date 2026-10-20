///|
pub fn tooling_dependencies_available() -> Bool {
  let color = @core.Color::black()
  let shaders = @render_common.builtin_shader_names()
  let options = @pixelmatch.Options::default()
  // `quick_check_silence` raises on a failing property; a raise means the
  // dependency is present but the probe property failed, which still counts as
  // "available" — only an unresolvable dependency should make this false.
  let quickcheck_report = @quickcheck.quick_check_silence(
    true,
    max_success=1,
  ) catch {
    Failure(_) => "ran-with-failure"
  }
  color == @core.Color::black() &&
  shaders.length() > 0 &&
  options.threshold >= 0.0 &&
  quickcheck_report.length() > 0
}
