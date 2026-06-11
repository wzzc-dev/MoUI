///|
pub fn tooling_dependencies_available() -> Bool {
  let color = @core.Color::black()
  let shaders = @render.builtin_shader_names()
  let options = @pixelmatch.Options::default()
  let quickcheck_report = @quickcheck.quick_check_silence(true, max_success=1)
  color == @core.Color::black() &&
  shaders.length() > 0 &&
  options.threshold >= 0.0 &&
  quickcheck_report.length() > 0
}
