///|
fn main {
  let controls = @services.WindowControlSource::new()
  let queue = @backend_common.WindowRequestQueue::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=@demo.program(controls),
    width=960.0,
    height=620.0,
  )
  @apphost.run_app("MoUI Chrome Demo", runtime)
  .render(@render_sun.raster())
  .window_requests(queue.requests())
  .backend(
    @linux.entry(
      options=@linux.LinuxHostAppOptions::new(window_controls=Some(controls)),
    ),
  )
  .run()
}
