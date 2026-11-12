///|
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@counter_app.program_with_dev_state(),
    width=520.0,
    height=360.0,
    state_transport=match @native_services.dev_state_transport_path() {
      Some(path) => Some(@native_services.dev_state_transport(path))
      None => None
    },
    transient_transport=match @native_services.dev_transient_transport_path() {
      Some(path) => Some(@native_services.dev_transient_transport(path))
      None => None
    },
  )
  match @devtools_socket.devtools_port_file_path() {
    Some(port_file) =>
      @devtools_socket.install_devtools_socket(
        runtime,
        port_file~,
        file_path=@devtools_publish.devtools_file_path(),
      )
    None =>
      match @devtools_publish.devtools_file_path() {
        Some(path) =>
          @devtools_publish.install_devtools_publisher(runtime, path~)
        None => ()
      }
  }
  @apphost.run_app("MoUI Counter", runtime)
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
}
