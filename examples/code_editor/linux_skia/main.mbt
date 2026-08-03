///|
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@code_editor.program(),
    width=1180.0,
    height=760.0,
  )
  runtime.set_action_commands(@code_editor.code_editor_action_command_map())
  @moui.run_app("MoUI Code Editor", runtime)
  .render_all(@render_skia.from_env())
  .backend(@linux_backend.entry())
  .run()
}
