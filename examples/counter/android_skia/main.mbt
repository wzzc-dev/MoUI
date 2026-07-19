///|
/// Platform entrypoint: application program and renderer configuration only.
/// The Android backend installs runtime callbacks; `moui_shell/embedding` owns
/// the ABI implementation, and `embedding_exports.mbt` is only a linker shim.
fn install_counter_android_embedding() -> Unit {
  @android_host.install_embedding(
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@counter_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => {
      @android_skia_backend.renderer_provider(
        options=@android_skia_backend.AndroidSkiaAppOptions::new(
          surface_route=@android_host.android_shell_renderer_selection(
              gpu_available=@android_skia_backend.android_skia_gpu_available(),
            ).surface_route,
        ),
      )
    },
    renderer_configure=@android_host.android_shell_renderer_configure,
    renderer_status_json=() => {
      @android_host.android_shell_renderer_status_json(
        gpu_available=@android_skia_backend.android_skia_gpu_available(),
      )
    },
  )
}

///|
fn main {
  install_counter_android_embedding()
  println(@android_skia_backend.android_skia_provider_preflight_summary())
}
