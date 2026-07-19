///|
/// Platform entrypoint: application program and renderer configuration only.
/// The iOS backend installs runtime callbacks; `moui_shell/embedding` owns the
/// ABI implementation, and `embedding_exports.mbt` is only a linker shim.
fn install_counter_ios_embedding() -> Unit {
  @ios_host.install_embedding(
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@counter_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => {
      @ios_skia_backend.renderer_provider(
        options=@ios_skia_backend.IosSkiaAppOptions::new(
          surface_route=@ios_host.ios_shell_renderer_selection(
              gpu_available=@ios_skia_backend.ios_skia_gpu_available(),
            ).surface_route,
        ),
      )
    },
    renderer_configure=@ios_host.ios_shell_renderer_configure,
    renderer_status_json=() => {
      @ios_host.ios_shell_renderer_status_json(
        gpu_available=@ios_skia_backend.ios_skia_gpu_available(),
      )
    },
  )
}

///|
fn main {
  install_counter_ios_embedding()
  println(@ios_skia_backend.ios_skia_provider_preflight_summary())
}
