///|
fn main {
  @moui.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
  .render(
    @render_wgpu.native(
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_coretext.coretext_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@macos_backend.entry())
  .run()
}
