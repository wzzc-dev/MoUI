///|
fn main {
  @linux_wgpu_backend.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
}
