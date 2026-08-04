///|
fn main {
  let runtime = @markdown_editor.runtime(
    environment=@web.app_environment(),
    width=1200.0,
  )
  @runtime.run_app("MoUI Markdown Editor", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
