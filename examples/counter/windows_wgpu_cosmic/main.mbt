///|
fn main {
  @moui.run_app(
    "MoUI Counter App",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
  .render(@render_wgpu.native(text_engine=@wgpu_cosmic.cosmic_text_engine()))
  .backend(@windows_backend.entry())
  .run()
}
