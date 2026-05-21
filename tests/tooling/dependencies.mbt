///|
pub fn tooling_dependencies_available() -> Bool {
  let color = @core.Color::black()
  let shaders = @render.builtin_shader_names()
  let options = @pixelmatch.Options::default()
  let expected = @quickcheck.Expected::Success
  color == @core.Color::black() &&
  shaders.length() > 0 &&
  options.threshold >= 0.0 &&
  expected is @quickcheck.Expected::Success
}
