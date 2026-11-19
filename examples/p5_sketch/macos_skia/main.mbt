///|
/// Runs on the async runtime so `https:` images can be fetched without
/// blocking the window pump. Sketches inherit the loader through the default
/// fetcher installed before the program creates them.
async fn main {
  let loader = @p5_http.RemoteImageLoader::new()
  @p5.set_default_image_fetcher(Some(loader.fetcher()))
  // The p5 addon carries no filesystem dependency; the host injects it here.
  @p5.set_default_file_ports(
    @p5.FilePorts::new(
      load=fn(path) { Some(@fs.read_file_to_bytes(path)) catch { _ => None } },
      save=fn(path, bytes) {
        try {
          @fs.write_bytes_to_file(path, bytes)
          true
        } catch {
          _ => false
        }
      },
    ),
  )
  @p5_skia_raster.install()
  let runtime = @runtime.new_program_with_dimensions(
    program=@p5_app.program(),
    width=1000.0,
    height=720.0,
  )
  let window_task : async () -> Unit = async fn() {
    @apphost.run_app("MoUI p5 Sketch", runtime)
    .render_all(@render_skia.from_env(platform=MacOS))
    .backend(@macos.entry())
    .run_async_pump()
  }
  @p5_http.with_loader(loader, window=window_task) catch {
    err => println("p5 sketch exited with error: \{err}")
  }
}
