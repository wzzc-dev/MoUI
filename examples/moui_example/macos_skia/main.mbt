fn main {
  @macos_skia_backend.run_app(
    "MoUI Quick Example",
    @runtime.new_program_with_dimensions(
      program=@moui_example_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
}
