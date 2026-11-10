///|
fn main {
  @apphost.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program_with_dev_state(),
      width=520.0,
      height=360.0,
      state_transport=match @native_services.dev_state_transport_path() {
        Some(path) => Some(@native_services.dev_state_transport(path))
        None => None
      },
      transient_transport=match
        @native_services.dev_transient_transport_path() {
        Some(path) => Some(@native_services.dev_transient_transport(path))
        None => None
      },
    ),
  )
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
}
